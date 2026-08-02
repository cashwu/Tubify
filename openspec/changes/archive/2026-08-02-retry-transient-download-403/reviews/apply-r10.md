# Cash Apply Review — Round 10

## Reviewer Findings

### Critical

None.

### Warning

None.

## Resolved Finding

- closed pipe fd busy-spin：Resolved。`drainPipes` 每輪依 `open` 狀態重建 `pollfd`，closed fd 使用 `-1` 排除；`POLLNVAL`、EOF 與 terminal read error 都會停用該 fd。新增 fixture 明確以 `exec 1>/dev/null` 讓 stdout 先 EOF，而 stderr descendant 保持開啟並延遲輸出。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- non-blocking triaged finding count: 0
- critical_gap: false
- round_type: micro
- decision: passed

## Verification

- focused `YTDLPServiceTests`: 65 tests, 0 failures
- full suite: 285 tests, 0 failures
- `git diff --check`: passed
- Cash validation: passed
- Cash tasks: 11/11 complete
- `implementation-notes.md`: no deviation/open-question entries

## Reviewer Summary

- Code reviewer：0 Critical、0 Warning；確認 closed fd、`POLLNVAL` 與 stdout EOF/stderr idle fixture。
- Code simplifier：無必要簡化；確認 fd 重建流程與 fixture 複雜度合理。
