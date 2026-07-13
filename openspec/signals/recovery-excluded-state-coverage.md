---
id: recovery-excluded-state-coverage
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r1.md
---

# Recovery contract 的排除狀態缺少負向覆蓋

Recovery 設計若明定部分狀態不得轉換或啟動副作用，spec 與 tasks SHALL 為這些排除狀態提供負向 scenario 與測試，不得只測會恢復的正向狀態。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer A+B，confidence 100，Warning）：七種非中斷狀態只有 design contract，沒有 spec scenario 或 task coverage。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer A，confidence 100，Warning）：七種排除狀態的測試未明確斷言三類 selection callback 都沒有副作用。
