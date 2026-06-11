# Propose Plus Review — Round 3
## Reviewer Findings
### Critical

(none)

### Warning

- reviewer: A
  severity: Warning
  confidence: 100
  location: `design.md` `Implementation Contract` / `specs/youtube-post-live-replay/spec.md` `Downloadable post-live replay detection` / `tasks.md` 1.5, 2.4
  summary: formats 查詢遇到非 ended-live error 時，design contract 要求走既有 `.failed` 流程與失敗通知，但 spec/tasks 只要求 `.failed` 與保留錯誤訊息。
  recommendation: 在 spec 的 `Scenario: post_live format lookup returns non-ended-live error` 增加 `generic failed download notification` 相關 `THEN`，並更新 tasks `1.5` / `2.4` 明確驗證非 ended-live format lookup error 會觸發既有失敗通知。

- reviewer: B
  severity: Warning
  confidence: 100
  location: `tasks.md` section 1
  summary: `[P]` markers are unsafe because tasks 1.1, 1.2, and 1.3 may target overlapping test files.
  recommendation: Remove `[P]` from 1.1-1.3, or make each task target one exact non-overlapping file so parallel apply cannot edit `TubifyTests/DownloadManagerTests.swift` or `TubifyTests/PostLiveReplayTests.swift` concurrently.

- reviewer: B
  severity: Warning
  confidence: 100
  location: `specs/youtube-post-live-replay/spec.md` `Ended-live extractor errors are transient post-live states` + `tasks.md` 1.2
  summary: The negative example `Video unavailable -> failed + sent` is not covered by the error classification test task.
  recommendation: Expand task 1.2 to require a negative classifier test proving `ERROR: [youtube] abc123: Video unavailable` remains `.failed` and still sends the generic failed download notification.

- reviewer: B
  severity: Warning
  confidence: 100
  location: `specs/youtube-post-live-replay/spec.md` `post_live format lookup returns non-ended-live error` + `tasks.md` 1.5
  summary: The spec requires preserving the non-ended-live error message, but task 1.5 only verifies `.failed`.
  recommendation: Update task 1.5 to explicitly assert that the original non-ended-live error message is preserved when the formats lookup fails.

### Suggestion

(none)

## Rating

quality_score: 8.6
critical_gap: false

不通過。此輪沒有 Critical finding，因此 critical_gap 為 false；但仍有多個高信心 Warning，集中在 spec/design/tasks contract 不一致、失敗通知驗證缺口、錯誤訊息保留未明確測試，以及 `[P]` 平行任務標記可能造成檔案衝突。這些都屬於可修正但會影響 apply 精準度與驗證完整性的問題，因此品質未達 >9 通過門檻。

## Fix Actions

- 修改 `specs/youtube-post-live-replay/spec.md`：讓 post_live formats 查詢非 ended-live error scenario 明確要求 generic failed download notification。
- 修改 `tasks.md`：移除所有 `[P]` marker，避免 apply 階段因測試檔重疊而產生平行衝突。
- 修改 `tasks.md`：讓 1.2 覆蓋 `Video unavailable` 負例、generic failed download notification、user-readable message。
- 修改 `tasks.md`：讓 1.5 與 2.4 明確驗證非 ended-live formats 查詢錯誤保留原錯誤並觸發既有失敗通知。

## Decision

next_round
