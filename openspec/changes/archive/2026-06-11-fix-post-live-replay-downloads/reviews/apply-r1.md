# Apply Plus Review — Round 1
## Reviewer Findings
### Critical
- severity: Critical
  confidence: 100
  location: openspec/changes/fix-post-live-replay-downloads/tasks.md:3; openspec/changes/fix-post-live-replay-downloads/specs/youtube-post-live-replay/spec.md:18-21
  summary: Task 1.1 和 spec 要求正向 follow-up format lookup 路徑，但目前測試只覆蓋初始 metadata 已有 usable formats。
  recommendation: 新增 `DownloadManager` 測試：初始 `post_live` metadata 沒有 usable formats，`fetchMediaOptions` 回傳可配對的 `137+140`，任務進入 normal download flow 而不是停在 `.postLive`。
  raised_by: A+B
- severity: Critical
  confidence: 100
  location: openspec/changes/fix-post-live-replay-downloads/tasks.md:20
  summary: Task 3.2 已標記完成，但缺少 `DownloadItemView` 測試或可審查的手動 UI 檢查紀錄來確認 `.postLive` row 文字與 retry control。
  recommendation: 新增聚焦的 UI 測試，或在 `implementation-notes.md` 記錄 `.postLive` 狀態文字與 retry control 的手動檢查。
  raised_by: A
### Warning
無。
### Suggestion
無。
## Rating
quality_score: 7
critical_gap: true

兩個 findings 都有明確 artifact 依據：正向 follow-up `fetchMediaOptions` 路徑是 task/spec 的要求但尚未測到；task 3.2 需要現有測試或手動 UI 檢查紀錄，目前缺少可審查證據。
## Fix Actions
- 修改 `TubifyTests/DownloadManagerTests.swift`，新增 `testPostLiveFollowUpFormatLookupWithPairableFormatsStartsDownloadFlow`，覆蓋初始 `post_live` metadata 沒有 usable formats、follow-up `fetchMediaOptions` 回傳 `137+140` 並進入 normal download flow。
- 修改 `Tubify/Views/DownloadItemView.swift` 與 `TubifyTests/ContentViewTests.swift`，將 `.postLive` row 狀態文字與 retry control 條件抽成可測 helper，並新增 `testDownloadItemViewPostLiveStatusTextAndRetryControl`。
- 已執行針對性測試：`xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' -only-testing:TubifyTests/DownloadManagerTests/testPostLiveFollowUpFormatLookupWithPairableFormatsStartsDownloadFlow -only-testing:TubifyTests/ContentViewTests/testDownloadItemViewPostLiveStatusTextAndRetryControl CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM=''`，結果通過。
- 已執行全套測試：`xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM=''`，結果為 200 tests、0 failures。
- 已執行 `spectra validate fix-post-live-replay-downloads`，結果 valid。
## Decision
next_round
