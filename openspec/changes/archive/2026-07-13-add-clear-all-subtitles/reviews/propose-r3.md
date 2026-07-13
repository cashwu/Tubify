# Propose Plus Review — Round 3

## Reviewer Findings

### Critical

None.

### Warning

- reviewer: A
  - severity: Warning
  - confidence: 100
  - layer: text
  - location: `openspec/changes/add-clear-all-subtitles/tasks.md` §3.1
  - summary: task 3.1 仍宣稱 `xcodebuild test` 可確認「字幕預設全選」測試通過，但 Round 2 已移除該 XCTest 保證，且 task 2.1 已改由 SwiftUI preview 手動驗證，屬修正傳播遺漏。
  - recommendation: 將 task 3.1 的自動測試範圍限於字幕清空純函式與既有音軌測試；字幕預設全選保留於 task 2.1 的 SwiftUI preview 手動驗證。

### Suggestion

None.

Reviewer B 回報 No findings。

## Rating

- Critical: 0
- Warning: 1
- critical_gap: false
- round_type: full

confidence filter 後保留一項 confidence 100 的 text Warning；依機械決策規則，本輪必須進入 next_round。因本輪為 full、沒有 Critical 且所有 surviving Warning 都是 text，下一輪為 micro。

## Fix Actions

- 修改 `openspec/changes/add-clear-all-subtitles/tasks.md`：將 task 3.1 的 `xcodebuild test` 覆蓋範圍同步為字幕清空純函式與既有音軌測試，並明列字幕預設全選仍由 task 2.1 的 SwiftUI preview 手動驗證。
- 修正只同步驗證文字，未改變任何行為或設計陳述，因此下一輪維持 micro。
- 修正後重新執行 spec 註解平衡、識別字 cross-grep、open signal 跨任務參照檢查與 `spectra validate add-clear-all-subtitles`，全部通過。

## Decision

next_round

仍有一項 surviving Warning；完成上述純文字同步後進入 micro Round 4。
