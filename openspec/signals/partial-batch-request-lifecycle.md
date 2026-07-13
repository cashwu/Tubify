---
id: partial-batch-request-lifecycle
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r3.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r4.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r5.md
---

# Partial batch removal 未正規化 request 與選項

批次工作在部分 child 被移除後，SHALL 以仍存在的 tasks 重新聚合選項、維持或解除 unresolved request，並限制 confirmation 只影響 active task 的實際可用選項，避免其餘 child 卡住或遭 removed-only selection 污染。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus rounds 3–5（Reviewer B，confidence 95，Warning）：playlist media request 的建立、註冊後移除與舊 request confirmation 依序暴露 partial-batch lifecycle 缺口。
