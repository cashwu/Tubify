---
id: paste-monitor-window-scope
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
---

# App-level keyboard monitor 缺少目標視窗 gate

App-level local keyboard monitor 若只檢查 responder 類型，會在 Settings 或其他非目標視窗攔截事件。設計此類快捷鍵時，SHALL 同時定義可識別目標視窗的 gate 與非目標視窗負向驗證。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer A，confidence 100，Warning）：Command-V routing 未確認 event window 屬於主下載介面。
