from __future__ import annotations

import json
import os
import re
from collections.abc import Iterator, Sequence
from pathlib import Path

from ..errors import CashError
from ..workspace import Workspace


def _tokens(value: str) -> list[str]:
    return [token for token in re.findall(r"\w+", value.casefold()) if token]


def _documents(workspace: Workspace) -> Iterator[tuple[str, str]]:
    yield from workspace.walk_text_files("openspec")


def _title(text: str, fallback: str) -> str:
    for line in text.splitlines():
        if line.startswith("#"):
            value = line.lstrip("#").strip()
            if value:
                return value
    return fallback


def _excerpt(text: str, tokens: list[str], *, limit: int = 240) -> str:
    folded = text.casefold()
    positions = [folded.find(token) for token in tokens]
    matches = [position for position in positions if position >= 0]
    start = max(0, (min(matches) if matches else 0) - 60)
    value = " ".join(text[start : start + limit].split())
    return value[:limit]


def search_payload(
    workspace: Workspace,
    query: str,
    *,
    limit: int,
) -> dict[str, object]:
    tokens = _tokens(query)
    if not tokens:
        raise CashError("invalid_query", "Search query must contain text.")
    if not isinstance(limit, int) or isinstance(limit, bool) or not 1 <= limit <= 100:
        raise CashError("invalid_limit", "Search limit must be between 1 and 100.")
    results: list[dict[str, object]] = []
    for relative, text in _documents(workspace):
        title = _title(text, Path(relative).name)
        folded_path = relative.casefold()
        folded_title = title.casefold()
        folded_body = text.casefold()
        raw_score = 0
        for token in tokens:
            raw_score += folded_path.count(token) * 5
            raw_score += folded_title.count(token) * 3
            raw_score += folded_body.count(token)
        if raw_score == 0:
            continue
        results.append(
            {
                "path": relative,
                "title": title,
                "excerpt": _excerpt(text, tokens),
                "score": round(raw_score / (len(tokens) * 5), 6),
            }
        )
    results.sort(
        key=lambda item: (
            -item["score"],
            item["path"].encode("utf-8"),
            item["title"],
            item["excerpt"],
        )
    )
    return {"results": results[:limit]}


def execute(arguments: Sequence[str]) -> int:
    positional = [value for value in arguments if not value.startswith("--")]
    if len(positional) < 1:
        raise CashError("invalid_arguments", "search requires a query.")
    query = positional[0]
    try:
        limit_index = arguments.index("--limit")
        limit = int(arguments[limit_index + 1])
    except (ValueError, IndexError) as error:
        raise CashError("invalid_limit", "--limit requires an integer.") from error
    workspace = Workspace.discover(
        os.getcwd(),
        launcher_root=os.environ.get("CASH_PROJECT_ROOT"),
    )
    workspace.assert_readable()
    payload = search_payload(workspace, query, limit=limit)
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return 0
