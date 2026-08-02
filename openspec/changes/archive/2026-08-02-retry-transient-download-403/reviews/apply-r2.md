# Cash Apply Review — Round 2

## Reviewer Findings

### Critical

None.

### Warning

None.

### Suggestion

1.
   - severity: Suggestion
   - confidence: 78
   - layer: test
   - location: `TubifyTests/YTDLPServiceTests.swift:220-273`
   - summary: overlap fixture 主要驗證舊 process 尚在執行時被取代；可再補一個舊 operation 已進入 backoff 後才啟動新 operation 的案例。
   - disposition: non-blocking triaged；production identity checks 與現有 overlap test 已覆蓋 contract，新增案例不影響本輪通過判定。
   - reviewer source: Reviewer B

## Seeded Findings Verdict

- target 403 同時包含 `Giving up after`：Resolved。`isRetryableDownload403` 已明確排除該 context，並有負向測試。
- task ID-only cancellation race：Resolved。每次 production `download` 建立 `DownloadOperationID`，active operation replacement、cancel 與 process cleanup 均以 operation identity 隔離。
- production process boundary test gap：Resolved。fixture 透過 production `download` path 驅動真實 `Process`，驗證 `cancel(taskId:)`、PID 退出、cleanup 與 cookies fallback 排除。

## New Findings Verdict

- post-termination stale-operation success：Resolved。`Process` termination cleanup 後、成功結果解析前再次檢查 operation identity；Reviewer A、Reviewer B 均確認無後續 actor suspension window。
- process cleanup assertion：Resolved。fixture 記錄 PID，測試以 `kill -0` 輪詢確認 cancellation 後 process 已退出。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- non-blocking triaged finding count: 1
- critical_gap: false
- round_type: full
- rationale: 兩位 reviewer 均確認三個 apply-r1 seeded findings 與本輪新增的 termination/cleanup findings 已解決；無 Critical 或 Warning，唯一 Suggestion 為非阻塞測試強化建議。

## Fix Actions

- fixed: `Tubify/Services/YTDLPService.swift`：加入 termination 後 stale-operation check，並修正 retry/cookies policy 註解。
- fixed: `TubifyTests/YTDLPServiceTests.swift`：加入 fixture PID 記錄與 process exit assertion。
- no design change、contract change 或 scope expansion。

## Reviewer Summary

- Reviewer A：無 Critical、無 Warning；所有 seeded findings 與本輪修正項目 resolved；Suggestion 無。
- Reviewer B：無 Critical、無 Warning；所有 seeded findings 與本輪修正項目 resolved；Suggestion 1，已 triage 為 non-blocking。
- verification：focused `YTDLPServiceTests` 59 tests、0 failures；修正前全專案 suite 279 tests、0 failures。

## Decision

passed
