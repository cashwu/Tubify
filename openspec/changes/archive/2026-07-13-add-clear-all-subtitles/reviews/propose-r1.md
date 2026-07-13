# Propose Plus Review — Round 1

## Reviewer Findings

### Critical

None.

### Warning

- reviewer: B
  - severity: Warning
  - confidence: 90
  - layer: design
  - location: `openspec/changes/add-clear-all-subtitles/tasks.md` §1.1、§2.1；`openspec/changes/add-clear-all-subtitles/specs/subtitle-selection/spec.md` §Clear all selected subtitles
  - summary: 現有測試 target 無 SwiftUI inspection/UI testing 工具，且字幕與音軌為 private `@State`；原任務無法以一般 XCTest 驗證按鈕 wiring、視窗保持開啟與音軌不變，容易退化成只測 `Set.removeAll()`。
  - recommendation: 採用同檔案內的最小純函式作為可測試接縫，讓 XCTest 驗證字幕狀態轉換，並將按鈕 wiring、視窗未 dismiss 與音軌 UI 未變列為明確手動驗證。

### Suggestion

None.

Reviewer A 回報 No findings。

## Rating

- Critical: 0
- Warning: 1
- critical_gap: false
- round_type: full

confidence filter 後保留一項 confidence 90 的 design Warning；依機械決策規則，本輪必須進入 next_round，且下一輪為 full。

## Fix Actions

- 修改 `openspec/changes/add-clear-all-subtitles/tasks.md`：指定同檔案內、internal 的 `clearSelectedSubtitles(_:)` 純函式作為最小測試接縫，並拆清 XCTest 狀態驗證與 SwiftUI preview 手動 wiring 驗證。
- 修正後重新執行 spec 註解平衡、識別字 cross-grep、open signal 跨任務參照檢查與 `spectra validate add-clear-all-subtitles`，全部通過。

## Decision

next_round

仍有一項 surviving Warning；完成上述修正後進入 full Round 2。
