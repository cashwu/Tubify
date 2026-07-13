---
id: ui-state-test-without-observable-seam
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/add-clear-all-subtitles/reviews/propose-r1.md
  - openspec/changes/add-clear-all-subtitles/reviews/propose-r2.md
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r2.md
---

# UI state 測試宣稱缺少可觀察接縫

`tasks.md` 宣稱一般單元測試可驗證 private UI state 或生命週期 wiring，但實作範圍沒有提供測試可呼叫的接縫，也沒有可觀察 view 行為的 UI 測試機制。這會讓 apply 階段重寫同一段集合邏輯來製造表面測試，卻無法證明實際 UI 使用該邏輯。

撰寫 UI 狀態任務時，SHALL 讓自動測試對應實際共用的最小接縫，或明確把無法由現有 test target 觀察的 wiring 指定為手動驗證；不得宣稱測試覆蓋不存在的觀察路徑。

## Occurrences

- 2026-07-13 — `add-clear-all-subtitles` — spectra-propose-plus rounds 1–2（Reviewer B、Reviewer A+B，confidence 90–95，Warning）：字幕清空與 `.onAppear` 預設全選均位於 private `@State`，原 tasks 未提供一般 XCTest 可觀察的實作接縫。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus rounds 1–2（Reviewer A+B，confidence 100，Warning）：monitor lifecycle 與 Settings validation 原先宣稱由 XCTest 覆蓋，但 artifacts 未定義 view 實際共用的 observable seam。
