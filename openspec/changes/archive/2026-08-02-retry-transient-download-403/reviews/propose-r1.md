# Cash Propose Review — Round 1

## Reviewer Findings

### Critical

None.

### Warning

1. `severity`: `Warning`; `confidence`: `100`; `layer`: `design`; `location`: `design.md` Decision 4、`proposal.md` Proposed Solution、`Tubify/Services/YTDLPService.swift:585`、`Tubify/ViewModels/DownloadManager.swift:974`; `summary`: 原 contract 宣稱 backoff 取消可立即結束，但既有 `cancel(taskId:)` 無法喚醒一次性 2、5、10 秒 sleep，最長會延遲 10 秒並佔用 queue slot；`recommendation`: 定義可由 `cancelledTaskIds` 實際中斷或有界觀察的最小 backoff 機制，並測試取消不需等待完整 delay。來源：Reviewer A。
2. `severity`: `Warning`; `confidence`: `100`; `layer`: `design`; `location`: `design.md` Decisions 3/5、`tasks.md` 1.3、`Tubify/Services/YTDLPService.swift:214-264`; `summary`: 原 test seam 只驅動內層 retry helper，無法證明 production `download` 的 first template、`shouldRetryWithCookies` 與 cookie-template fallback 真實分支；`recommendation`: 定義 production 與測試共用、可注入 scripted executor 的 internal download orchestration seam，或縮減無法驗證的測試承諾。來源：Reviewer A。

### Suggestion

1. `severity`: `Suggestion`; `confidence`: `75`; `layer`: `design`; `location`: `design.md` Decision 2 / Risks; `summary`: 只以 generic `HTTP Error 403: Forbidden` 子字串分類會包含 webpage、subtitle、fragment 及 yt-dlp 已內部重試的 403，artifacts 卻只描述 direct media 403 與 17 秒 app backoff；`recommendation`: 明確擴大範圍與請求放大風險，或把分類縮到本次日誌的 direct video-data 403 context。來源：Reviewer B。

## Rating

- 累積 blocking Critical: 0
- 累積 blocking Warning: 2
- 非 blocking triaged findings: 0
- `critical_gap`: `false`
- `round_type`: `full`

兩個 confidence 100 的 design Warning 直接違反 proposal 的取消與可驗證性承諾，在 first round 均進入 cumulative blocking set；Suggestion 為 confidence 75，保留為非 blocking 改善項。本輪不能通過，需在修正後由 Reviewer V 驗證。

## Fix Actions

- 修改 `proposal.md`、`design.md`、`specs/download-reliability/spec.md` 與 `tasks.md`：將 backoff 拆為不超過 100 ms 的 async sleep slices，使 actor 可在 slice 間觀察 `cancelledTaskIds`，取消後不再啟動 process 並釋放 queue slot，不新增 `Task` registry、continuation 或 synchronization primitive。
- 修改 `proposal.md`、`design.md`、`specs/download-reliability/spec.md` 與 `tasks.md`：定義 internal `executeDownloadFlow` 為 production 與測試共用的唯一 orchestration seam，其範圍包含 first template、target-403 retries、`shouldRetryWithCookies`、cookie-template provider 與第二條 retry path，並以 scripted executor、slice sleeper 與 cancellation probe 直接驗證 production branches。
- 修改 `proposal.md`、`design.md`、`specs/download-reliability/spec.md` 與 `tasks.md`：採用 Reviewer B 建議，把分類縮為 `unable to download video data: HTTP Error 403: Forbidden`，明確排除 webpage、subtitle、fragment downloader 與 `Giving up after` context；同時說明 17 秒只限制 Tubify backoff，不限制 yt-dlp process 時間或內部 request 數。
- Post-fix mechanical self-check：spec annotation counts 為 0/0，2 個 requirements、10 個 scenarios、1 個 example 與 8 個 tasks 無過期數字宣稱；`executeDownloadFlow`、target error fragment、100 ms slices、2/5/10 delays 已跨 artifacts 同步；open signals 無 `check` 需執行。
- 重新執行 `/Users/cash/Github/Tubify/.cash-skills/bin/cash validate "retry-transient-download-403"`：`Validation passed.`

## Decision

next_round
