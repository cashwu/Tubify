# Cash Apply Review — Round 6

## Reviewer Findings

本輪為前一個 apply run 以 `decision: passed` 結束後的新 run 第一輪（full round）。觸發原因是外部 review 指出 delta spec 對 TOCTOU 窗口中的非目錄項目過度保證刪除一定成功；主 agent先將該句改為「可能移除」，並明訂失敗時走既有非致命處置，再進入本輪品質關卡。

### Warning

**W1**（Reviewer A）
- `severity`: Warning
- `confidence`: 100
- `layer`: design
- `location`: `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 2 與 `## Risks / Trade-offs`
- `summary`: spec 已正確改為刪除操作「可能」移除非目錄項目並處理 `unlink` 失敗，但 design 仍以「會被刪除」「都會刪除」絕對描述 hardlink 與 TOCTOU 路徑替換，直接與決策 6、Implementation Contract 及實作的 `unlink` 失敗分支矛盾。
- `recommendation`: 將 design 同步為「若 `unlink` 成功」才產生名稱或內容損失；失敗時明確銜接決策 6 的單一候選檔非致命規則。

### Suggestion

**S1**（Reviewer A）
- `severity`: Suggestion
- `confidence`: 100
- `layer`: text
- `location`: `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 5、決策 7、決策 8
- `summary`: 三項 code-facing claim 的語意成立，但引用的 `YTDLPService.swift` 行號已隨程式碼演進漂移，會誤導後續讀者。
- `recommendation`: 移除不穩定的行號，保留 symbol 與控制流語意引用。

Reviewer B 回報 no findings，確認新 spec 句子與 `Darwin.unlink`、warning、`CleanupOutcome.completed.failed`、繼續其他候選檔、不拋錯及不改變下載結果的 contract 一致，且文字已足夠直接。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- 非 blocking triaged finding count: 1
- `critical_gap`: false
- `round_type`: full

rationale：本輪是新 run 第一輪，所有 surviving Warning 均為 blocking。W1 有 spec、design、Implementation Contract、實作與測試的直接對照證據，`confidence` 100，進入 cumulative blocking set；S1 為同步性行號問題，不進入 blocking set。因此 `decision: next_round`。

## Fix Actions

**W1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 2 與 `## Risks / Trade-offs`：hardlink 改為「若被 `unlink` 成功刪除」才失去連結名稱；TOCTOU 路徑替換改為「可能」刪除非目錄項目，並明訂 `unlink` 失敗時依決策 6 的單一候選檔非致命規則處理。symbolic link、FIFO、socket 與另一個一般檔案的後果都限縮為刪除成功時才成立。

**S1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 5 與決策 7，移除已漂移的 `YTDLPService.swift` 行號，以 `executeDownload` fallback 與 `executeWithTransient403Retries` 成功 return 前 guard 的 symbol／控制流語意作為穩定引用。pre-round mechanical self-check 另找到決策 8 的 `allowTransient403Retries` 行號同樣漂移，已在同一輪一併移除。

**驗證**：已執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；annotation counts 平衡，15 個 scenario 與 6 個 Example 的數量未因本輪修正改變，相關絕對措辭已跨 spec／design 搜尋並同步。

**Change 目錄外檔案修改**：本輪 Fix Actions 只修改 `openspec/changes/cleanup-orphaned-part-files/design.md`，不呼叫 `touched ensure` 或 `touched record`。

## Decision

next_round
