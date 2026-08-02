---
id: stale-operation-post-termination-success
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/apply-r2.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r3.md
---

# Stale operation 在 Process 成功結束後仍可能回傳 success

若 operation identity 只在 process termination status 或 retry 起點檢查，stale operation 可能在成功結果解析前穿越 cancellation 邊界並回傳舊結果。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B，Warning）：Process status 0 後缺少 operation identity check；已在成功結果處理前補檢查，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 3（Reviewer A、Reviewer B，Warning）：outer retry flow 在成功 attempt 後缺少最後的 cancellation／operation identity check；已補上並以 regression test 固定，verdict 為 Resolved。
