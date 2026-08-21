# Cash Propose Review — Round 2

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 逐一驗證並檢查 fix propagation。

### Cumulative blocking set verdicts

- **C1: resolved** — 決策 6 明確區分致命與非致命失敗，Contract 第 2 點逐條對應，spec 已拆為「判斷前提不成立時放棄整輪清理」與「單一候選檔處理失敗時繼續處理其餘候選檔」兩個 scenario，無殘留矛盾。verifying reviewer：Reviewer V。
- **C2: resolved** — 決策 5 將列舉目錄改由 `finalPath` 的 parent 推導，spec requirement 條件 1 與 Contract 第 2 點一致；Contract 第 3 點的快照取自 `outputDirectory`，因兩者被要求相同而自洽。verifying reviewer：Reviewer V。
- **C3: resolved** — spec delta 全檔已無 `cookies` 與 `stale` 任何字串，scenario 已改為不繫結 cookies 觸發條件的通用形式，不再與 master spec `### Requirement: 403 重試維持下載生命週期與 cookies contract` 衝突。verifying reviewer：Reviewer V。
- **C4: resolved** — 決策 7 明說不呼叫 `isCancelled` 並引用 `Tubify/Services/YTDLPService.swift:367`，Contract 第 4 點與 task 2.2 逐字要求不呼叫，spec 與 tasks 已無 stale operation 條文，清理函式簽名已移除 `operationID`。verifying reviewer：Reviewer V。
- **W1: resolved** — 決策 8 已把宣稱範圍限縮為「production `download` 的多 attempt 成功路徑走到清理程式碼」，並明文說明無注入點、fixture 使用不含 `--cookies-from-browser safari` 的 template、不宣稱涵蓋 cookies fallback 分支；proposal Non-Goals 同步補上。verifying reviewer：Reviewer V。

五個 member 全部以 verified resolution 離開 cumulative blocking set。

### Warning

**F1**（Reviewer V）
- `severity`: Warning
- `confidence`: 80
- `layer`: design
- `location`: tasks.md task 1.12
- `summary`: 「以唯讀權限使其中一個候選檔刪除失敗」在 macOS 上不成立——unlink 取決於父目錄的寫入權限而非檔案本身，0444 的檔案仍會被 `FileManager.removeItem` 成功刪除。依此 task 寫出的測試會兩個候選檔都被刪掉，而三項斷言仍全部成立，形成永遠綠燈卻從未走到非致命分支的死測試。
- `recommendation`: 改以 `chflags uchg` 設定 immutable flag，測試結束前以 `nouchg` 還原；不得改成把整個目錄設為唯讀。
- `disposition`: fix-introduced
- `introduced_by`: Round 1 `## Fix Actions` 的「**C1 — 修復**」，其中新增 task 1.12 驅動非致命失敗分支。

**F2**（Reviewer V）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: design.md 決策 5
- `summary`: 決策 5 宣稱「`executeDownload` 的 60 秒最近媒體檔 fallback 找到別處的檔案」時會因目錄不符而放棄清理，但該 fallback 只列舉 `outputDirectory` 本身（`Tubify/Services/YTDLPService.swift:849`），其回傳路徑的 parent 恆等於 `outputDirectory`，永遠通過相等性檢查。決策 5 對 C2 後半的 fallback 錯 stem 風險實際貢獻為零。
- `recommendation`: 刪去括號中的 fallback 一項，明說該風險不受決策 5 約束，緩解僅來自決策 2、決策 3 與決策 4，並在 Risks 新增對應殘餘風險條目。
- `disposition`: fix-introduced
- `introduced_by`: Round 1 `## Fix Actions` 的「**C2 — 修復**」，其中新增決策 5。

### Suggestion

**F3**（Reviewer V，`confidence` 50）
- `location`: design.md Implementation Contract 第 7 點 ↔ tasks.md 1.10、1.11
- `summary`: Contract 第 7 點只列舉兩項 seam 測試覆蓋，但 tasks 實際有四個 seam 測試；1.10 與 1.11 在 Contract 中沒有對應條目，只能追溯到 spec scenario。
- `disposition`: fix-introduced
- `introduced_by`: Round 1 `## Fix Actions` 的「**C2 — 修復**」（新增 task 1.10）與「**C1 — 修復**」（新增 task 1.11）。

**F4**（Reviewer V，`confidence` 50）
- `location`: design.md 決策 8；tasks.md 1.2–1.8
- `summary`: 「多 attempt 成功」case 走 `cookieTemplateProvider == nil` → `allowTransient403Retries: true` 路徑（`Tubify/Services/YTDLPService.swift:299`），而 `download` 沒有 `sleeper` 注入點，第一次 403 後會實際 `Task.sleep` 2 秒；七個 production fixture 測試合計約增加 14 秒，此成本未被記錄。
- `disposition`: fix-introduced（Reviewer V 原標 `new`，經主 agent 更正）

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 2
- 非 blocking triaged finding count: 2
- `critical_gap`: false
- `round_type`: micro

rationale：Round 1 的五個 blocking member 全部取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開 cumulative blocking set。本輪新增 F1 與 F2 兩個 `fix-introduced` 的 Warning，兩者 `confidence` 皆 ≥ 80，依規則進入 cumulative blocking set，因此 `decision: next_round`。F1 與 F2 均經主 agent 覆核程式碼確認成立：`Tubify/Services/YTDLPService.swift:849` 證實 fallback 只列舉 `outputDirectory`，`:299` 證實無 cookies template 時 `allowTransient403Retries` 為 true。

## Fix Actions

**Disposition correction — F4 由 `new` 更正為 `fix-introduced`**。Reviewer V 原標 `new`。主 agent 依「接受 `new` 標記前必須檢查是否位於本 loop 的 fix-touched location」規則覆核：決策 8 是 Round 1 「**W1 — 修復**」直接改寫的段落，而 2 秒 backoff 正是該修復把 fixture template 從帶 cookies 改為不帶 cookies 所導致——帶 cookies 的原設計走 `allowTransient403Retries: cookieTemplateProvider == nil` 為 false 的路徑，首段不 backoff。因此該缺陷源自 Round 1 的 fix action，更正為 `fix-introduced`，`introduced_by` 為「**W1 — 修復**」。F4 經 confidence filter 後為 `Suggestion`，依規則不因 disposition 而 blocking。

**F1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md` task 1.12：失敗注入機制改為對候選檔設定 immutable flag（`chflags uchg`）並於測試結束前以 `nouchg` 還原，並明文禁止改以 `chmod` 降低檔案本身權限（說明 macOS 的 unlink 取決於父目錄寫入權限）。同步修改 `openspec/changes/cleanup-orphaned-part-files/design.md` Implementation Contract 第 7 點，加入同一條注入方式的規範與兩項禁止事項，使 design 與 tasks 對此機制的敘述一致。

**F2 — 修復**。修改 design.md 決策 5：刪去括號中的 fallback 一項，只保留「使用者自帶 `-o`」；新增段落明說該 fallback 只列舉 `outputDirectory`（引用 `Tubify/Services/YTDLPService.swift:849`），其回傳路徑 parent 恆等於 `outputDirectory`，永遠通過相等性檢查，因此本決策對 fallback 錯 stem 風險沒有貢獻，緩解完全由決策 2、決策 3、決策 4 承擔。同步在 design.md `## Risks / Trade-offs` 新增「fallback 取錯 stem」條目記錄該殘餘風險。

**F3 — 修復**。修改 design.md Implementation Contract 第 7 點，補上「最終輸出路徑的父目錄與 `outputDirectory` 不同時不清理」與「最終輸出檔不存在時放棄整輪清理並回傳原本的最終輸出路徑」兩項；同步修改 tasks.md task 1.10 與 1.11，各自補上對 Contract 第 7 點的追溯引用。

**F4 — 修復**。修改 design.md 決策 8，明文記錄不帶 cookies 的 template 使 `allowTransient403Retries` 為 true（引用 `Tubify/Services/YTDLPService.swift:299`），「多 attempt 成功」case 每次固定付出 2 秒 backoff，並說明這是 `download` 缺少 `sleeper` 注入點的既有限制，本變更不為此新增注入點。

**驗證**：修復涉及 design 與 tasks 兩個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

next_round

cumulative blocking set 中有 2 個 `fix-introduced` 的 Warning（F1、F2）已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第二輪，下一輪位置為第三輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 F1 與 F2 給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
