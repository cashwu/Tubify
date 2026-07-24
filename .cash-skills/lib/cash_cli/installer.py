from __future__ import annotations

import argparse
import base64
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .config import ConfigError, parse_cash_config, parse_openspec_config


VERSION_RE = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z")
DIGEST_RE = re.compile(r"[0-9a-f]{64}\Z")
MODE_RE = re.compile(r"0[0-7]{3}\Z")
SKILLS = (
    "analyze",
    "apply",
    "archive",
    "ask",
    "audit",
    "commit",
    "debug",
    "discuss",
    "drift",
    "ingest",
    "propose",
    "verify",
)
STABLE_PATHS = (".cash-skills/bin/cash", ".cash-workspace.lock")
GUIDANCE_PATHS = ("AGENTS.md", "CLAUDE.md")
RECEIPT_PATH = ".cash-skills/receipt.tsv"
JOURNAL_PATH = ".cash-skills/state/installer/journal.json"
LEGACY_MANIFEST_PATH = "scripts/cash-skills/legacy-spectra-digests.tsv"


class InstallerError(Exception):
    def __init__(self, message: str, *, result: str | None = None, exit_code: int = 1):
        super().__init__(message)
        self.result = result
        self.exit_code = exit_code


@dataclass(frozen=True)
class Record:
    kind: str
    path: str
    digest: str
    mode: int


@dataclass(frozen=True)
class Snapshot:
    exists: bool
    content: bytes | None = None
    mode: int | None = None
    device: int | None = None
    inode: int | None = None


@dataclass(frozen=True)
class Receipt:
    version: str
    generation: str
    records: tuple[tuple[str, str, str, int, int | None, int | None], ...]


@dataclass(frozen=True)
class LegacyReceipt:
    version: str
    records: tuple[tuple[str, str], ...]


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def version_parts(value: str) -> tuple[str, str, str]:
    match = VERSION_RE.fullmatch(value)
    if match is None:
        raise InstallerError(f"invalid bundle version: {value}")
    return match.group(1), match.group(2), match.group(3)


def compare_versions(left: str, right: str) -> int:
    for a, b in zip(version_parts(left), version_parts(right), strict=True):
        if len(a) != len(b):
            return -1 if len(a) < len(b) else 1
        if a != b:
            return -1 if a < b else 1
    return 0


def relative_path(value: str) -> str:
    path = Path(value)
    if not value or path.is_absolute() or ".." in path.parts or value != path.as_posix():
        raise InstallerError(f"unsafe managed path: {value}")
    return value


def ensure_contained(root: Path, relative: str) -> Path:
    relative_path(relative)
    candidate = root / relative
    current = root
    for part in Path(relative).parts:
        current = current / part
        try:
            metadata = os.lstat(current)
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(metadata.st_mode):
            raise InstallerError(f"symlink managed boundary: {relative}")
        if current != candidate and not stat.S_ISDIR(metadata.st_mode):
            raise InstallerError(f"managed parent is not a directory: {relative}")
    return candidate


def read_regular(
    root: Path,
    relative: str,
    *,
    expected_mode: int | None = None,
    allow_hardlink: bool = False,
) -> tuple[bytes, os.stat_result]:
    path = ensure_contained(root, relative)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise InstallerError(f"cannot open regular file {relative}: {error}") from error
    try:
        opened = os.fstat(descriptor)
        named = os.lstat(path)
        if (
            not stat.S_ISREG(opened.st_mode)
            or (not allow_hardlink and opened.st_nlink != 1)
            or (opened.st_dev, opened.st_ino) != (named.st_dev, named.st_ino)
        ):
            raise InstallerError(f"unsafe regular file identity: {relative}")
        if expected_mode is not None and stat.S_IMODE(opened.st_mode) != expected_mode:
            raise InstallerError(f"invalid mode for {relative}: expected {expected_mode:04o}")
        chunks: list[bytes] = []
        while chunk := os.read(descriptor, 131072):
            chunks.append(chunk)
        after = os.fstat(descriptor)
        if (opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
        ):
            raise InstallerError(f"file changed while reading: {relative}")
        return b"".join(chunks), opened
    finally:
        os.close(descriptor)


def optional_snapshot(root: Path, relative: str) -> Snapshot:
    path = ensure_contained(root, relative)
    try:
        metadata = os.lstat(path)
    except FileNotFoundError:
        return Snapshot(False)
    content, opened = read_regular(root, relative)
    return Snapshot(
        True,
        content,
        stat.S_IMODE(opened.st_mode),
        opened.st_dev,
        opened.st_ino,
    )


def snapshots(
    root: Path,
    relatives: Iterable[str],
) -> tuple[tuple[str, Snapshot], ...]:
    return tuple(
        (relative, optional_snapshot(root, relative))
        for relative in dict.fromkeys(relatives)
    )


def ensure_directories(root: Path, relative_parent: str) -> None:
    current = root
    for part in Path(relative_parent).parts:
        current = current / part
        try:
            metadata = os.lstat(current)
        except FileNotFoundError:
            os.mkdir(current, 0o755)
            metadata = os.lstat(current)
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
            raise InstallerError(f"unsafe managed directory: {current}")


def snapshot_matches(root: Path, relative: str, expected: Snapshot) -> bool:
    current = optional_snapshot(root, relative)
    if current.exists != expected.exists:
        return False
    if not expected.exists:
        return True
    return (
        current.device == expected.device
        and current.inode == expected.inode
        and current.mode == expected.mode
        and current.content == expected.content
    )


def atomic_write(
    root: Path,
    relative: str,
    content: bytes,
    mode: int,
    *,
    expected: Snapshot | None = None,
) -> None:
    path = ensure_contained(root, relative)
    ensure_directories(root, Path(relative).parent.as_posix())
    parent = path.parent
    before = os.lstat(parent)
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    directory_fd = os.open(parent, flags)
    temporary = f".cash-install-{uuid.uuid4().hex}"
    try:
        held = os.fstat(directory_fd)
        named = os.lstat(parent)
        if (held.st_dev, held.st_ino) != (before.st_dev, before.st_ino) or (
            named.st_dev,
            named.st_ino,
        ) != (held.st_dev, held.st_ino):
            raise InstallerError(f"managed parent identity changed: {relative}")
        ensure_contained(root, relative)
        if expected is not None and not snapshot_matches(root, relative, expected):
            raise InstallerError(f"managed destination changed after preflight: {relative}")
        descriptor = os.open(
            temporary,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            mode,
            dir_fd=directory_fd,
        )
        try:
            offset = 0
            while offset < len(content):
                offset += os.write(descriptor, content[offset:])
            os.fsync(descriptor)
            os.fchmod(descriptor, mode)
        finally:
            os.close(descriptor)
        os.replace(temporary, path.name, src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
    except Exception:
        try:
            os.unlink(temporary, dir_fd=directory_fd)
        except OSError:
            pass
        raise
    finally:
        os.close(directory_fd)


def source_inventory(source: Path) -> tuple[str, tuple[Record, ...], str]:
    version_bytes, _ = read_regular(source, "cash-skills.version", expected_mode=0o644)
    try:
        version_text = version_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        raise InstallerError("bundle version must be UTF-8") from error
    if not version_text.endswith("\n") or version_text.count("\n") != 1:
        raise InstallerError("bundle version must contain one LF-terminated line")
    version = version_text[:-1]
    version_parts(version)

    launcher, _ = read_regular(source, STABLE_PATHS[0], expected_mode=0o755)
    lock, _ = read_regular(source, STABLE_PATHS[1], expected_mode=0o644)
    if lock:
        raise InstallerError("source workspace lock must be empty")
    records: list[Record] = [
        Record("stable", STABLE_PATHS[0], sha256(launcher), 0o755),
        Record("stable", STABLE_PATHS[1], sha256(lock), 0o644),
    ]
    library = source / ".cash-skills" / "lib" / "cash_cli"
    if library.is_symlink() or not library.is_dir():
        raise InstallerError("missing source Cash runtime")
    runtime_paths = sorted(
        (
            path.relative_to(source).as_posix()
            for path in library.rglob("*.py")
            if "__pycache__" not in path.parts
        ),
        key=lambda value: value.encode("utf-8"),
    )
    if not runtime_paths:
        raise InstallerError("source Cash runtime is empty")
    for relative in runtime_paths:
        content, _ = read_regular(source, relative, expected_mode=0o644)
        records.append(Record("runtime", relative, sha256(content), 0o644))
    for variant in (".agents", ".claude"):
        for skill in SKILLS:
            relative = f"{variant}/skills/cash-{skill}/SKILL.md"
            content, _ = read_regular(source, relative, expected_mode=0o644)
            records.append(Record("skill", relative, sha256(content), 0o644))
    runtime_stream = "".join(
        f"{record.path}\t{record.digest}\t{record.mode:04o}\n"
        for record in records
        if record.kind == "runtime"
    ).encode("utf-8")
    return version, tuple(records), sha256(runtime_stream)


def legacy_manifest(source: Path) -> tuple[tuple[str, str], ...]:
    content, _ = read_regular(source, LEGACY_MANIFEST_PATH, expected_mode=0o644)
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise InstallerError("legacy digest manifest must be UTF-8") from error
    if not text.endswith("\n") or "\r" in text:
        raise InstallerError("legacy digest manifest must be LF terminated")
    rows = [line.split("\t") for line in text.splitlines()]
    if not rows or rows[0] != ["version", "1"]:
        raise InstallerError("legacy digest manifest has an invalid version")
    expected_paths = tuple(
        f"{variant}/skills/spectra-{skill}"
        for variant in (".agents", ".claude")
        for skill in SKILLS
    )
    if len(rows) != len(expected_paths) + 1:
        raise InstallerError("legacy digest manifest has an invalid record count")
    result: list[tuple[str, str]] = []
    for row, expected in zip(rows[1:], expected_paths, strict=True):
        if (
            len(row) != 3
            or row[0] != "skill"
            or row[1] != expected
            or DIGEST_RE.fullmatch(row[2]) is None
        ):
            raise InstallerError(f"legacy digest record is invalid: {expected}")
        result.append((row[1], row[2]))
    return tuple(result)


def inspect_legacy_candidate(
    target: Path,
    relative: str,
    expected_digest: str,
) -> dict[str, int | str]:
    directory = ensure_contained(target, relative)
    metadata = os.lstat(directory)
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        raise InstallerError(f"legacy candidate is not a real directory: {relative}")
    entries = sorted(entry.name for entry in os.scandir(directory))
    if entries != ["SKILL.md"]:
        raise InstallerError(f"legacy candidate has unknown or extra content: {relative}")
    skill_relative = f"{relative}/SKILL.md"
    content, opened = read_regular(target, skill_relative, expected_mode=0o644)
    if sha256(content) != expected_digest:
        raise InstallerError(f"legacy candidate body drift: {relative}")
    parent = os.lstat(directory.parent)
    return {
        "path": relative,
        "digest": expected_digest,
        "removable": True,
        "directory_device": metadata.st_dev,
        "directory_inode": metadata.st_ino,
        "file_device": opened.st_dev,
        "file_inode": opened.st_ino,
        "parent_device": parent.st_dev,
        "parent_inode": parent.st_ino,
    }


def classify_legacy_candidate(
    target: Path,
    relative: str,
    expected_digest: str,
) -> dict[str, int | str]:
    """Plan-time classification of an existing legacy skill directory.

    Boundary-unsafe shapes (symlink, non-directory, extra content, unsafe mode
    or hard link) still fail closed because they can lead to deletion outside
    the target. A body that simply does not match the known baseline is an
    unrecognised release, not a safety problem: it is preserved and reported
    instead of blocking the whole installation.
    """
    directory = ensure_contained(target, relative)
    metadata = os.lstat(directory)
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        raise InstallerError(f"legacy candidate is not a real directory: {relative}")
    entries = sorted(entry.name for entry in os.scandir(directory))
    if entries != ["SKILL.md"]:
        raise InstallerError(f"legacy candidate has unknown or extra content: {relative}")
    content, opened = read_regular(target, f"{relative}/SKILL.md")
    if stat.S_IMODE(opened.st_mode) != 0o644 or sha256(content) != expected_digest:
        return {
            "path": relative,
            "digest": sha256(content),
            "removable": False,
        }
    return inspect_legacy_candidate(target, relative, expected_digest)


def legacy_candidates(
    target: Path,
    records: tuple[tuple[str, str], ...],
) -> list[dict[str, int | str]]:
    result: list[dict[str, int | str]] = []
    for relative, digest in records:
        candidate_path = ensure_contained(target, relative)
        if candidate_path.exists() or candidate_path.is_symlink():
            result.append(classify_legacy_candidate(target, relative, digest))
    return result


def installation_inputs(
    source: Path,
    target: Path,
    records: tuple[Record, ...],
) -> tuple[
    tuple[tuple[str, Snapshot], ...],
    tuple[tuple[str, Snapshot], ...],
]:
    source_paths = (
        "cash-skills.version",
        ".cash.yaml",
        LEGACY_MANIFEST_PATH,
        *GUIDANCE_PATHS,
        *(record.path for record in records),
    )
    target_paths = (
        RECEIPT_PATH,
        ".cash.yaml",
        ".spectra.yaml",
        "openspec/config.yaml",
        *GUIDANCE_PATHS,
        *(record.path for record in records if record.kind != "stable"),
    )
    return snapshots(source, source_paths), snapshots(target, target_paths)


def receipt_bytes(
    version: str,
    generation: str,
    records: Iterable[Record],
    target: Path,
) -> bytes:
    lines = [f"version\t{version}", f"runtime_generation\t{generation}"]
    for record in records:
        if record.kind == "stable":
            metadata = os.lstat(target / record.path)
            lines.append(
                f"stable\t{record.path}\t{record.digest}\t{record.mode:04o}"
                f"\t{metadata.st_dev}\t{metadata.st_ino}"
            )
        else:
            lines.append(
                f"{record.kind}\t{record.path}\t{record.digest}\t{record.mode:04o}"
            )
    return ("\n".join(lines) + "\n").encode("utf-8")


def parse_receipt(content: bytes, expected_records: tuple[Record, ...]) -> Receipt:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise InstallerError("receipt must be UTF-8") from error
    if not text.endswith("\n") or "\r" in text or "\x00" in text:
        raise InstallerError("receipt must be LF-terminated text")
    rows = [line.split("\t") for line in text.splitlines()]
    if len(rows) != len(expected_records) + 2:
        raise InstallerError("receipt has an invalid record count")
    if len(rows[0]) != 2 or rows[0][0] != "version":
        raise InstallerError("receipt has an invalid version record")
    version_parts(rows[0][1])
    if (
        len(rows[1]) != 2
        or rows[1][0] != "runtime_generation"
        or DIGEST_RE.fullmatch(rows[1][1]) is None
    ):
        raise InstallerError("receipt has an invalid runtime generation")
    parsed: list[tuple[str, str, str, int, int | None, int | None]] = []
    for row, expected in zip(rows[2:], expected_records, strict=True):
        expected_fields = 6 if expected.kind == "stable" else 4
        if len(row) != expected_fields or row[0] != expected.kind or row[1] != expected.path:
            raise InstallerError(f"receipt record order or shape is invalid: {expected.path}")
        if DIGEST_RE.fullmatch(row[2]) is None or MODE_RE.fullmatch(row[3]) is None:
            raise InstallerError(f"receipt digest or mode is invalid: {expected.path}")
        mode = int(row[3], 8)
        if mode != expected.mode:
            raise InstallerError(f"receipt contract mode is invalid: {expected.path}")
        device = inode = None
        if expected.kind == "stable":
            try:
                device, inode = int(row[4]), int(row[5])
            except ValueError as error:
                raise InstallerError(f"receipt stable identity is invalid: {expected.path}") from error
            if device < 0 or inode <= 0:
                raise InstallerError(f"receipt stable identity is invalid: {expected.path}")
        parsed.append((row[0], row[1], row[2], mode, device, inode))
    runtime_stream = "".join(
        f"{path}\t{digest}\t{mode:04o}\n"
        for kind, path, digest, mode, _, _ in parsed
        if kind == "runtime"
    ).encode("utf-8")
    if sha256(runtime_stream) != rows[1][1]:
        raise InstallerError("receipt runtime generation does not match its records")
    return Receipt(rows[0][1], rows[1][1], tuple(parsed))


def parse_legacy_receipt(
    content: bytes,
    skill_records: tuple[Record, ...],
) -> LegacyReceipt | None:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if not text.endswith("\n") or "\r" in text:
        return None
    rows = [line.split("\t") for line in text.splitlines()]
    if len(rows) != 25 or len(rows[0]) != 2 or rows[0][0] != "version":
        return None
    version_parts(rows[0][1])
    parsed: list[tuple[str, str]] = []
    for row, record in zip(rows[1:], skill_records, strict=True):
        if (
            len(row) != 3
            or row[0] != "sha256"
            or DIGEST_RE.fullmatch(row[1]) is None
            or row[2] != record.path
        ):
            return None
        parsed.append((row[2], row[1]))
    return LegacyReceipt(rows[0][1], tuple(parsed))


def validate_target_prerequisites(target: Path) -> None:
    try:
        result = subprocess.run(
            ["git", "-C", str(target), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise InstallerError("target must be a Git worktree top-level") from error
    if Path(result.stdout.strip()).resolve() != target:
        raise InstallerError("target must be the Git worktree top-level")
    content, _ = read_regular(target, "openspec/config.yaml")
    try:
        parse_openspec_config(content.decode("utf-8"), path="openspec/config.yaml")
    except (UnicodeDecodeError, ConfigError) as error:
        raise InstallerError(f"invalid target openspec/config.yaml: {error}") from error


def parse_legacy_config(content: bytes) -> bytes:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise InstallerError("legacy config must be UTF-8") from error
    values: dict[str, str] = {}
    allowed = {"locale", "tdd", "audit", "parallel_tasks", "spec_dir"}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        if line != line.strip() or ":" not in line:
            raise InstallerError("legacy config contains unsupported YAML")
        key, value = line.split(":", 1)
        value = value.strip()
        if key not in allowed or key in values or not value or any(
            token in value for token in ("#", "[", "]", "{", "}", "&", "*", "!", '"', "'")
        ):
            raise InstallerError(f"legacy config contains unsupported key or value: {key}")
        values[key] = value
    if values.get("spec_dir", "openspec") != "openspec":
        raise InstallerError("legacy config uses a non-default spec_dir")
    values.pop("spec_dir", None)
    output = "".join(f"{key}: {value}\n" for key, value in values.items()).encode("utf-8")
    try:
        parse_cash_config(output.decode("utf-8"), path=".cash.yaml")
    except ConfigError as error:
        raise InstallerError(f"legacy config cannot migrate: {error}") from error
    return output


def config_plan(source: Path, target: Path) -> tuple[bytes | None, bool]:
    source_content, _ = read_regular(source, ".cash.yaml", expected_mode=0o644)
    try:
        parse_cash_config(source_content.decode("utf-8"), path=".cash.yaml")
    except (UnicodeDecodeError, ConfigError) as error:
        raise InstallerError(f"invalid source .cash.yaml: {error}") from error
    cash = optional_snapshot(target, ".cash.yaml")
    if cash.exists:
        try:
            parse_cash_config(cash.content.decode("utf-8"), path=".cash.yaml")  # type: ignore[union-attr]
        except (UnicodeDecodeError, ConfigError) as error:
            raise InstallerError(f"invalid target .cash.yaml: {error}") from error
        return None, False
    legacy = optional_snapshot(target, ".spectra.yaml")
    if legacy.exists:
        return parse_legacy_config(legacy.content or b""), True
    return source_content, True


def marker_span(data: bytes, name: bytes) -> tuple[int, int] | None:
    start = b"<!-- " + name + b":START -->"
    end = b"<!-- " + name + b":END -->"
    if data.count(start) != data.count(start + b"\n") or data.count(end) != data.count(end + b"\n"):
        raise InstallerError(f"malformed {name.decode()} guidance marker")
    if data.count(start) > 1 or data.count(end) > 1 or data.count(start) != data.count(end):
        raise InstallerError(f"duplicate or unbalanced {name.decode()} guidance marker")
    if not data.count(start):
        return None
    begin = data.index(start)
    finish = data.index(end)
    if finish < begin:
        raise InstallerError(f"reversed {name.decode()} guidance marker")
    line_end = data.find(b"\n", finish)
    return begin, len(data) if line_end < 0 else line_end + 1


def canonical_guidance(source: Path, relative: str) -> bytes:
    content, _ = read_regular(source, relative, expected_mode=0o644)
    span = marker_span(content, b"CASH")
    if span is None:
        raise InstallerError(f"source guidance has no Cash block: {relative}")
    if marker_span(content, b"SPECTRA") is not None:
        raise InstallerError(f"source guidance contains a legacy Spectra block: {relative}")
    return content[span[0] : span[1]]


def render_guidance(source: Path, target: Path, relative: str) -> tuple[bytes, int, bool]:
    canonical = canonical_guidance(source, relative)
    existing = optional_snapshot(target, relative)
    content = existing.content or b""
    cash = marker_span(content, b"CASH")
    legacy = marker_span(content, b"SPECTRA")
    if cash and legacy and not (cash[1] <= legacy[0] or legacy[1] <= cash[0]):
        raise InstallerError(f"nested guidance markers: {relative}")
    spans: list[tuple[int, int, bytes]] = []
    if cash:
        spans.append((cash[0], cash[1], canonical))
    if legacy:
        spans.append((legacy[0], legacy[1], b"" if cash else canonical))
    if not spans:
        separator = b"" if not content or content.endswith(b"\n") else b"\n"
        rendered = content + separator + canonical
    else:
        rendered = content
        for begin, end, replacement in sorted(spans, reverse=True):
            rendered = rendered[:begin] + replacement + rendered[end:]
    return rendered, existing.mode or 0o644, rendered != content


def acquire_lock(target: Path, *, dry_run: bool) -> tuple[int | None, bool]:
    lock = target / STABLE_PATHS[1]
    existed = lock.exists()
    if dry_run and not existed:
        return None, False
    flags = os.O_RDWR | getattr(os, "O_NOFOLLOW", 0)
    if not existed:
        flags |= os.O_CREAT | os.O_EXCL
    try:
        descriptor = os.open(lock, flags, 0o644)
    except FileExistsError:
        try:
            descriptor = os.open(
                lock,
                os.O_RDWR | getattr(os, "O_NOFOLLOW", 0),
            )
            existed = True
        except OSError as error:
            raise InstallerError(f"cannot open stable workspace lock: {error}") from error
    except OSError as error:
        raise InstallerError(f"cannot open stable workspace lock: {error}") from error
    fcntl.flock(descriptor, fcntl.LOCK_EX)
    opened = os.fstat(descriptor)
    named = os.lstat(lock)
    if (
        not stat.S_ISREG(opened.st_mode)
        or opened.st_nlink != 1
        or stat.S_IMODE(opened.st_mode) != 0o644
        or opened.st_size != 0
        or (opened.st_dev, opened.st_ino) != (named.st_dev, named.st_ino)
    ):
        os.close(descriptor)
        raise InstallerError("stable workspace lock is unsafe or drifted")
    return descriptor, not existed


def publish_launcher(source: Path, target: Path, *, dry_run: bool) -> bool:
    source_bytes, _ = read_regular(source, STABLE_PATHS[0], expected_mode=0o755)
    existing = optional_snapshot(target, STABLE_PATHS[0])
    if existing.exists:
        if existing.content != source_bytes or existing.mode != 0o755:
            raise InstallerError("stable launcher drift requires an unsupported bootstrap migration")
        return False
    if dry_run:
        return True
    atomic_write(
        target,
        STABLE_PATHS[0],
        source_bytes,
        0o755,
        expected=existing,
    )
    return True


def wait_for_inflight_receipt(
    target: Path,
    before: Snapshot,
) -> bool:
    if not (target / STABLE_PATHS[1]).exists():
        return False
    descriptor, _ = acquire_lock(target, dry_run=False)
    try:
        after = optional_snapshot(target, RECEIPT_PATH)
        return (
            after.exists != before.exists
            or after.content != before.content
            or after.device != before.device
            or after.inode != before.inode
        )
    finally:
        if descriptor is not None:
            os.close(descriptor)


def validate_installed_receipt(
    target: Path,
    receipt: Receipt,
    records: tuple[Record, ...],
) -> list[str]:
    conflicts: list[str] = []
    for parsed, expected in zip(receipt.records, records, strict=True):
        kind, path, digest, mode, device, inode = parsed
        snapshot = optional_snapshot(target, path)
        if not snapshot.exists:
            raise InstallerError(f"receipt-managed path is missing: {path}")
        actual_digest = sha256(snapshot.content or b"")
        if kind == "stable":
            if (
                actual_digest != digest
                or snapshot.mode != mode
                or snapshot.device != device
                or snapshot.inode != inode
            ):
                raise InstallerError(f"stable receipt identity drift: {path}")
        elif actual_digest != digest or snapshot.mode != mode:
            conflicts.append(path)
        if path != expected.path:
            raise InstallerError(f"receipt path mismatch: {path}")
    return conflicts


class InstallTransaction:
    def __init__(self, target: Path):
        self.target = target
        self.operations: list[dict[str, object]] = []

    def add(self, relative: str, content: bytes, mode: int) -> None:
        before = optional_snapshot(self.target, relative)
        self.operations.append(
            {
                "kind": "write",
                "path": relative,
                "content": content,
                "mode": mode,
                "before": before,
            }
        )

    def add_legacy_delete(self, candidate: dict[str, int | str]) -> None:
        relative = str(candidate["path"])
        parent = Path(relative).parent.as_posix()
        quarantine = f"{parent}/.cash-legacy-{uuid.uuid4().hex}"
        self.operations.append(
            {
                "kind": "legacy_delete",
                **candidate,
                "quarantine": quarantine,
            }
        )

    def _journal(self, published: int, phase: str = "publishing") -> bytes:
        rows = []
        for operation in self.operations:
            if operation["kind"] == "write":
                before = operation["before"]
                assert isinstance(before, Snapshot)
                rows.append(
                    {
                        "kind": "write",
                        "path": operation["path"],
                        "exists": before.exists,
                        "content": (
                            base64.b64encode(before.content or b"").decode("ascii")
                            if before.exists
                            else None
                        ),
                        "mode": before.mode,
                    }
                )
            else:
                rows.append(
                    {
                        key: value
                        for key, value in operation.items()
                        if key != "content"
                    }
                )
        return (
            json.dumps(
                {
                    "version": 2,
                    "phase": phase,
                    "published": published,
                    "operations": rows,
                },
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")

    def commit(self) -> None:
        if not self.operations:
            return
        ensure_directories(self.target, str(Path(JOURNAL_PATH).parent))
        atomic_write(self.target, JOURNAL_PATH, self._journal(0), 0o600)
        published = 0
        try:
            for operation in self.operations:
                next_published = published + 1
                atomic_write(
                    self.target,
                    JOURNAL_PATH,
                    self._journal(next_published),
                    0o600,
                )
                if operation["kind"] == "write":
                    before = operation["before"]
                    assert isinstance(before, Snapshot)
                    atomic_write(
                        self.target,
                        str(operation["path"]),
                        bytes(operation["content"]),
                        int(operation["mode"]),
                        expected=before,
                    )
                else:
                    self._publish_legacy_delete(operation)
                published = next_published
                fail_after = os.environ.get("CASH_INSTALL_FAIL_AFTER")
                if fail_after and published == int(fail_after):
                    raise InstallerError(f"injected publication failure after {published}")
        except Exception:
            try:
                self.rollback(published)
                self.cleanup_journal()
            except Exception as rollback_error:
                raise InstallerError(
                    f"installer rollback failed; recovery journal preserved: {rollback_error}"
                ) from rollback_error
            raise
        atomic_write(
            self.target,
            JOURNAL_PATH,
            self._journal(published, "committed"),
            0o600,
        )
        if os.environ.get("CASH_INSTALL_CRASH_AFTER_COMMIT") == "1":
            os._exit(97)
        try:
            self._remove_quarantines(committed=True)
        except Exception as error:
            raise InstallerError(
                f"installer commit cleanup failed; recovery journal preserved: {error}"
            ) from error
        self.cleanup_journal()

    def rollback(self, published: int) -> None:
        for operation in reversed(self.operations[:published]):
            if operation["kind"] == "legacy_delete":
                original = ensure_contained(self.target, str(operation["path"]))
                quarantine = ensure_contained(self.target, str(operation["quarantine"]))
                if quarantine.exists() and not original.exists():
                    os.rename(quarantine, original)
                elif quarantine.exists() or original.exists():
                    candidate = inspect_legacy_candidate(
                        self.target,
                        str(operation["path"]),
                        str(operation["digest"]),
                    )
                    if (
                        candidate["directory_device"] != operation["directory_device"]
                        or candidate["directory_inode"] != operation["directory_inode"]
                    ):
                        raise InstallerError(
                            f"legacy rollback identity drift: {operation['path']}"
                        )
                continue
            relative = str(operation["path"])
            before = operation["before"]
            assert isinstance(before, Snapshot)
            path = ensure_contained(self.target, relative)
            if before.exists:
                atomic_write(
                    self.target,
                    relative,
                    before.content or b"",
                    before.mode or 0o644,
                )
            elif path.exists():
                metadata = os.lstat(path)
                if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
                    raise InstallerError(f"rollback target is unsafe: {relative}")
                path.unlink()

    def _publish_legacy_delete(self, operation: dict[str, object]) -> None:
        candidate = inspect_legacy_candidate(
            self.target,
            str(operation["path"]),
            str(operation["digest"]),
        )
        for field in (
            "directory_device",
            "directory_inode",
            "file_device",
            "file_inode",
            "parent_device",
            "parent_inode",
        ):
            if candidate[field] != operation[field]:
                raise InstallerError(
                    f"legacy candidate changed after preflight: {operation['path']}"
                )
        source = ensure_contained(self.target, str(operation["path"]))
        quarantine = ensure_contained(self.target, str(operation["quarantine"]))
        if quarantine.exists():
            raise InstallerError(f"legacy quarantine collision: {operation['quarantine']}")
        os.rename(source, quarantine)

    def _remove_quarantines(self, *, committed: bool = False) -> None:
        removed = 0
        for operation in self.operations:
            if operation["kind"] != "legacy_delete":
                continue
            quarantine = ensure_contained(self.target, str(operation["quarantine"]))
            if not quarantine.exists():
                original = ensure_contained(self.target, str(operation["path"]))
                if committed and not original.exists():
                    continue
                raise InstallerError(
                    f"legacy quarantine disappeared: {operation['quarantine']}"
                )
            candidate = inspect_legacy_candidate(
                self.target,
                str(operation["quarantine"]),
                str(operation["digest"]),
            )
            if (
                candidate["directory_device"] != operation["directory_device"]
                or candidate["directory_inode"] != operation["directory_inode"]
            ):
                raise InstallerError(
                    f"legacy quarantine identity drift: {operation['quarantine']}"
                )
            (quarantine / "SKILL.md").unlink()
            quarantine.rmdir()
            removed += 1
            if os.environ.get("CASH_INSTALL_CRASH_AFTER_QUARANTINE") == str(removed):
                os._exit(98)

    def cleanup_journal(self) -> None:
        journal = self.target / JOURNAL_PATH
        if journal.exists():
            journal.unlink()
        for relative in (
            ".cash-skills/state/installer",
            ".cash-skills/state",
        ):
            try:
                (self.target / relative).rmdir()
            except OSError:
                pass


def recover_installer(target: Path) -> None:
    journal = target / JOURNAL_PATH
    if not journal.exists():
        return
    content, _ = read_regular(target, JOURNAL_PATH, expected_mode=0o600)
    try:
        document = json.loads(content)
        if (
            set(document) != {"version", "phase", "published", "operations"}
            or document["version"] != 2
            or document["phase"] not in {"publishing", "committed"}
        ):
            raise ValueError("invalid journal schema")
        operations = document["operations"]
        published = int(document["published"])
        transaction = InstallTransaction(target)
        for item in operations:
            if item["kind"] == "write":
                before = Snapshot(
                    bool(item["exists"]),
                    (
                        base64.b64decode(item["content"])
                        if item["exists"]
                        else None
                    ),
                    item["mode"],
                )
                transaction.operations.append(
                    {
                        "kind": "write",
                        "path": item["path"],
                        "content": b"",
                        "mode": 0o644,
                        "before": before,
                    }
                )
            else:
                transaction.operations.append(dict(item))
        if document["phase"] == "committed":
            if published != len(operations):
                raise ValueError("committed journal has incomplete publication ledger")
            transaction._remove_quarantines(committed=True)
        else:
            transaction.rollback(published)
        transaction.cleanup_journal()
    except Exception as error:
        raise InstallerError(f"cannot recover installer journal: {error}") from error


def install_target(
    source: Path,
    target_input: str,
    *,
    dry_run: bool,
    force: bool,
) -> str:
    if sys.version_info < (3, 11):
        raise InstallerError("Cash installer requires Python 3.11+")
    if not target_input or target_input == "/" or Path(target_input).is_symlink():
        raise InstallerError("target must be a safe existing directory")
    target = Path(target_input).resolve()
    if not target.is_dir() or target == source:
        raise InstallerError("target must be an existing non-source directory")
    validate_target_prerequisites(target)
    version, records, generation = source_inventory(source)
    legacy_records = legacy_manifest(source)
    for relative in (
        *(record.path for record in records),
        RECEIPT_PATH,
        ".cash.yaml",
        *GUIDANCE_PATHS,
    ):
        ensure_contained(target, relative)

    receipt_snapshot = optional_snapshot(target, RECEIPT_PATH)
    receipt: Receipt | None = None
    legacy_receipt: LegacyReceipt | None = None
    skill_records = tuple(record for record in records if record.kind == "skill")
    if receipt_snapshot.exists:
        try:
            receipt = parse_receipt(receipt_snapshot.content or b"", records)
        except InstallerError as new_error:
            legacy_receipt = parse_legacy_receipt(
                receipt_snapshot.content or b"",
                skill_records,
            )
            if legacy_receipt is None:
                raise new_error
    target_version = receipt.version if receipt else (
        legacy_receipt.version if legacy_receipt else None
    )
    if target_version is not None and compare_versions(version, target_version) < 0:
        return "newer"

    source_config, _ = read_regular(source, ".cash.yaml", expected_mode=0o644)
    try:
        parse_cash_config(source_config.decode("utf-8"), path=".cash.yaml")
    except (UnicodeDecodeError, ConfigError) as error:
        raise InstallerError(f"invalid source .cash.yaml: {error}") from error

    planned_config, config_changed = config_plan(source, target)
    guidance: list[tuple[str, bytes, int, bool]] = []
    for relative in GUIDANCE_PATHS:
        rendered, mode, changed = render_guidance(source, target, relative)
        guidance.append((relative, rendered, mode, changed))
    planned_legacy_candidates = legacy_candidates(target, legacy_records)

    conflicts: list[str] = []
    if receipt is not None:
        conflicts = validate_installed_receipt(target, receipt, records)
        if compare_versions(version, receipt.version) == 0:
            for parsed, source_record in zip(receipt.records, records, strict=True):
                if parsed[2] != source_record.digest:
                    raise InstallerError(
                        f"equal-version source integrity drift: {source_record.path}"
                    )
            if receipt.generation != generation:
                raise InstallerError("equal-version runtime generation drift")
    elif legacy_receipt is not None:
        for (path, expected_digest), record in zip(
            legacy_receipt.records,
            skill_records,
            strict=True,
        ):
            snapshot = optional_snapshot(target, path)
            # The legacy receipt schema records only path and digest; it has no
            # mode field and the legacy installer never guaranteed one. Gating
            # migration on mode would reject installs the old contract produced.
            # The upgrade rewrites每個 managed skill with its contract mode，
            # so mode is normalised by this transaction instead.
            if (
                not snapshot.exists
                or sha256(snapshot.content or b"") != expected_digest
                or path != record.path
            ):
                raise InstallerError(f"legacy receipt drift: {path}")
    else:
        present_skills = [
            record
            for record in skill_records
            if optional_snapshot(target, record.path).exists
        ]
        if len(present_skills) not in {0, 24} and not force:
            if wait_for_inflight_receipt(target, receipt_snapshot):
                return install_target(
                    source,
                    str(target),
                    dry_run=dry_run,
                    force=force,
                )
            raise InstallerError(
                "receipt-less Cash skill inventory is partial",
                result="conflict",
                exit_code=2,
            )
        for record in present_skills:
            snapshot = optional_snapshot(target, record.path)
            if (
                snapshot.mode != 0o644
                or sha256(snapshot.content or b"") != record.digest
            ):
                conflicts.append(record.path)
        runtime_records = [record for record in records if record.kind == "runtime"]
        present_runtime = [
            record for record in runtime_records if optional_snapshot(target, record.path).exists
        ]
        if present_runtime and len(present_runtime) != len(runtime_records):
            conflicts.extend(record.path for record in runtime_records)
    if conflicts and not force:
        if wait_for_inflight_receipt(target, receipt_snapshot):
            return install_target(
                source,
                str(target),
                dry_run=dry_run,
                force=force,
            )
        raise InstallerError(
            "managed target drift: " + ", ".join(sorted(set(conflicts))),
            result="conflict",
            exit_code=2,
        )

    source_inputs, target_inputs = installation_inputs(
        source,
        target,
        records,
    )
    lock_existed_before = (target / STABLE_PATHS[1]).exists()
    launcher_existed_before = (target / STABLE_PATHS[0]).exists()
    if launcher_existed_before and not lock_existed_before:
        raise InstallerError("launcher exists without stable workspace lock")
    lock_descriptor, _ = acquire_lock(target, dry_run=dry_run)
    try:
        hold_path = os.environ.get("CASH_INSTALL_HOLD_FILE")
        if hold_path and not dry_run:
            ready = Path(f"{hold_path}.ready")
            release = Path(f"{hold_path}.release")
            ready.write_text("ready\n", encoding="utf-8")
            deadline = time.monotonic() + 10
            while not release.exists():
                if time.monotonic() >= deadline:
                    raise InstallerError("installer test hold timed out")
                time.sleep(0.01)
        validate_target_prerequisites(target)
        locked_source_inputs, locked_target_inputs = installation_inputs(
            source,
            target,
            records,
        )
        locked_legacy_candidates = legacy_candidates(target, legacy_records)
        if (
            locked_source_inputs != source_inputs
            or locked_target_inputs != target_inputs
            or locked_legacy_candidates != planned_legacy_candidates
        ):
            if lock_descriptor is not None:
                os.close(lock_descriptor)
                lock_descriptor = None
            return install_target(
                source,
                str(target),
                dry_run=dry_run,
                force=force,
            )
        post_lock_receipt = optional_snapshot(target, RECEIPT_PATH)
        if (
            post_lock_receipt.exists != receipt_snapshot.exists
            or post_lock_receipt.content != receipt_snapshot.content
            or post_lock_receipt.device != receipt_snapshot.device
            or post_lock_receipt.inode != receipt_snapshot.inode
        ):
            if lock_descriptor is not None:
                os.close(lock_descriptor)
                lock_descriptor = None
            return install_target(
                source,
                str(target),
                dry_run=dry_run,
                force=force,
            )
        if not dry_run:
            recover_installer(target)
        launcher_changed = publish_launcher(source, target, dry_run=dry_run)

        transaction = InstallTransaction(target)
        for record in records:
            if record.kind == "stable":
                continue
            source_content, _ = read_regular(
                source,
                record.path,
                expected_mode=record.mode,
            )
            if sha256(source_content) != record.digest:
                raise InstallerError(
                    f"source managed path changed after preflight: {record.path}"
                )
            current = optional_snapshot(target, record.path)
            if (
                not current.exists
                or current.mode != record.mode
                or sha256(current.content or b"") != record.digest
            ):
                transaction.add(record.path, source_content, record.mode)
        if config_changed and planned_config is not None:
            transaction.add(".cash.yaml", planned_config, 0o644)
        for relative, rendered, mode, changed in guidance:
            if changed:
                transaction.add(relative, rendered, mode)
        for candidate in planned_legacy_candidates:
            if candidate.get("removable"):
                transaction.add_legacy_delete(candidate)

        preserved = [
            str(candidate["path"])
            for candidate in planned_legacy_candidates
            if not candidate.get("removable")
        ]
        if preserved:
            print(
                f"{target}: preserved {len(preserved)} unrecognised legacy skill(s): "
                + ", ".join(preserved),
                file=sys.stderr,
            )

        would_change = bool(transaction.operations) or launcher_changed or receipt is None
        if receipt is not None and not would_change:
            expected_receipt = receipt_bytes(version, generation, records, target)
            would_change = expected_receipt != (receipt_snapshot.content or b"")
        if not would_change:
            return "current"
        if dry_run:
            return "update"
        final_source_inputs, final_target_inputs = installation_inputs(
            source,
            target,
            records,
        )
        if (
            final_source_inputs != source_inputs
            or final_target_inputs != target_inputs
            or legacy_candidates(target, legacy_records) != planned_legacy_candidates
        ):
            raise InstallerError("installation inputs changed after lock acquisition")
        new_receipt = receipt_bytes(version, generation, records, target)
        transaction.add(RECEIPT_PATH, new_receipt, 0o644)
        transaction.commit()
        return "update"
    finally:
        if lock_descriptor is not None:
            os.close(lock_descriptor)


def bootstrap_source(source: Path, *, dry_run: bool) -> str:
    if sys.version_info < (3, 11):
        raise InstallerError("Cash installer requires Python 3.11+")
    validate_target_prerequisites(source)
    version, records, generation = source_inventory(source)
    source_config, _ = read_regular(source, ".cash.yaml", expected_mode=0o644)
    try:
        parse_cash_config(source_config.decode("utf-8"), path=".cash.yaml")
    except (UnicodeDecodeError, ConfigError) as error:
        raise InstallerError(f"invalid source .cash.yaml: {error}") from error
    ensure_contained(source, RECEIPT_PATH)

    lock_descriptor, _ = acquire_lock(source, dry_run=dry_run)
    try:
        validate_target_prerequisites(source)
        locked_version, locked_records, locked_generation = source_inventory(source)
        if (
            locked_version != version
            or locked_records != records
            or locked_generation != generation
        ):
            raise InstallerError("source inventory changed while acquiring lock")
        locked_config, _ = read_regular(source, ".cash.yaml", expected_mode=0o644)
        if locked_config != source_config:
            raise InstallerError("source .cash.yaml changed while acquiring lock")

        receipt_snapshot = optional_snapshot(source, RECEIPT_PATH)
        expected = receipt_bytes(version, generation, records, source)
        if receipt_snapshot.exists and receipt_snapshot.content == expected:
            if receipt_snapshot.mode != 0o644:
                raise InstallerError("source receipt mode is invalid")
            return "current"
        if dry_run:
            return "would-bootstrap"
        atomic_write(
            source,
            RECEIPT_PATH,
            expected,
            0o644,
            expected=receipt_snapshot,
        )
        return "bootstrap"
    finally:
        if lock_descriptor is not None:
            os.close(lock_descriptor)


def safe_home() -> Path:
    value = os.environ.get("HOME", "")
    path = Path(value)
    if not value or not path.is_absolute() or value == "/" or path.is_symlink():
        raise InstallerError("HOME must be an absolute non-root real directory")
    resolved = path.resolve()
    if not resolved.is_dir() or resolved == Path("/"):
        raise InstallerError("HOME must be an existing directory")
    return resolved


def registry_path() -> Path:
    return safe_home() / ".config" / "cash-skills" / "projects.txt"


def read_registry() -> list[str]:
    root = safe_home()
    path = registry_path()
    relative = path.relative_to(root).as_posix()
    snapshot = optional_snapshot(root, relative)
    if not snapshot.exists:
        return []
    content = snapshot.content or b""
    try:
        lines = content.decode("utf-8").split("\n")
    except UnicodeDecodeError as error:
        raise InstallerError("registry must be UTF-8") from error
    records: list[str] = []
    for line_number, line in enumerate(lines, start=1):
        if line == "":
            continue
        if any(ord(character) < 32 or ord(character) == 127 for character in line):
            raise InstallerError(
                f"registry line {line_number} contains an ASCII control character"
            )
        candidate = Path(line)
        components = line.split("/")
        if (
            not candidate.is_absolute()
            or candidate.as_posix() != line
            or any(part in {"", ".", ".."} for part in components[1:])
        ):
            raise InstallerError(
                f"registry line {line_number} path is not canonical"
            )
        current = Path(candidate.anchor)
        fully_existing = True
        for part in candidate.parts[1:]:
            current /= part
            try:
                metadata = os.lstat(current)
            except FileNotFoundError:
                fully_existing = False
                break
            except OSError as error:
                raise InstallerError(
                    f"cannot inspect registry line {line_number}: {error}"
                ) from error
            if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
                raise InstallerError(
                    f"registry line {line_number} path is not canonical"
                )
        if fully_existing and candidate.resolve().as_posix() != line:
            raise InstallerError(
                f"registry line {line_number} path is not canonical"
            )
        if line not in records:
            records.append(line)
    return records


def write_registry(records: list[str]) -> None:
    path = registry_path()
    root = safe_home()
    relative = path.relative_to(root).as_posix()
    ensure_directories(root, str(Path(relative).parent))
    atomic_write(root, relative, "".join(f"{record}\n" for record in records).encode(), 0o644)


def canonical_target(value: str, *, allow_missing: bool = False) -> str:
    if not value or any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise InstallerError("project path is invalid")
    path = Path(value)
    if path.exists():
        if path.is_symlink() or not path.is_dir():
            raise InstallerError("project must be a real directory")
        return path.resolve().as_posix()
    if allow_missing and path.is_absolute() and value != "/":
        return path.as_posix()
    raise InstallerError("project must be an existing directory")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="install-cash-skills.fish")
    modes = result.add_mutually_exclusive_group(required=True)
    modes.add_argument("--target", metavar="<project>")
    modes.add_argument("--self", action="store_true")
    modes.add_argument("--register", metavar="<project>")
    modes.add_argument("--unregister", metavar="<project>")
    modes.add_argument("--list", action="store_true")
    modes.add_argument("--all", action="store_true")
    result.add_argument("--dry-run", action="store_true")
    result.add_argument("--force", action="store_true")
    return result


def run(arguments: list[str] | None = None) -> int:
    options = parser().parse_args(arguments)
    source = Path(__file__).resolve().parents[3]
    if options.dry_run and not (options.target or options.all or options.self):
        raise InstallerError(
            "--dry-run requires --target, --all, or --self",
            exit_code=2,
        )
    if options.force and not (options.target or options.all):
        raise InstallerError("--force requires --target or --all", exit_code=2)
    if options.self:
        result = bootstrap_source(source, dry_run=options.dry_run)
        print(f"Result: {result}")
        return 0
    if options.target:
        result = install_target(
            source,
            options.target,
            dry_run=options.dry_run,
            force=options.force,
        )
        print(f"Result: {result}")
        return 0
    records = read_registry()
    if options.register:
        project = canonical_target(options.register)
        if Path(project) == source:
            raise InstallerError("project must be an existing non-source directory")
        validate_target_prerequisites(Path(project))
        if project not in records:
            records.append(project)
            write_registry(records)
        print(f"registered: {project}")
        return 0
    if options.unregister:
        project = canonical_target(options.unregister, allow_missing=True)
        updated = [record for record in records if record != project]
        if updated != records:
            write_registry(updated)
        print(f"unregistered: {project}")
        return 0
    if options.list:
        print("\n".join(records))
        return 0
    counts = {
        "updated": 0,
        "would-update": 0,
        "current": 0,
        "newer": 0,
        "conflict": 0,
        "failed": 0,
    }
    for record in records:
        try:
            result = install_target(
                source,
                record,
                dry_run=options.dry_run,
                force=options.force,
            )
            label = "would-update" if options.dry_run and result == "update" else (
                "updated" if result == "update" else result
            )
        except InstallerError as error:
            label = error.result or "failed"
            print(f"{record}: {error}", file=sys.stderr)
        counts[label] += 1
        print(f"{label}: {record}")
    print(
        "Summary: "
        + " ".join(f"{key}={value}" for key, value in counts.items())
    )
    return 1 if counts["conflict"] or counts["failed"] else 0


def main() -> int:
    try:
        return run()
    except InstallerError as error:
        print(f"Error: {error}", file=sys.stderr)
        if error.result:
            print(f"Result: {error.result}")
        return error.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
