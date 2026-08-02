---
id: target-403-giving-up-context-classification
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/apply-r1.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r2.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r4.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r6.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r7.md
---

# Target 403 classification 未排除 Giving up after context

HTTP 403 retry classification 若只匹配 video-data 片段，未同時排除 `Giving up after` context，可能把已明確耗盡 downloader retries 的錯誤誤判為可恢復 target 403。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer A，confidence 100，Warning）：`isRetryableDownload403` 未排除同時含有 target 403 與 `Giving up after` 的錯誤。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已以分類條件與負向測試修復；本輪 verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 4（Reviewer A、Reviewer B）：production 多行 stderr context 保留與負向 fixture 已修復；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 6（Reviewer A、Reviewer B）：確認多行 context 與 bounded drain 無 blocking warning；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 7（Code reviewer）：確認完整 error context、無 `lastError` fallback，且無 blocking warning；verdict 為 Resolved。
