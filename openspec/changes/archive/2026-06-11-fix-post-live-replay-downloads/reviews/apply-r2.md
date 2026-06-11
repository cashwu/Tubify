# Apply Plus Review — Round 2
## Reviewer Findings
### Critical
無。
### Warning
- severity: Warning
  confidence: 86
  location: Tubify/ViewModels/DownloadManager.swift:462-506; openspec/changes/fix-post-live-replay-downloads/design.md Implementation Contract
  summary: 已展開 playlist video tasks 會略過 post-live metadata gate，因此 no-usable-format 或 ended-live lookup 結果仍可能被排入下載。
  recommendation: 對 selected expanded video tasks 套用相同的 post-live usable-format/error classification 路徑，再決定是否設為 `.pending`，並新增聚焦的 `confirmPlaylistSelection` 測試。
  raised_by: B
### Suggestion
無。
## Rating
quality_score: 8.0
critical_gap: false

此 finding 有程式碼依據：`confirmPlaylistSelection` 對已展開影片只 opportunistically 取得 media options，失敗時吞掉錯誤，之後仍可能將 task 設為 `.pending` 或 media selection，尚未套用單一影片路徑的 post-live usable-format/error classification。影響範圍較窄且下載階段仍有 ended-live fallback，因此不是 Critical，但分數不足以通過。
## Fix Actions
- 已修正：調整 `Tubify/ViewModels/DownloadManager.swift` 的 `confirmPlaylistSelection`，對已展開 playlist video tasks 套用 post-live usable formats 與 ended-live/non-ended-live error 分流，並只將仍為 `.fetchingInfo` 的 tasks 推進到 media selection 或 pending 下載流程。
- 已修正：新增 `TubifyTests/DownloadManagerTests.swift` 的 `testConfirmPlaylistSelectionPostLiveVideoWithoutUsableFormatsStaysPostLive`，覆蓋 playlist selected video 的 post-live no usable formats 不排入下載。
- 已驗證：focused `xcodebuild test ... -only-testing:TubifyTests/DownloadManagerTests/testConfirmPlaylistSelectionPostLiveVideoWithoutUsableFormatsStaysPostLive` 通過。
- 已驗證：full `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' ...` 執行 201 tests，0 failures。
- 已驗證：`spectra validate fix-post-live-replay-downloads` valid。
## Decision
next_round
