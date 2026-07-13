# Propose Plus Review — Round 3

## Reviewer Findings

### Critical

無。

### Warning

1. reviewer: A
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `specs/download-ui-workflows/spec.md` — Activate completion notification / Activate notification without a valid path；`design.md` — Persistent completion and notification navigation / Acceptance criteria；`tasks.md` — 2.3、4.1
   - summary: router 單元測試未證明 `UNUserNotificationCenterDelegate` wiring 會轉交 router 並完成 response handling，手動驗證也未實際點擊有效或失效通知。
   - recommendation: 定義 delegate 共用 completion bridge，並加入有效通知與輸出檔已失效通知的實際點擊驗證。

2. reviewer: B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `design.md` — UI-activated persisted task recovery；`tasks.md` — 1.1；`Tubify/Views/PlaylistSelectionView.swift`
   - summary: 現有 `PlaylistSelectionView.onDisappear` 會把 parent teardown 當成取消並刪除 placeholder，直接破壞跨 session unresolved playlist request replay。
   - recommendation: 只有顯式取消才 resolve request；parent disappearance 只 detach UI，並驗證新 session 可重播且 placeholder 保留。

### Suggestion

無。

## Rating

- Critical: 0
- Warning: 2
- critical_gap: false
- round_type: full

confidence filter 後仍有 2 個 design-layer Warning，因此本輪決策為 `next_round`，下一輪維持 full。

## Fix Actions

- 修改 `openspec/changes/improve-download-ui-workflows/design.md`：新增 playlist 明確取消／parent teardown 契約、`handleActivatedNotification(userInfo:completionHandler:)` bridge、completion 單元測試與有效／失效通知點擊驗收。
- 修改 `openspec/changes/improve-download-ui-workflows/specs/download-ui-workflows/spec.md`：新增 playlist selection parent disappearance 時保留 placeholder 與 unresolved request scenario。
- 修改 `openspec/changes/improve-download-ui-workflows/tasks.md`：要求移除 `.onDisappear` 隱式取消、禁止 interactive dismissal、手動驗證跨 session playlist replay，並加入 notification delegate bridge tests 與 notification activation 手動檢查。
- 重新執行 `spectra validate improve-download-ui-workflows`：通過。
- 重新執行 mechanical self-check：7 requirements、30 scenarios，註解配對、數量、識別字與 signal-derived checks 均通過。
- 重新推導：playlist cancellation 與 notification delegate bridge 都是行為／設計變更，下一輪維持 full。

## Decision

next_round
