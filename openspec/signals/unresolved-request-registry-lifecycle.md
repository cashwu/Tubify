---
id: unresolved-request-registry-lifecycle
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r2.md
---

# Unresolved request registry 未跟隨來源生命週期

Manager 保存 unresolved UI request 時，registry SHALL 在來源 task 被移除或清空後同步清理，且 async work 註冊 request 前必須重新確認來源仍存在，避免新 UI session 重播 stale request。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 2（Reviewer B，confidence 90，Warning）：task removal、clear-all 與延遲 metadata／playlist completion 可能留下引用已刪除來源的 request。
