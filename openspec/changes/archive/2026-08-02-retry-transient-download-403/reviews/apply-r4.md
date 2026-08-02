# Cash Apply Review — Round 4

## Reviewer Findings

### Critical

None.

### Warning

1.
   - severity: Warning
   - location: `Tubify/Services/YTDLPService.swift:661-665`
   - summary: `readDataToEndOfFile()` 在 actor 上同步 drain，殘留 writer 可能造成無界等待。
   - disposition: fixed in next round；改為 bounded non-blocking `drainPipe`，每輪檢查 deadline，timeout 後關閉 read end。
   - reviewer source: Reviewer B

## Seeded Findings Verdict

- Sol stderr drain race：Resolved by the fix actions below.
- Sol multiline `Giving up after` context overwrite：Resolved by complete attempt error context and production-boundary regression test.
- Existing 403 classifier, cookies contract, cancellation and operation isolation：Resolved.

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- round_type: micro
- decision: next_round

## Fix Actions

- fixed in next round: `Tubify/Services/YTDLPService.swift`：以 non-blocking `read`/`poll` bounded drain 取代無界 EOF read。
- fixed in next round: `TubifyTests/YTDLPServiceTests.swift`：加入 writer 不關閉的 bounded-drain regression test。
