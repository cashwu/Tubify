---
id: contract-spec-definition-mismatch
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r1.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r6.md
---

# design Implementation Contract 與 spec 對同一概念的定義不一致

同一個失敗處置、範圍界定或資料來源若在 `design.md` 的 Implementation Contract 與 delta spec 的 requirement／scenario 各寫一次，兩份敘述容易分歧。實作者依 Contract 寫程式、驗收者依 spec 判定，分歧會直接變成驗收爭議。每個此類概念 SHALL 在兩份 artifact 中可逐條對應，且以同一組條件表述。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 100，Critical）：Contract 規定「讀取 `finalPath` 的 mtime 失敗時直接 return」，spec scenario 卻要求 mtime 讀取失敗時「記錄該失敗並繼續處理其餘候選檔案」。已改為明確區分致命失敗（放棄整輪清理）與非致命失敗（記錄後繼續下一個），spec 拆為兩個 scenario，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A confidence 100 與 Reviewer B 獨立提出，Critical）：spec 定義候選檔案限定為最終輸出路徑的父目錄，Contract 卻列舉傳入的 `outputDirectory` 參數，兩者在使用者自帶 `-o` 時並不相同。已改為列舉目錄由 `finalPath` 的 parent 推導、與 `outputDirectory` 不符時放棄清理，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 6（Reviewer A，confidence 100，Warning）：delta spec 已把 TOCTOU 窗口中的非目錄項目改為「可能」被刪除並涵蓋 `unlink` 失敗，但 design 的 hardlink 與 Risks 敘述仍保留「會被刪除」的絕對成功保證。已同步限縮為僅在 `unlink` 成功時產生名稱或內容損失，失敗時依單一候選檔非致命規則處理，round 7 verdict 為 resolved。
