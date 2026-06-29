---
id: tasks-stale-cross-reference
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-06-29
last_seen: 2026-06-29
links:
  - openspec/changes/route-download-command-by-site/reviews/propose-r2.md
---

# tasks.md 跨任務參考在重新編號後失效

在 `tasks.md` 中，任務以「（見 X.Y）」相互參考。當新增任務群組或插入任務導致後續群組／任務編號順延時，既有的「（見 X.Y）」字面參考未同步更新，會指向錯誤甚至無關的任務，誤導 apply 階段的實作者。

撰寫或修改 `tasks.md` 時，凡調整任務編號（新增群組、插入任務、群組順延），SHALL 一併檢查並更新所有「見 N.M」字面跨參考，確保仍指向原意圖的任務。

## Occurrences

- 2026-06-29 — `route-download-command-by-site` — spectra-propose-plus round 2（Reviewer A，confidence 88，Warning）：新增 task group 4 使 UI／測試群組由 4、5 順延為 5、6 後，task 2.1 的「（見 5.1）」仍指向已變成 `EmptyStateView` 文案的 5.1，而非單元測試任務 6.1。
