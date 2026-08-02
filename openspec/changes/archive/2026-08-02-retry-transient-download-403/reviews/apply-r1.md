# Cash Apply Review — Round 1

## Reviewer Findings

### Critical

None.

### Warning

1.
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `Tubify/Services/YTDLPService.swift:425-429`；對應 `design.md:40`、`Implementation Contract:67`、`spec.md:38`；測試 `TubifyTests/YTDLPServiceTests.swift:158-177`
   - summary: `isRetryableDownload403` 只檢查 target 403 片段，未排除同時包含 `Giving up after` 的錯誤；含有 `Giving up after` 與 target 403 片段的訊息仍會進入 retry。
   - recommendation: 在 classification 明確排除 `Giving up after` context，並新增同時包含 target 片段與 `Giving up after` 的測試，確認不等待、不啟動額外 process。
   - reviewer source: Reviewer A

2.
   - severity: Warning
   - confidence: 95
   - layer: design
   - location: `Tubify/Services/YTDLPService.swift:240-370`
   - summary: 取消狀態只以 `taskId` 索引；舊的 retry flow 在 backoff 期間仍存活時，新下載會於 `download()` 清除同一 `taskId` 的 `cancelledTaskIds`，導致舊 flow 可能在取消後繼續啟動 process，或取消訊號反而影響新的下載。
   - recommendation: 讓取消與 download operation 綁定，或在重新排程前確保舊 flow 完全結束；若需 generation／identity 機制，先更新 design。
   - reviewer source: Reviewer B — Quality
   - introduced_by: `Tubify/Services/YTDLPService.swift:303-370` 新增的跨 backoff retry loop，以及 `Tubify/Services/YTDLPService.swift:240-250` 新增的 flow 接線。

3.
   - severity: Warning
   - confidence: 88
   - layer: design
   - location: `TubifyTests/YTDLPServiceTests.swift:435-483`
   - summary: cancellation 測試使用 scripted `attemptExecutor` 與 `cancellationProbe`，未實際執行 `executeDownload`、`Process.terminate()` 或 `cancel(taskId:)`；因此無法驗證 active process 終止、`cancelledTaskIds` 傳遞、process lifecycle cleanup，以及取消後不會觸發 cookies fallback。
   - recommendation: 增加涵蓋 production process boundary 的測試，驗證 active process cancellation 與 backoff 取消後確實不啟動下一個 process。
   - reviewer source: Reviewer B — Quality
   - introduced_by: `TubifyTests/YTDLPServiceTests.swift:435-483` 新增的 cancellation 測試實作。

### Suggestion

1.
   - severity: Suggestion
   - confidence: 75
   - layer: text
   - location: `Tubify/Services/YTDLPService.swift:212-213`
   - summary: 註解宣稱重試僅在原始 command 含 Safari cookies 時啟用，但目前 target 403 retry 對無 cookies template 也會生效，文字與目前 403 policy 不一致。
   - recommendation: 修改註解，區分 target 403 retry policy 與 Safari cookies fallback 的啟用條件。
   - reviewer source: Reviewer A

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 3
- non-blocking triaged finding count: 1
- critical_gap: false
- round_type: full
- rationale: 本輪沒有 Critical，但三個 Warning 在 unseeded first round 皆屬 blocking。其中特別是 task ID 重用造成的 cancellation race 需要新增 design 未定義的 identity／generation 機制，觸發 cash-apply Fix-loop design circuit breaker，因此不能以未經 ingest 的實作方式繼續。

## Fix Actions

- needs-design：針對 `Tubify/Services/YTDLPService.swift:240-370` 的 task ID cancellation race，需要定義 operation identity／generation 或等價的取消綁定機制；`design.md` 目前未定義該機制，依 circuit breaker 不實作，將 decision 設為 `aborted` 並導向 `$cash-ingest`。
- Abort triage bucket 1：`Tubify/Services/YTDLPService.swift:240-370` 的 cancellation identity race 維持本 change obligation，後續需先經 `$cash-ingest` 更新 design／scope。
- Abort triage bucket 1：`Tubify/Services/YTDLPService.swift:425-429` 的 `Giving up after` 與 target 403 classification 缺口維持本 change obligation，尚未修復。
- Abort triage bucket 1：`TubifyTests/YTDLPServiceTests.swift:435-483` 的 production process boundary cancellation coverage 缺口維持本 change obligation，尚未修復。
- 非 blocking triage：Reviewer A 的 `Tubify/Services/YTDLPService.swift:212-213` 註解一致性建議為 text-only Suggestion，不進入 blocking set。
- None; 本輪因 design circuit breaker aborted，沒有實作 fix，fixed_files 為 0。

## Decision

aborted

本輪因 resolving cancellation identity race 需要 `identity/generation` 機制，而該機制未在 `design.md` 定義，觸發 Fix-loop design circuit breaker。請先透過 `$cash-ingest retry-transient-download-403` 更新 contract／design，再處理 bucket 1 findings；不建議在未更新 artifacts 的情況下原樣重跑 review。
