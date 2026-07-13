---
id: tasks-stale-verification-scope
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/add-clear-all-subtitles/reviews/propose-r3.md
---

# tasks.md 驗證範圍在修正後仍保留過期宣稱

前置任務移除或改變自動測試保證後，後續整體驗證任務仍宣稱測試命令涵蓋已不存在的案例。這類修正傳播遺漏會讓 apply 階段把無法達成的驗證文字當成完成條件。

修改測試任務或驗證方式時，SHALL 同步檢查所有後續驗證任務與命令描述，確保其宣稱的覆蓋範圍仍和實際測試、手動檢查分工一致。

## Occurrences

- 2026-07-13 — `add-clear-all-subtitles` — spectra-propose-plus round 3（Reviewer A，confidence 100，Warning）：移除字幕預設全選的 XCTest 保證後，整體 `xcodebuild test` 任務仍誤稱會覆蓋該行為。
