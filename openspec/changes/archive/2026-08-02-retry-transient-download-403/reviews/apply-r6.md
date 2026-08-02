# Cash Apply Review — Round 6

## Reviewer Findings

### Critical

None.

### Warning

None.

### Suggestion

- stdout/stderr 目前各自最多 drain 1 秒；未來若需要更嚴格的總時間契約，可改用 shared deadline。
- 任意 descendant process management 不屬於本 change contract；fixture 已驗證 writer 在 pipe 關閉後退出。

## Seeded Findings Verdict

- Sol stderr drain race：Resolved。handler 停止後以 lock 排除 callback race，`drainPipe` 使用 non-blocking `read`/`poll` 並在每輪檢查 deadline。
- Sol multiline `Giving up after` context overwrite：Resolved。`DownloadResultHolder` 保留完整 error lines，classifier 看到完整 context，且 production fixture 直接 assertion 錯誤內容與 invocation count。
- target 403 classifier、cookies contract、cancellation、operation isolation、root Process cleanup：Resolved。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- non-blocking triaged finding count: 2
- critical_gap: false
- round_type: micro
- decision: passed

## Verification

- focused `YTDLPServiceTests`: 63 tests, 0 failures
- full suite: 283 tests, 0 failures
- `git diff --check`: passed
- Cash tasks: 11/11 complete
- `implementation-notes.md`: no deviation/open-question entries

## Reviewer Summary

- Reviewer A：無 Critical、無 Warning；確認 Sol warnings、bounded drain、error context 與 cleanup fixture 已修正。
- Reviewer B：無 Critical、無 Warning；確認 deadline、poll/read error handling、lock ordering 與 multiline classification。
