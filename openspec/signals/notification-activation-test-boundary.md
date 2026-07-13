---
id: notification-activation-test-boundary
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r3.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r1.md
---

# Notification activation 缺少可觀察 routing 與 delegate 驗證

系統通知 activation 同時包含 userInfo routing、外部 side effect 與 completion handler。Artifacts SHALL 定義可注入的 routing seam，並以自動測試或明確整合檢查驗證 delegate wiring 與 completion semantics。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus rounds 1、3（Reviewer A，confidence 90–100，Warning）：初版既無 Finder reveal seam，後續仍缺少 delegate-to-router 與實際 notification activation 驗證。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer B，confidence 90，Warning）：notification delegate 在非同步 launch task 才初始化，冷啟動 activation 可能早於 delegate wiring。
