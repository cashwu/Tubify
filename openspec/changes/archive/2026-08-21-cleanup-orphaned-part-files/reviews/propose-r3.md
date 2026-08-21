# Cash Propose Review — Round 3

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 逐一驗證並檢查 Round 2 修復的 fix propagation。

### Cumulative blocking set verdicts

- **F1: resolved** — tasks.md task 1.12 已將注入方式改為 `chflags uchg` immutable flag 並要求測試結束前以 `nouchg` 還原，明文禁止 `chmod`；design.md Implementation Contract 第 7 點以 SHALL 規範同一機制，且同時禁止 `chmod` 與「整個目錄設為唯讀」。immutable flag 會使 `FileManager.removeItem` 以 EPERM 失敗，確實進入決策 6 的非致命分支，死測試風險消失。兩處對機制與 `nouchg` 還原的要求一致、無矛盾。verifying reviewer：Reviewer V。
- **F2: resolved** — design.md 決策 5 已刪去錯誤的 fallback 宣稱，改為明說該 fallback 只列舉 `outputDirectory` 本身。Reviewer V 核對 `Tubify/Services/YTDLPService.swift:849` 確為 `let dirURL = URL(fileURLWithPath: outputDirectory)` 且 `contentsOfDirectory(at:)` 非遞迴，回傳路徑 parent 恆等於 `outputDirectory`；新增的 Risks「fallback 取錯 stem」條目與決策 5 用語一致，與 spec requirement 條件 1、Contract 第 2 點的相等性檢查仍自洽。verifying reviewer：Reviewer V。

兩個 member 皆以 verified resolution 離開 cumulative blocking set，該集合現為空。

### 一併驗證通過的項目

- **F3 修復正確**：Contract 第 7 點現列四項 seam 覆蓋，對應 tasks 1.10、1.11、1.12、1.13，四對四、無遺漏也無多出。
- **F4 修復正確**：決策 8 的 2 秒 backoff 敘述限定在「多 attempt 成功」case（`Tubify/Services/YTDLPService.swift:299`），Contract 第 5 點的「單次失敗」case 走 `isRetryableDownload403` 回傳 false 的路徑（`:586`）而單次結束，兩者路徑不同、敘述互不衝突。
- **全域一致性**：12 個 spec scenario 全部有 task 覆蓋；Contract 第 6 點的八項 production 覆蓋與 tasks 1.2–1.9 一一對應；決策 1–8 與 Contract 1–7 的所有交叉引用皆指向存在的條目；`:367`、`:849`、`:299` 三處程式碼引用行號經逐一核對皆正確；全域已無 `chmod` 或唯讀注入的舊敘述。

### 經 confidence filter 丟棄的 findings

Reviewer V 另回報兩個 `confidence` 低於 50 的 finding，依 confidence filter 丟棄，其 downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- 非 blocking triaged finding count: 0
- `critical_gap`: false
- `round_type`: micro

rationale：cumulative blocking set 的兩個 member F1、F2 均取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開集合，集合現為空。本輪新增的兩個 finding `confidence` 分別為 45 與 40，皆低於 50，依 confidence filter 丟棄，不進入 cumulative blocking set。post-filter cumulative blocking set 不含任何 blocking Critical 或 blocking Warning，pass 條件成立，因此 `decision: passed`。

## Fix Actions

None; pass condition met.

**Downgrade trace — Reviewer V N1（`confidence` 45，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 2「**F3 — 修復**」）已依 confidence filter 丟棄**。該 finding 指出 Contract 第 7 點的四項 seam 覆蓋中，只有 tasks task 1.12 沒有補上「design Implementation Contract 第 7 點」的追溯引用。主 agent 覆核其 `layer`：該修正僅為交叉引用的一致性，不影響任何行為或設計陳述，維持 `text`，不重分類為 `design`。

**Downgrade trace — Reviewer V N2（`confidence` 40，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 2「**F1 — 修復**」）已依 confidence filter 丟棄**。該 finding 指出 design Contract 第 7 點列了兩項禁止（不得用 `chmod`、不得將整個目錄設為唯讀），tasks task 1.12 只複述了 `chmod` 一項。Reviewer V 自述兩處無矛盾，僅為單向遺漏。主 agent 覆核其 `layer`：該修正僅為複述完整度，design 側的規範本身已完整且對實作具約束力，不影響行為或設計陳述，維持 `text`，不重分類為 `design`。

**Change 目錄外檔案修改**：本輪未執行任何 fix action，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

passed
