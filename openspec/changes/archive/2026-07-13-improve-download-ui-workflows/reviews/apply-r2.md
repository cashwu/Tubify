# Apply Plus Review — Round 2

## Reviewer Findings

### Critical

None.

### Warning

1. reviewer: `B`
   - severity: `Warning`
   - confidence: `90`
   - layer: `design`
   - location: `Tubify/ViewModels/DownloadManager.swift:207-219, 893-900, 929-938`
   - summary: Manager-owned unresolved request registries 未隨任務移除或「清除全部」同步清理，async metadata／playlist work 也可能在來源已刪除後註冊 stale request，造成新 UI session 重播無效操作。
   - recommendation: 在 `removeTask`／`clearAllTasks` 清除引用被移除 task／placeholder 的 media、playlist 與 video-or-playlist requests，並在註冊 async 產生的 request 前確認來源仍存在。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 1
- critical_gap: `false`
- round_type: `full`

Reviewer A 確認 round 1 fixes 與 implementation contract 均符合；Reviewer B 的 stale request finding 以 confidence 90 保留為 `Warning`，因此本輪為 `next_round`。此 finding 涉及 production lifecycle behavior，下一輪必須是 `full`。

## Fix Actions

- 修改 `Tubify/ViewModels/DownloadManager.swift`：`registerMediaRequest` 與 `registerPlaylistRequest` 在 registry 邊界確認來源 task／placeholder 仍存在；`removeTask` 清除引用該 task 的 media/playlist requests；`clearAllTasks` 清空三類 unresolved registries 與 per-session delivery bookkeeping。
- 修改 `TubifyTests/DownloadManagerTests.swift`：新增既有 media request 移除後不重播、async metadata/playlist 完成前移除來源不產生 stale request，以及 clear-all 後三類 request 都不跨 session 重播的測試；mock playlist fetch 支援既有 delay seam。
- 驗證：4 個 targeted regression tests 先以 6 failures 重現問題，修正後 4/4 通過；完整 `DownloadManagerTests` 60/60 通過。

## Decision

next_round
