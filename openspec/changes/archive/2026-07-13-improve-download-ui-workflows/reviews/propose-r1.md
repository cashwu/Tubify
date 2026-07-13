# Propose Plus Review — Round 1

## Reviewer Findings

### Critical

無。

### Warning

1. reviewer: A
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `design.md` — Focus-aware paste monitor lifecycle；`specs/download-ui-workflows/spec.md` — Context-aware paste handling；`proposal.md` — What Changes
   - summary: 貼上 routing 只檢查 first responder，未確認 event 是否來自主下載視窗，Settings 非文字控制聚焦時仍可能新增任務。
   - recommendation: 增加可測試的 main-window gate、Settings 負向 scenario 與測試。

2. reviewer: A+B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `design.md` — Implementation Contract / Behavior；`tasks.md` — 1.1；`specs/download-ui-workflows/spec.md` — Persisted task recovery after UI activation
   - summary: contract 排除七種非中斷狀態，但 spec 與 tasks 沒有對應負向 scenario 與測試。
   - recommendation: 增加 table-driven coverage，驗證狀態及 metadata、selection、queue 副作用均不變。

3. reviewer: A+B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `design.md` — Focus-aware paste monitor lifecycle / Interfaces and data；`tasks.md` — 2.1；`specs/download-ui-workflows/spec.md` — Main view reappears
   - summary: artifacts 宣稱 helper tests 可驗證 private SwiftUI monitor lifecycle，但沒有可觀察 seam，也未為實際 `.onAppear`／`.onDisappear` wiring 指定完整驗證路徑。
   - recommendation: 定義可注入的 monitor controller，並將實際 view lifecycle wiring 明列為手動整合驗證。

4. reviewer: A
   - severity: Warning
   - confidence: 90
   - layer: design
   - location: `design.md` — Persistent completion and notification navigation / Interfaces and data；`tasks.md` — 2.3；`proposal.md` — Impact
   - summary: notification output routing 沒有可隔離 `FileManager`／`NSWorkspace` 的測試 seam，Impact 也未指定承載測試的檔案。
   - recommendation: 定義可注入的 routing helper，並新增明確的 notification test target file。

5. reviewer: B
   - severity: Warning
   - confidence: 95
   - layer: design
   - location: `design.md` — UI-activated persisted task recovery；`tasks.md` — 1.1
   - summary: `fetchingInfo` 同時代表單支影片、playlist placeholder 與 playlist child，現有設計沒有定義恢復 routing。
   - recommendation: 明確區分三種來源，並定義不改 `DownloadTask` Codable shape 時的安全降級與測試。

6. reviewer: B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `tasks.md` — 2.1、2.2
   - summary: 兩個 `[P]` 任務同時修改 `TubifyTests/ContentViewTests.swift`，違反 parallel task 的檔案隔離條件。
   - recommendation: 將 error-summary tests 移至獨立且合理的 test file，或移除 `[P]`。

7. reviewer: B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `specs/download-ui-workflows/spec.md` — Actionable download errors；`design.md` — Actionable error presentation；`tasks.md` — 2.2
   - summary: 「bounded summary」沒有具體長度、截斷與 Unicode 計數規則，無法一致實作或驗收。
   - recommendation: 指定 `Character` 上限、ellipsis 規則，並新增 overlong 與 Unicode 測試。

8. reviewer: B
   - severity: Warning
   - confidence: 100
   - layer: design
   - location: `specs/download-ui-workflows/spec.md` — Navigate controls by keyboard；`tasks.md` — 3.2、4.1
   - summary: 現有驗證只涵蓋 focus/source scan，沒有驗證 accessibility tree 內的 localized labels。
   - recommendation: 加入 Accessibility Inspector 或 VoiceOver 的明確手動檢查。

### Suggestion

無。

## Rating

- Critical: 0
- Warning: 8
- critical_gap: false
- round_type: full

confidence filter 後仍有 8 個 Warning，且全部屬於 design layer，因此本輪必須進入下一輪，下一輪類型為 full。

## Fix Actions

- 修改 `openspec/changes/improve-download-ui-workflows/proposal.md`：新增 `TubifyTests/DownloadItemViewTests.swift` 與 `TubifyTests/NotificationServiceTests.swift` 的 structured Impact entries。
- 修改 `openspec/changes/improve-download-ui-workflows/design.md`：加入 main-window marker、可注入 `PasteMonitorController`、三種 `fetchingInfo` routing、安全降級、160 `Character` 摘要規則、可注入 `NotificationOutputRouter`、排除狀態與 accessibility 驗證契約。
- 修改 `openspec/changes/improve-download-ui-workflows/specs/download-ui-workflows/spec.md`：加入 Settings 非文字 focus、playlist placeholder/child recovery、七種排除狀態及超長錯誤摘要 scenarios。
- 修改 `openspec/changes/improve-download-ui-workflows/tasks.md`：同步新增負向與 routing 測試、真實 lifecycle 手動檢查、notification seam tests、accessibility label 驗證，並將 error tests 移至獨立檔以保持 `[P]` 隔離。
- 重新執行 `spectra validate improve-download-ui-workflows`：通過。
- 重新執行 mechanical self-check：7 requirements、27 scenarios，註解配對、數量、識別字與 signal-derived checks 均通過。
- 重新推導：上述修改新增並調整行為與設計陳述，下一輪維持 full。

## Decision

next_round
