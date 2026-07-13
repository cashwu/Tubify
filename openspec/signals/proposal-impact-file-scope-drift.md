---
id: proposal-impact-file-scope-drift
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r5.md
---

# Proposal Impact 與實際修改檔案漂移

Apply 階段若調整或確認實作 scope，proposal `## Impact` 的 affected-code entries SHALL 與 change 實際修改檔案同步，不得保留未修改的路徑或漏列必要檔案。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 5（Reviewer A，confidence 100，Warning）：`## Impact` 列出三個未由本 change 修改的 test files。
