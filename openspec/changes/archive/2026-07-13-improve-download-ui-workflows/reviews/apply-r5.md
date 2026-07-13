# Apply Plus Review — Round 5

## Reviewer Findings

### Critical

None.

### Warning

1. reviewer: `A`
   - severity: `Warning`
   - confidence: `100`
   - layer: `text`
   - location: `openspec/changes/improve-download-ui-workflows/proposal.md` 的 `## Impact`
   - summary: Proposal 將未由本 change 修改的 `TubifyTests/DownloadTaskTests.swift`、`TubifyTests/MediaSelectionLogicTests.swift` 與 `TubifyTests/PlaylistSelectionViewTests.swift` 列為 affected code。
   - recommendation: 從 `## Impact` 移除三個不屬於本 change diff 的路徑，讓 scope declaration 與實際修改一致。

2. reviewer: `A`
   - severity: `Warning`
   - confidence: `100`
   - layer: `design`
   - location: `openspec/changes/improve-download-ui-workflows/tasks.md:18` 與當時缺少的整合驗證紀錄
   - summary: Task 4.1 已標示完成，但 round 4 新增的回歸測試尚未納入一次完整 test suite，且多項明定的手動整合檢查沒有可稽核的執行紀錄。
   - recommendation: 重跑完整 macOS test suite，逐項執行可行的 UI 整合檢查並記錄結果；無法由測試環境完成的系統整合必須明確記錄限制與自動化替代證據。

3. reviewer: `B`
   - severity: `Warning`
   - confidence: `95`
   - layer: `design`
   - location: `Tubify/ViewModels/DownloadManager.swift:271-301, 758-791`
   - summary: 移除批次中唯一具有可選媒體項目的 child 後，normalized media request 仍可能留下空白或過期選項；已顯示的舊 request 也可能把只屬於已移除 task 的 selection 套到剩餘 task。
   - recommendation: 部分移除後若剩餘 tasks 已不需要選擇，應自動 resolve 並恢復 queue；確認舊 request 時只把各 task 實際可用的 selection 套到仍存在的 tasks，並加入回歸測試。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 3
- critical_gap: `false`
- round_type: `full`

三項 finding 均以 confidence 80 以上保留為 `Warning`；第二項雖由 reviewer 標為文字問題，但修正需要補做實際驗證，已依規則重新分類為 `design`。本輪不符合 pass condition，且 behavior 與驗證內容皆有修改，下一輪必須是 `full`。

## Fix Actions

- 修改 `openspec/changes/improve-download-ui-workflows/proposal.md`：移除三個不屬於本 change diff 的 test paths，使 `## Impact` 與實際 scope 一致。
- 修改 `Tubify/ViewModels/DownloadManager.swift`：部分移除後重新判定剩餘 tasks 是否仍需要媒體選擇；不需要時自動 resolve 並恢復 queue，且 confirmation 僅套用每個 active task 實際具備的 subtitle/audio options。
- 修改 `TubifyTests/DownloadManagerTests.swift`：新增移除唯一具有選項 child 後自動 resolve，以及舊 request 不得把 removed-only selection 套到剩餘 task 的回歸覆蓋；完整 `DownloadManagerTests` 64/64 通過。
- 修改 `Tubify/Views/ContentView.swift`：修正 SwiftUI 視窗恢復會覆寫主視窗 identifier、導致關閉重開後 Command-V 不再路由的實際 UI 問題，於視窗再次成為 key 時恢復 marker。
- 修改 `TubifyTests/ContentViewTests.swift`：新增主視窗 marker 被覆寫後於 `didBecomeKey` 恢復的回歸測試；並將測試改為不顯示視窗，避免 AppKit 視窗動畫 teardown crash。
- 新增 `openspec/changes/improve-download-ui-workflows/manual-verification.md`：記錄 Settings 單一視窗、三種 paste scope、關閉重開、錯誤詳情、completed row、Finder action、含空格 folder picker 與 accessibility tree 的實際驗證；系統通知授權在 debug test host 回傳 `UNErrorDomain 1`，已如實記錄，delegate initialization、routing、Finder side effect 與 completion-once 由自動測試覆蓋。
- 驗證：完整 macOS test suite 250/250 通過、0 failures；`spectra validate improve-download-ui-workflows` 通過；`spectra analyze improve-download-ui-workflows --json` 為 0 Critical。

## Decision

next_round
