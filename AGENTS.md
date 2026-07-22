<!-- CASH:START -->

# Cash Project Guidance

本專案只使用 Cash workflow invocations。Spectra CLI 與 `openspec/` artifact schema 仍具權威；Cash skills 會繼續使用 `spectra` commands 與 `openspec/` artifacts。標準 `spectra-*` skills 是否存在不改變 Cash-only routing。

- 結構化討論 → `$cash-discuss`
- 規劃或提出變更 → `$cash-propose`
- 實作或繼續 tasks → `$cash-apply`
- 實作期間需求變更 → `$cash-ingest`，再繼續 `$cash-apply`
- 封存完成的變更 → `$cash-archive`
- 提交單一選定變更 → `$cash-commit`

有效 workflow：`$cash-discuss`? → `$cash-propose` → `$cash-apply` ⇄ `$cash-ingest` → `$cash-archive` → `$cash-commit`。

## 向量模型未下載時的替代方式

Spectra 的語意搜尋依賴本機向量模型。若模型尚未下載，不需要中斷或要求先下載，直接改用路徑與檔案讀取：

- 使用者直接給 change 名稱 → 直接讀 `openspec/changes/<name>/` 底下的 artifacts（找不到時用 `spectra list --parked` 確認是否被 parked）
- 問程式碼或需求相關的問題 → 直接用 Grep／Read 搜尋 `openspec/specs/` 與程式碼來回答

<!-- CASH:END -->
