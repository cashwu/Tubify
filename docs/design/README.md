# 設計文件（Design）

各 change 在實作前撰寫的設計：脈絡、目標與非目標、關鍵決策與替代方案、風險，以及部分 change 的 Implementation Contract。規格（要什麼）見 [../specs/](../specs/README.md)，完成的任務見 [../completed-tasks.md](../completed-tasks.md)。

| 日期 | Change | 規格 |
| ---- | ------ | ---- |
| 2026-03-12 | [playlist-selection](2026-03-12-playlist-selection.md) | [playlist-selection](../specs/playlist-selection.md) |
| 2026-04-09 | [playlist-or-video-prompt](2026-04-09-playlist-or-video-prompt.md) | [playlist-or-video-prompt](../specs/playlist-or-video-prompt.md) |
| 2026-06-11 | [fix-post-live-replay-downloads](2026-06-11-fix-post-live-replay-downloads.md) | [youtube-post-live-replay](../specs/youtube-post-live-replay.md) |
| 2026-06-29 | [route-download-command-by-site](2026-06-29-route-download-command-by-site.md) | [multi-site-download](../specs/multi-site-download.md) |
| 2026-07-13 | [improve-download-ui-workflows](2026-07-13-improve-download-ui-workflows.md) | [download-ui-workflows](../specs/download-ui-workflows.md) |
| 2026-08-02 | [retry-transient-download-403](2026-08-02-retry-transient-download-403.md) | [download-reliability](../specs/download-reliability.md) |
| 2026-08-21 | [cleanup-orphaned-part-files](2026-08-21-cleanup-orphaned-part-files.md) | [download-reliability](../specs/download-reliability.md) |
| 2026-08-21 | [cookieless-subtitle-detection](2026-08-21-cookieless-subtitle-detection.md) | [subtitle-selection](../specs/subtitle-selection.md) |
| 2026-08-22 | [dubbed-audio-track-selection](2026-08-22-dubbed-audio-track-selection.md) | [audio-track-selection](../specs/audio-track-selection.md) |

`add-clear-all-subtitles` 範圍很小，沒有撰寫獨立的 design。

文中偶爾出現的 `openspec/changes/...` 路徑是當時的檔案位置（已移除，內容整理在本 `docs/` 下，原檔可由 git 歷史取回）。
