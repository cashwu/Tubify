---
id: ui-session-request-replay-gap
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r2.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r1.md
---

# One-shot recovery 與 UI session 重建造成 request 遺失

Manager-wide idempotent recovery 若把待處理 request 只送到 view-local state，UI session 重建後可能永久失去操作入口。設計 SHALL 區分一次性 work activation 與每個 UI session 的 unresolved request delivery。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer B，confidence 90，Warning）：selection callbacks 寫入舊 `ContentView` state，新 view 又被 activation flag 阻止重播。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer A，confidence 100，Warning）：實作測試尚未證明 playlist 與 video-or-playlist unresolved requests 對同 session 不重複、對新 session 各重播一次。
