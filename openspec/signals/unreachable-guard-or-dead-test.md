---
id: unreachable-guard-or-dead-test
type: recurring-finding
status: open
occurrences: 5
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r1.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r2.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r4.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r6.md
---

# 防護檢查或失敗注入在實際機制下永遠不生效

新增的防護條件若在控制流上恆為 false，或測試的失敗注入手段在目標平台上根本不會失敗，就會產出「有 scenario、有 task，但永遠測不到也永遠不會生效」的死條文與永遠綠燈的死測試。撰寫防護與失敗注入時 SHALL 先驗證觸發路徑實際可達：對防護，確認上游沒有更早、條件更強的等價檢查；對失敗注入，確認該手段在目標平台的語意確實會使目標 API 失敗。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A confidence 90 與 Reviewer B 獨立提出，Critical）：清理開頭的 `isCancelled(...cancellationProbe: nil)` 恆為 false，因為 `executeWithTransient403Retries` 在成功 attempt 後已做過條件更強的同一檢查（`Tubify/Services/YTDLPService.swift:367`）；且 `activeDownloadOperations`、`cancelledOperationIDs`、`runningProcesses` 皆為 `private`（`:159-161`），seam 測試無法注入 staleness。已移除該檢查與對應 scenario、task，改由既有檢查承擔語意，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 2（Reviewer V，confidence 80，Warning，disposition fix-introduced）：task 要求「以唯讀權限使候選檔刪除失敗」，但 macOS 的 unlink 取決於父目錄寫入權限，`chmod 444` 的檔案仍會被 `FileManager.removeItem` 成功刪除，測試三項斷言仍全綠卻從未進入非致命失敗分支。已改為 `chflags uchg` immutable flag 並要求 `nouchg` 還原，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer B，confidence 80，Warning，disposition fix-introduced）：為修復「刪除條件未排除目錄」而新增的 `isRegularFileKey` 檢查被排在 mtime 檢查之前，而兩者來自同一次 `getattrlist`——讀不到 mtime 的項目其型別必然也讀不到，會先被「型別讀取失敗跳過」吃掉，使「候選檔 mtime 讀取失敗」從「有未發現的注入手段」變成原理上不可達，design 卻反過來以「沒有穩定注入手段」豁免其測試。已把兩個屬性合併為單次 `resourceValues(forKeys:)` 讀取、收斂為單一非致命分支，並以 ACL `deny readattr` 注入驅動，verdict 為 resolved。這是本 change 第三次出現同類缺陷。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer A 與 Reviewer B 獨立提出，confidence 100，Critical，disposition fix-introduced）：為修復「型別檢查與刪除之間的 TOCTOU」而新增的 task，其核心斷言在 contract 定義下恆不成立——目錄的 `resourceValues` 讀取成功並回傳 `isRegularFile = false`，走的是候選過濾分支，既非屬性讀取失敗也非刪除失敗，因此 `unlink` 根本不會被呼叫，而該項目既不在 `deleted` 也不在 `failed`。已改為不經過候選條件序列、直接驗證刪除原語性質的獨立測試，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer B，confidence 80，Warning，disposition new）：spec 的六項 MUST 條件之一「路徑不等於最終輸出路徑本身」在形態 regex 存在下恆為真——最終輸出檔名去掉 stem 前綴後恰為單一副檔名而不含點，而 regex 每個分支都要求至少一個點（實測九種檔名形狀全部不通過）。該條件永遠攔不下任何項目，也不可能有 task 驅動。已移出 spec 的規範性條件，實作保留為 defence-in-depth 並在 design 明文標記其不可達，verdict 為 resolved。
