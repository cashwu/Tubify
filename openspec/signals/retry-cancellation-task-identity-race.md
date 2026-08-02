---
id: retry-cancellation-task-identity-race
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/apply-r1.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r2.md
---

# Retry cancellation 只以 task ID 綁定 operation

可重入的 retry flow 若只以可重用 `taskId` 儲存取消狀態，舊 operation 與新 operation 可能互相清除或觀察 cancellation signal，造成取消後錯誤啟動 process 或新下載受到舊取消影響。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer B，confidence 95，Warning）：backoff 中的舊 flow 與同一 `taskId` 的新 download 可能互相清除 `cancelledTaskIds`。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已以 `DownloadOperationID`、active replacement 與 operation-keyed process cleanup 修復；本輪 verdict 為 Resolved。
