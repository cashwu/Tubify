# Apply Plus Review — Round 1

## Reviewer Findings

### Critical

None.

### Warning

1. reviewer: `A`
   - severity: `Warning`
   - confidence: `100`
   - layer: `design`
   - location: `openspec/changes/improve-download-ui-workflows/tasks.md:3`; `openspec/changes/improve-download-ui-workflows/design.md:108`; `TubifyTests/DownloadManagerTests.swift:116-227`
   - summary: Recovery 測試未完整覆蓋明定的跨 session request replay 與排除狀態副作用。
   - recommendation: 新增測試驗證 unresolved `PlaylistSelectionRequest` 與 `VideoOrPlaylistChoiceRequest` 對同 session 不重複 delivery、對新 session 各重播一次且不重啟 recovery；並在七種排除狀態測試註冊三類 selection callbacks，明確斷言 delivery 次數皆為零。

2. reviewer: `B`
   - severity: `Warning`
   - confidence: `90`
   - layer: `design`
   - location: `Tubify/TubifyApp.swift:34-38`; `Tubify/Services/NotificationService.swift:35-45`
   - summary: `NotificationService.shared` 的 lazy initialization 發生在 `applicationDidFinishLaunching` 內的非同步 `Task`，冷啟動通知點擊可能在 delegate 設定前交付而遺失。
   - recommendation: 在 `applicationWillFinishLaunching` 同步初始化 `NotificationService.shared` 並設定 notification center delegate，授權請求仍保留在 `applicationDidFinishLaunching` 的非同步工作。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 2
- critical_gap: `false`
- round_type: `full`

兩項 finding 的 confidence 均達 80 以上且為 `Warning`，因此 round 1 不符合 pass condition；兩項皆涉及 implementation behavior／test contract，下一輪必須是 `full`。

## Fix Actions

- 修改 `TubifyTests/DownloadManagerTests.swift`：新增 playlist 與 video-or-playlist unresolved request 的同 session idempotency、跨 session replay、manager-wide work 不重啟測試，並讓七種排除狀態明確斷言三類 selection callback 都未觸發。
- 修改 `Tubify/TubifyApp.swift`：在 `applicationWillFinishLaunching` 同步初始化 `NotificationService.shared`，保留授權請求於 `applicationDidFinishLaunching`。
- 修改 `TubifyTests/NotificationServiceTests.swift`：以可注入 initialization closure 驗證 AppDelegate 在 launch 完成前同步啟動 notification service。
- 驗證：4 個 targeted tests 全部通過，0 failures。

## Decision

next_round
