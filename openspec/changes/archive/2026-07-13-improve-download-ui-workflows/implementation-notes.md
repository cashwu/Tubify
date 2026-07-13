<!-- apply-plus implementation notes | change: improve-download-ui-workflows | initialized: 2026-07-13 15:31 | no entries below means no deviations or open questions were recorded -->

## 2026-07-13 15:33 — Recovery 狀態轉換需移出 PersistenceService
- 類別：deviation
- 任務：1.1
- 內容：將 `Tubify/Services/PersistenceService.swift` 加入 proposal Impact，並移除 `loadTasks()` 在 UI activation 前把 `.downloading` 改成 `.pending` 的既有轉換，改由 `DownloadManager.resumePersistedTasksAfterUIActivation(sessionID:)` 統一處理。
- 原因：原 proposal 未列出實際執行狀態轉換的 persistence 檔案；若不調整，production path 無法符合「callbacks 就緒後才恢復」的 Implementation Contract。

## 2026-07-13 15:36 — 新增 test files 需要 Xcode target membership
- 類別：deviation
- 任務：2.1–3.1
- 內容：將 `Tubify.xcodeproj/project.pbxproj` 加入 proposal Impact，並預先把 `DownloadItemViewTests.swift`、`NotificationServiceTests.swift`、`SettingsViewTests.swift` 加入 `TubifyTests` target。
- 原因：tasks 明定新增三個 test files，但 proposal 未列出 Xcode project membership 的必要修改；集中處理可避免三個平行任務同時編輯 project file。
