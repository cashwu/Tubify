# Cash Apply Review — Round 5

## Reviewer Findings

### Critical

None.

### Warning

1.
   - severity: Warning
   - location: `Tubify/Services/YTDLPService.swift:707-731`
   - summary: bounded drain 後的 fixture descendant writer cleanup 尚未被明確驗證。
   - disposition: fixed in next round；fixture 改為持續寫入，read end 關閉後以 `EPIPE` 結束，並以 writer PID assertion 驗證退出。
   - reviewer source: Reviewer A、Reviewer B

## Seeded Findings Verdict

- stderr drain race：Resolved；deadline 每輪檢查，continuous writer 不會繞過上限。
- multiline `Giving up after` context overwrite：Resolved；完整 error context 與直接 assertion 已加入。
- Existing 403 classifier, cookies contract, cancellation and operation isolation：Resolved.

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- round_type: micro
- decision: next_round

## Fix Actions

- fixed in next round: `Tubify/Services/YTDLPService.swift`：保留 bounded drain，移除不受平台允許的 process-group 強殺嘗試，維持既有 root `Process` cleanup contract。
- fixed in next round: `TubifyTests/YTDLPServiceTests.swift`：驗證 continuous writer 在 pipe 關閉後退出。
