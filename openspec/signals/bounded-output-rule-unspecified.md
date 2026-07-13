---
id: bounded-output-rule-unspecified
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
---

# Bounded output 缺少可驗收的邊界規則

Artifacts 使用 bounded、limited 或 truncated 描述輸出時，SHALL 指定長度單位、上限、截斷方式與邊界測試，避免不同實作者產生不一致行為。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：error summary 未定義上限、ellipsis 或 Unicode 計數方式。
