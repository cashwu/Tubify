---
id: backoff-cancellation-observation-gap
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/propose-r1.md
---

# Backoff 取消 contract 缺少可觀察邊界

當作業在 async backoff 期間仍佔用 concurrency slot，artifacts 若要求取消及時結束，SHALL 定義 cancellation signal 如何喚醒或有界觀察 wait，並驗證取消後不再啟動新作業。單純在一次性 sleep 前後檢查 flag，不足以支持「立即取消」的 contract。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — cash-propose round 1（Reviewer A，confidence 100，Warning）：既有 `cancel(taskId:)` 只寫入 `cancelledTaskIds`，無法喚醒整段 2、5、10 秒 sleep，與 artifacts 的 backoff 及時取消承諾衝突。
