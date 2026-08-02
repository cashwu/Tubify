# Cash Apply Review — Round 3

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
   - summary: 可再補一個舊 operation 已進入 backoff 後才啟動新 operation 的 overlap 案例。
   - disposition: non-blocking triaged；現有 operation identity checks 與 overlap 測試已覆蓋交付 contract。
   - reviewer source: Reviewer A、Reviewer B

2.
   - severity: Suggestion
   - confidence: 72
   - layer: test
   - location: `TubifyTests/YTDLPServiceTests.swift:303`
   - summary: success-after-attempt regression test 使用 cancellation probe，未直接模擬 active operation identity 被替換。
   - disposition: non-blocking triaged；production flow 已在 attempt 成功返回前檢查 cancellation 與 `DownloadOperationID` identity，既有 overlap fixture 覆蓋 operation replacement。
   - reviewer source: Reviewer B

## Seeded Findings Verdict

- target 403 同時包含 `Giving up after`：Resolved。分類器明確排除該 context，並有負向測試。
- task ID-only cancellation race：Resolved。每次 production `download` 建立 `DownloadOperationID`，active operation replacement、cancel 與 process cleanup 均以 operation identity 隔離。
- production process boundary test gap：Resolved。fixture 透過 production `download` path 驅動真實 `Process`，驗證 `cancel(taskId:)`、PID 退出、cleanup 與 cookies fallback 排除。

## New Findings Verdict

- post-termination stale-operation success：Resolved。`Process` termination cleanup 後、成功結果解析前再次檢查 operation identity。
- outer retry-flow success return：Resolved。每次 `executeAttempt` 成功後、`executeWithTransient403Retries` 返回前再次檢查 cancellation 與 operation identity，並以 regression test 固定行為。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- non-blocking triaged finding count: 2
- critical_gap: false
- round_type: micro
- rationale: 兩位 fresh reviewer 均確認 late finding 已修正，且所有 seeded findings 已解決；Suggestion 均為非阻塞測試強化建議。

## Fix Actions

- fixed: `Tubify/Services/YTDLPService.swift`：在 retry helper 成功返回前補上 cancellation／operation identity check。
- fixed: `TubifyTests/YTDLPServiceTests.swift`：加入成功 attempt 後取消的 regression test。
- no design change、contract change 或 scope expansion。

## Reviewer Summary

- Reviewer A：無 Critical、無 Warning；確認 outer-flow guard 與全部 seeded findings 已 resolved。
- Reviewer B：無 Critical、無 Warning；確認 outer-flow guard、operation isolation、Process fixture 與 classifier；另提出兩項非阻塞測試建議。
- verification：focused `YTDLPServiceTests` 60 tests、0 failures；full suite 280 tests、0 failures；`git diff --check` 通過。

## Decision

passed
