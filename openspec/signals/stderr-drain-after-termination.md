---
id: stderr-drain-after-termination
type: recurring-finding
status: open
occurrences: 7
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/apply-r4.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r5.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r6.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r7.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r8.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r9.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r10.md
---

# Process termination 後 stderr drain 可能遺失 403

`terminationHandler` 與 `readabilityHandler` 沒有完成順序保證；若未先 drain pipe，最後的 target 403 可能變成未知錯誤而不觸發 retry。drain 也必須有界，避免殘留 writer 阻塞 actor。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — apply-r4 Warning：termination 後直接停止 handler，可能遺失 stderr；已改為 bounded non-blocking drain。
- 2026-08-02 — `retry-transient-download-403` — apply-r5 Warning：bounded drain 需涵蓋 continuous writer 與 cleanup evidence；已補 deadline 每輪檢查與 writer PID assertion。
- 2026-08-02 — `retry-transient-download-403` — apply-r6：確認 stderr drain、deadline、lock ordering 與 fixture cleanup，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r7：確認 stdout/stderr 共用 drain deadline，並通過 focused/full suite；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r8 Warning：shared deadline 下 stdout 可能讓 stderr starvation；已加入每個 fd 的 immediate nonblocking read 與 regression test，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r9 Warning：單次 immediate read 仍可能漏掉第二個 stderr chunk；已改用雙 fd poll loop 並補超過 8 KiB stderr regression test，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r10 Warning：EOF fd 留在 poll 集合可能 busy-spin；已以 `fd = -1` 排除並補 stdout EOF/stderr idle regression test，verdict 為 Resolved。
