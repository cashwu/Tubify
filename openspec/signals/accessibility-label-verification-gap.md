---
id: accessibility-label-verification-gap
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
---

# Accessibility label requirement 缺少 accessibility-tree 驗證

Keyboard focus 與 accessibility label 是不同契約。要求 descriptive labels 時，驗收 SHALL 包含 Accessibility Inspector、VoiceOver 或等價的 accessibility-tree 檢查，不能只靠 focus traversal 或 source scan。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：驗證只涵蓋 `.focusable(false)` scan 與鍵盤巡覽，未檢查 localized labels。
