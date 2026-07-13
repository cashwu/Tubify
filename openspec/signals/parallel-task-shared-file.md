---
id: parallel-task-shared-file
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
---

# Parallel tasks 共用修改檔案

標記 `[P]` 的 tasks SHALL 具有互不重疊的修改檔案與依賴；若兩個 task 會編輯同一 source 或 test file，必須移除平行標記或重新分配合理的檔案邊界。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：paste 與 error-summary tasks 同時指定 `TubifyTests/ContentViewTests.swift`。
