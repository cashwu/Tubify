# Propose Plus Review — Round 2

## Reviewer Findings

### Critical

無。

### Warning

1. reviewer: A
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `specs/download-ui-workflows/spec.md` — Persistent completion navigation；`tasks.md` — 2.3
   - summary: task 只檢查 preference 值，沒有走 completion branch 驗證未設定時保留、明確 true 時移除。
   - recommendation: 在 `DownloadManagerTests.swift` 驅動兩種 completion path 並斷言 retention/removal。

2. reviewer: A
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `design.md` — Lightweight settings validation / Interfaces and data / Acceptance criteria；`tasks.md` — 3.1；`proposal.md` — Impact
   - summary: validator tests 沒有共用可觀察 seam 或具體 test file，無法證明 private SwiftUI presentation 使用同一套判斷。
   - recommendation: 定義 internal 純 validator 與結果型別，新增 `TubifyTests/SettingsViewTests.swift` 並明列三種結果。

3. reviewer: A
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `specs/download-ui-workflows/spec.md` — Download folder contains spaces；`design.md` — Acceptance criteria；`tasks.md` — 3.1、4.1
   - summary: 含空格資料夾的 folder-picker scenario 沒有實際驗證步驟。
   - recommendation: 明列設定有效含空格路徑、開啟 picker、確認起始目錄的手動整合檢查。

4. reviewer: B
   - severity: Warning
   - confidence: 90
   - layer: design
   - location: `design.md` — UI-activated persisted task recovery / Focus-aware paste monitor lifecycle；`tasks.md` — 1.1、2.1、4.1；`specs/download-ui-workflows/spec.md` — Persisted task recovery after UI activation / Main view reappears
   - summary: manager-wide activation flag 與 view-local request queues 會在 ContentView 重建或 callback 缺席時遺失 selection request；新 view 又因 idempotency 無法重新取得 request。
   - recommendation: 定義 manager-owned unresolved request registry，以及 manager-wide recovery 與 per-UI-session delivery 的分層 idempotency。

### Suggestion

無。

## Rating

- Critical: 0
- Warning: 4
- critical_gap: false
- round_type: full

confidence filter 後仍有 4 個 design-layer Warning，因此本輪決策為 `next_round`，下一輪維持 full。

## Fix Actions

- 修改 `openspec/changes/improve-download-ui-workflows/proposal.md`：新增 `TubifyTests/SettingsViewTests.swift` structured Impact entry。
- 修改 `openspec/changes/improve-download-ui-workflows/design.md`：定義 manager-wide recovery 與 per-session delivery、manager-owned unresolved request registries、`deactivateUI(sessionID:)`、純 command validator、completion-path 測試與含空格 picker 驗收。
- 修改 `openspec/changes/improve-download-ui-workflows/specs/download-ui-workflows/spec.md`：加入新 UI session 重播與 UI 缺席時保留 selection request scenarios，並把重複 activation 限定為同一 session。
- 修改 `openspec/changes/improve-download-ui-workflows/tasks.md`：補 completion branch 測試、`SettingsViewTests.swift` validator seam、含空格 picker 手動驗收，以及跨 session callback reconnect 測試。
- 重新執行 `spectra validate improve-download-ui-workflows`：通過。
- 重新執行 mechanical self-check：7 requirements、29 scenarios，註解配對、數量、識別字與 signal-derived checks 均通過。
- 重新推導：UI session 與 request registry 修改屬於行為／設計變更，下一輪維持 full。

## Decision

next_round
