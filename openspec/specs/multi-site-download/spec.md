# multi-site-download Specification

## Purpose

TBD - created by archiving change 'route-download-command-by-site'. Update Purpose after archive.

## Requirements

### Requirement: Accept any valid URL into the download queue

The system SHALL accept any URL that passes basic format validation (a well-formed `http://` or `https://` address that is not a markdown link) into the download queue, regardless of which site it points to. The system SHALL NOT reject a URL solely because it is not a YouTube address.

#### Scenario: Non-YouTube URL is accepted

- **WHEN** the user adds a valid non-YouTube URL such as an x.com or Instagram post
- **THEN** the system adds it to the download queue and does not return a "not a YouTube URL" error

#### Scenario: Malformed input is still rejected

- **WHEN** the user adds an input that fails basic format validation
- **THEN** the system rejects it and reports a format error

##### Example: validation outcomes

| Input | Expected Outcome |
| ----- | ---------------- |
| `https://www.youtube.com/watch?v=dQw4w9WgXcQ` | accepted |
| `https://x.com/user/status/123` | accepted |
| `https://www.instagram.com/p/abc123/` | accepted |
| `ftp://example.com/file` | rejected: format error |
| `[text](https://x.com/a)` | rejected: format error |


<!-- @trace
source: route-download-command-by-site
updated: 2026-06-29
code:
  - Tubify/Models/AppSettings.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Views/EmptyStateView.swift
  - TubifyTests/DownloadManagerTests.swift
  - Tubify/Views/ContentView.swift
-->

---
### Requirement: Route the download command by site

When starting a download, the system SHALL select the download command template based on the task URL. For YouTube URLs the system SHALL use the existing user-configurable download command. For non-YouTube URLs the system SHALL use a generic download command. The command assembly for YouTube URLs SHALL be unchanged from prior behavior.

A "YouTube URL" means a URL recognized as one of the supported YouTube forms — a `youtube.com` watch URL, a `youtu.be` short link, a `youtube.com` playlist URL, or a `youtube.com` shorts URL (the same set the existing YouTube recognition rules match). Every other URL that passes format validation — including YouTube-domain shapes outside those forms, such as a `youtube.com/@channel` URL or a watch URL carrying only `list=` with no `v=` — SHALL be classified as non-YouTube and SHALL use the generic download command.

#### Scenario: YouTube URL uses the existing command

- **WHEN** a download starts for a YouTube URL
- **THEN** the system uses the existing configurable download command template

#### Scenario: Non-YouTube URL uses the generic command

- **WHEN** a download starts for a non-YouTube URL
- **THEN** the system uses the generic download command template

##### Example: command routing

| Task URL | Command template used |
| -------- | --------------------- |
| `https://www.youtube.com/watch?v=dQw4w9WgXcQ` | configurable download command |
| `https://youtu.be/dQw4w9WgXcQ` | configurable download command |
| `https://www.youtube.com/@channelname` | generic download command (unsupported YouTube-domain shape) |
| `https://x.com/user/status/123` | generic download command |
| `https://www.instagram.com/reel/abc123/` | generic download command |


<!-- @trace
source: route-download-command-by-site
updated: 2026-06-29
code:
  - Tubify/Models/AppSettings.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Views/EmptyStateView.swift
  - TubifyTests/DownloadManagerTests.swift
  - Tubify/Views/ContentView.swift
-->

---
### Requirement: YouTube-specific handling is gated to YouTube URLs

YouTube-specific handling — playlist detection and expansion, the "download the single video or the whole playlist?" prompt for mixed video-and-playlist URLs, and the `i.ytimg.com` thumbnail prefetch derived from an extracted video ID — SHALL be applied only to YouTube URLs. For a non-YouTube URL the system SHALL treat it as a single download task and SHALL NOT prefetch a YouTube-derived thumbnail, even when the URL incidentally contains tokens such as `list=` or an 11-character path segment.

#### Scenario: Non-YouTube URL is treated as a single task

- **WHEN** the user adds a non-YouTube URL that incidentally contains a `list=` query parameter
- **THEN** the system enqueues it as a single download task and does not trigger playlist expansion or the video-or-playlist prompt

#### Scenario: Non-YouTube URL gets no YouTube thumbnail

- **WHEN** the user adds a non-YouTube URL whose path contains an 11-character segment
- **THEN** the system does not set an `i.ytimg.com` thumbnail and relies on metadata for any thumbnail

##### Example: handling by site

| Task URL | Playlist/prompt path | ytimg thumbnail prefetch |
| -------- | -------------------- | ------------------------ |
| `https://www.youtube.com/playlist?list=PL123` | yes (playlist) | n/a |
| `https://www.youtube.com/watch?v=abc12345678` | no | yes |
| `https://example.com/feed?list=summer` | no (single task) | no |
| `https://www.instagram.com/reel/Cabc1234def/` | no (single task) | no |


<!-- @trace
source: route-download-command-by-site
updated: 2026-06-29
code:
  - Tubify/Models/AppSettings.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Views/EmptyStateView.swift
  - TubifyTests/DownloadManagerTests.swift
  - Tubify/Views/ContentView.swift
-->

---
### Requirement: Generic download command is a fixed constant

The generic download command SHALL be a fixed application constant. The system SHALL NOT persist it to user settings and SHALL NOT expose it for editing in the settings UI. The generic command SHALL be a complete, executable download-backend command of the same structure as the built-in default YouTube download command (the `AppSettingsDefaults.downloadCommand` constant, not the user-edited value) — it SHALL include the same browser-cookies argument and the URL placeholder used by the download backend — and SHALL differ from that default only in the format-selection argument. Because the generic command is a fixed constant, it SHALL NOT track any user edits the operator makes to the YouTube download command. The generic command SHALL NOT be a bare format selector or any other fragment that the download backend cannot execute on its own.

#### Scenario: Generic command is not user-editable

- **WHEN** the user opens the settings screen
- **THEN** only the existing YouTube download command is shown and editable, and the generic command is not presented as an editable field

#### Scenario: Generic command is a complete executable command

- **WHEN** a non-YouTube download runs with the generic command
- **THEN** the command passed to the download backend is a full invocation (backend executable, browser-cookies argument, format-selection argument, and the resolved URL), not a bare format selector

##### Example: structural parity with the default YouTube command

| Aspect | Default YouTube command (`AppSettingsDefaults.downloadCommand`) | Generic command |
| ------ | --------------- | --------------- |
| backend executable | present | present (same) |
| browser-cookies argument | present | present (same) |
| URL placeholder | present | present (same) |
| format-selection argument | YouTube-optimized (AVC/m4a) | generic (e.g. `bv*+ba/b`) — the only difference |


<!-- @trace
source: route-download-command-by-site
updated: 2026-06-29
code:
  - Tubify/Models/AppSettings.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Views/EmptyStateView.swift
  - TubifyTests/DownloadManagerTests.swift
  - Tubify/Views/ContentView.swift
-->

---
### Requirement: User-facing copy is site-neutral

User-facing copy that previously referred specifically to YouTube SHALL be presented in neutral video terms, so that the interface does not imply YouTube-only support.

#### Scenario: Empty state uses neutral copy

- **WHEN** the user views the empty state prompt for adding URLs
- **THEN** the prompt refers to video links generally rather than YouTube specifically

<!-- @trace
source: route-download-command-by-site
updated: 2026-06-29
code:
  - Tubify/Models/AppSettings.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Views/EmptyStateView.swift
  - TubifyTests/DownloadManagerTests.swift
  - Tubify/Views/ContentView.swift
-->