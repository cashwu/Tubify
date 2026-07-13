# Propose Plus Review — Round 2

## Reviewer Findings

### Critical

None.

### Warning

- reviewer: A+B
  - severity: Warning
  - confidence: 95
  - layer: design
  - location: `openspec/changes/add-clear-all-subtitles/tasks.md` §1.2；`openspec/changes/add-clear-all-subtitles/specs/subtitle-selection/spec.md` §Preserve default subtitle selection
  - summary: `Preserve default subtitle selection` 仍要求一般 XCTest 證明 private `@State` 的 `.onAppear` 初始化行為，但任務沒有可觀察接縫，測試只能重寫同一段集合邏輯而無法證明 view 實際使用它。
  - recommendation: 指定第二個可測試接縫，或移除不可達成的 XCTest 保證並改成明確的 SwiftUI preview 手動 wiring 驗證。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 1
- critical_gap: false
- round_type: full

confidence filter 後保留一項由 A+B 獨立確認、confidence 95 的 design Warning；依機械決策規則，本輪必須進入 next_round，且下一輪為 full。

## Fix Actions

- 修改 `openspec/changes/add-clear-all-subtitles/tasks.md`：移除無法觀察 private `.onAppear` 的 task 1.2 自動測試宣稱，避免為既有全選行為新增第二個測試 helper；改在 task 2.1 以 SwiftUI preview 明確驗證 `Preserve default subtitle selection` 與 view wiring。
- 修正後重新執行 spec 註解平衡、識別字 cross-grep、open signal 跨任務參照檢查與 `spectra validate add-clear-all-subtitles`，全部通過。

## Decision

next_round

仍有一項 surviving Warning；完成上述修正後進入 full Round 3。
