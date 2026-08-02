# Cash Apply Review — Round 8

## Reviewer Findings

### Critical

None.

### Warning

None.

## Resolved Findings

- shared deadline stderr starvation：Resolved。`drainPipe` 即使 deadline 已過，也會先對該 fd 執行一次 immediate nonblocking read；stdout 耗盡 deadline 時，stderr 仍能讀到 target 403。
- fixture descendant cleanup：Resolved。starvation 與 hanging-writer tests 在 deferred cleanup 中 probe PID、送 `TERM`，仍存活時再送 `KILL`，最後才移除 fixture directory。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- non-blocking triaged finding count: 0
- critical_gap: false
- round_type: micro
- decision: passed

## Verification

- focused `YTDLPServiceTests`: 64 tests, 0 failures
- full suite: 284 tests, 0 failures
- `git diff --check`: passed
- Cash validation: passed
- Cash tasks: 11/11 complete
- `implementation-notes.md`: no deviation/open-question entries

## Reviewer Summary

- Code reviewer：0 Critical、0 Warning；確認 immediate read 修正與 deferred descendant cleanup。
- Code simplifier：無必要簡化；確認 cleanup 與 starvation fixture 複雜度均符合測試目的。
