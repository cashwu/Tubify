# Cash Propose Review — Round 6

## Reviewer Findings

本輪為新 run 的第一輪（full round）。觸發原因是第二個 run 以 `decision: passed` 結束後，第三份外部 review 提出三個問題，主 agent 驗證並修復後啟動本輪。本輪 cumulative blocking set 從空開始。

外部 review 的三個原始問題與主 agent 的處置摘要：

- **外部問題 1（Critical）**：型別檢查與 `removeItem` 之間的 TOCTOU 使 spec 的絕對 `MUST NOT 刪除目錄` 無法保證。主 agent 實測 `unlink(目錄)` 以 `EPERM` 失敗且目錄完好，新增決策 9 改用 `Darwin.unlink` 並禁用 `removeItem`。
- **外部問題 2（Warning）**：task 1.16 的 `0o111` 注入同時使列舉與 unlink 失敗，無法區辨 guard 是否生效。主 agent 實測 `0o333` 使列舉失敗而 unlink 可行，並新增決策 10 的 `cleanupObserver` 使「放棄整輪清理」可被斷言。
- **外部問題 3（附帶）**：失敗 warning 沒有驗收。主 agent 以 observer 涵蓋六條失敗路徑。

### Critical

**M1**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併）
- `severity`: Critical
- `confidence`: 100
- `layer`: design
- `location`: tasks.md 1.18；design.md Implementation Contract 第 2、3 點；specs/download-reliability/spec.md scenario「型別檢查通過後被替換為目錄時刪除仍失敗」
- `summary`: task 1.18 的核心斷言在 Contract 定義下不可能成立，且該測試對決策 9 完全不具鑑別力。Reviewer B 實測確認：對目錄呼叫 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])` **讀取成功**並回傳 `isRegularFile = false`，因此「目錄一開始就存在且通過名稱層條件」的近似時序會走型別檢查的候選過濾分支，既非「屬性讀取失敗」也非「`unlink` 失敗」；而 Contract 第 3 點把 `failed` 逐字定義為「屬性讀取失敗或 `unlink` 失敗而跳過的候選檔名」，該目錄兩邊都不在，`unlink` 從頭到尾不會被呼叫。後果有二：依 Contract 正確實作時 1.18 是**恆紅**測試；若實作者為了讓它變綠而把「非一般檔案」塞進 `failed`，則直接違反 Contract 第 3 點且 `unlink` 依然沒被呼叫。扣掉該斷言後 1.18 與既有 task 1.14 完全重複。結果是決策 9 與 spec 新增的兩條保證都沒有能真正驅動它們的驗收手段。
- `recommendation`: 把 1.18 改為**直接驗證刪除原語**的測試，不經過候選條件序列：對含檔案的目錄呼叫 `Darwin.unlink` 斷言 rc == -1、`errno == EPERM`、目錄與內層檔案完好；對指向目錄的 symbolic link 斷言 rc == 0、連結消失而 target 完整。另新增 code review task 確認刪除點使用 `Darwin.unlink` 且清理路徑不出現 `FileManager.removeItem`。
- `disposition`: fix-introduced
- `introduced_by`: 本輪為修復外部問題 1 新增的決策 9、spec scenario 與 task 1.18。

### Warning

**W1**（Reviewer A）
- `severity`: Warning
- `confidence`: 100
- `layer`: design（Reviewer A 原標 `text`，經主 agent 更正）
- `location`: tasks.md 2.2；design.md Implementation Contract 第 2 點
- `summary`: task 2.2 仍寫 `cleanupOrphanedPartFiles(finalPath:outputDirectory:preexistingEntryNames:taskId:)`，缺少本輪新增的 `observer` 參數，而同一 task 後半段又要求「每個 return 路徑 MUST 以本次結果呼叫 `observer` 恰好一次」，task 內部自相矛盾。
- `recommendation`: 簽名同步為含 `observer:`。
- `disposition`: fix-introduced
- `introduced_by`: 本輪新增決策 10 與 Contract 第 2 點的 `observer` 參數。

**W2**（Reviewer B）
- `severity`: Warning
- `confidence`: 80
- `layer`: design
- `location`: specs/download-reliability/spec.md requirement 條件 5；design.md Implementation Contract 第 2 點
- `summary`: 條件 5「該路徑不等於最終輸出路徑本身」在條件 3 的形態 regex 存在下**恆為真，永遠不會攔下任何項目**。最終輸出檔名去掉 `<stem>.` 前綴後恰為單一副檔名而不含點，而 regex 每個分支都要求剩餘部分至少含一個點。Reviewer B 實測涵蓋 `video.mp4`、`a.b.mp4`、`video.part`、`video.mp4.part`、`clip.f401.mp4.part`、`x.ytdl`、無副檔名七種形狀，全部不通過名稱條件。這是 `unreachable-guard-or-dead-test` 在本 change 的第四次出現，而該 signal 逐字要求「對防護，確認上游沒有更早、條件更強的等價檢查」。條件 5 是 spec 的六項 MUST 之一，卻沒有也不可能有 task 驅動。
- `recommendation`: 從 spec 的規範性條件移除，實作可保留為 defence-in-depth，但 design MUST 明文標記其在現行 regex 下不可達。
- `disposition`: new

**W3**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: design.md Implementation Contract 第 8 點末段；tasks.md `## 3. Verification`；specs/download-reliability/spec.md 兩個失敗 scenario 的 `THEN 系統 SHALL 記錄該失敗`
- `summary`: 外部問題 3 只修復了一半。observer 斷言證明的是「該 return 路徑被走到」，不證明該路徑寫了日誌。design 第 8 點自己保留了一條責任「日誌內容本身仍由 code review 驗證」，但 tasks 第 3 節只有 3.2，且 3.2 逐字只涵蓋成功刪除的 info 日誌。四個致命放棄路徑與兩條非致命失敗路徑的 warning 日誌既沒有測試也沒有 code review task——正是 Round 4 W1 判定必須消除的「既無測試也無 code review 的分支」，以「design 指派了驗證責任、tasks 沒有承接」的形式復活。
- `recommendation`: 新增 Verification task，以程式碼審查確認各分支的 warning 日誌與 `observer` 呼叫成對出現。
- `disposition`: unresolved-prior（Reviewer B 標 `fix-introduced`；兩者皆為 blocking disposition，主 agent 取更準確的 `unresolved-prior`——外部問題 3 本身未被完整修復）

**W4**（Reviewer A）
- `severity`: Warning
- `confidence`: 80
- `layer`: design
- `location`: design.md Implementation Contract 第 8 點的 seam 測試覆蓋清單
- `summary`: 第 8 點仍只列 7 項，但 tasks 現有 8 個 `attemptExecutor` seam 測試。Round 5 的 F1 修復才剛把此清單校正為一一對應，本輪新增 1.18 時未同步，對應關係再度破裂。
- `recommendation`: 補上對應項；若 1.18 依 M1 改為刪除原語測試，則另立 Contract 條目。
- `disposition`: fix-introduced
- `introduced_by`: 本輪新增 task 1.18 時未同步 Contract 第 8 點。

### Suggestion

**S1**（Reviewer A 與 Reviewer B 獨立提出，`confidence` 70，合併）：多處以 `FileManager.removeItem` 為前提的敘述已隨決策 9 過期——Contract 第 2 點禁用預取快取的理由寫成「條件 6 正是為了防守目錄被遞迴刪除」與決策 9 直接矛盾；決策 2 開頭、Contract 第 8 點的 `chmod` 說明、spec scenario 的 `##### Example:` 亦同。同一份 spec 的兩個 Example 對 `removeItem` 的角色互相矛盾。

**S2**（Reviewer B，`confidence` 65）：`CleanupOutcome` 宣告為 `Equatable` 且以**有序陣列**攜帶 `deleted` / `failed`，但順序完全來自 `contentsOfDirectory(atPath:)`，該順序在 APFS 上既非建立順序也非字典序（實測：依 f407→f400 建立 8 個檔案，列舉回傳 `f401, f400, f406, f407, …`）。任何含兩個以上元素的相等性斷言會在 CI 上間歇失敗。

**S3**（Reviewer B，`confidence` 50）：task 1.16 未寫明 `attemptExecutor` MUST 在改權限之前建立**最終輸出檔本身**，否則檢查順序會在更早一步就以 `.finalPathUnavailable` 放棄；task 1.10 未寫明 `outputDirectory` MUST 實際存在，照抄既有 seam 測試的 `/Downloads` 會先命中 `.snapshotUnavailable`。

**S4**（Reviewer A，`confidence` 55）：task 1.16 未寫明候選檔的建立者，1.11 與 1.15 都有明寫。

**S5**（Reviewer A，`confidence` 55，`disposition` unresolved-prior）：proposal 的條件清單未反映刪除機制本身提供的絕對保證。

### 經 confidence filter 丟棄的 findings

Reviewer A 的 `confidence` 45 finding（task 2.1 的 Contract 引用不完整）與 Reviewer B 的 `confidence` 45 finding（`unlink` 的 `ENOENT` 被一律記為 `failed`）依 confidence filter 丟棄，downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 1
- post-filter cumulative blocking set Warning count: 4
- 非 blocking triaged finding count: 5
- `critical_gap`: true
- `round_type`: full

rationale：本輪為新 run 的第一輪，1 個 Critical 與 4 個 Warning 全部進入 cumulative blocking set。M1 由兩位 reviewer 獨立驗證，Reviewer B 另以實測確認「目錄的 `resourceValues` 讀取成功並回傳 `isRegularFile = false`」這個關鍵事實，使 `failed` 斷言恆不成立；W2 由 Reviewer B 以七種檔名形狀實測證明條件恆為真。存在 blocking Critical，因此 `critical_gap` 為 true、`decision: next_round`。

## Fix Actions

**Disposition correction — W1 的 `layer` 由 `text` 更正為 `design`**。Reviewer A 原標 `text`。主 agent 覆核：函式簽名決定實作者寫出的 API 形狀，缺少 `observer` 參數會使同一 task 後半段的 observer 要求無法實作，屬於影響行為而非純措辭同步。依「無法判斷時一律 design」更正，仍為 Warning、`confidence` 100，維持 blocking。

**M1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md`：新增 Implementation Contract 第 9 點「刪除原語測試覆蓋」，明訂對含檔案的目錄與指向目錄的 symbolic link 直接呼叫 `Darwin.unlink` 的斷言，並說明該測試必須獨立於 seam 測試存在的理由（目錄的 `isRegularFile` 為 false，走完整流程一定在型別檢查被濾掉，`unlink` 不會被呼叫；被過濾的項目既不在 `deleted` 也不在 `failed`，斷言其出現在 `failed` 的測試恆紅）。Contract 第 2 點補一條，明訂被名稱層條件、型別檢查或 mtime 條件過濾掉的項目兩者皆不列入。修改 `openspec/changes/cleanup-orphaned-part-files/specs/download-reliability/spec.md`：scenario 改名為「刪除操作本身拒絕目錄」，GIVEN 改為直接描述刪除原語的性質而非 TOCTOU 時序，Example 說明該 scenario 驗收的是刪除操作本身、與條件是否先攔下該項目無關。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md` task 1.18 為刪除原語測試，並明文禁止改以走完整清理流程的方式驗證。

**W1 — 修復**。修改 tasks.md task 2.2，簽名同步為 `cleanupOrphanedPartFiles(finalPath:outputDirectory:preexistingEntryNames:taskId:observer:)`。

**W2 — 修復**。修改 spec.md：移除原條件 5「該路徑不等於最終輸出路徑本身」，原條件 6「該項目是一般檔案」重編號為條件 5，並補一段說明最終輸出檔為何不需要獨立排除條件。spec 內所有「條件 6」引用同步為「條件 5」。修改 design.md 決策 2，補一段記錄七種檔名形狀的實測結果，說明實作仍保留一道 `path != finalPath` 比對作為 defence-in-depth，但它恆為真、因此**不列為 spec 的獨立條件**，並引用 `openspec/signals/unreachable-guard-or-dead-test.md` 說明把永不生效的檢查寫成規範性 MUST 正是該 signal 記錄的缺陷。Contract 第 2 點的條件序列標註該比對為 defence-in-depth。design 與 tasks 的「條件 6」引用同步為「條件 5」。

**W3 — 修復**。修改 design.md Contract 第 8 點末段，把「日誌內容本身仍由 code review 驗證」改為明確指向 Verification 的 code review task，涵蓋四個致命 return 與兩個非致命 continue 分支。修改 tasks.md 新增 task 3.3，以程式碼審查確認各分支記錄含 task ID 與原因／候選檔名的 warning 日誌，且與 `observer` 呼叫成對出現；原 3.3 重編為 3.4。

**W4 — 修復**。M1 的修復把刪除原語測試獨立為 Contract 第 9 點，task 1.18 因此不再屬於第 8 點的 seam 覆蓋清單。第 8 點的 7 項與 seam tasks 1.10、1.11、1.12、1.13、1.15、1.16、1.17 恢復一一對應。

**S1 — 修復**（非 blocking，一併處理）。修改 design.md：Contract 第 2 點禁用預取快取的理由改寫為「守 mtime 判定的時效性與 symbolic link 替換窗口」，不再訴諸已由決策 9 承擔的保證；決策 2 開頭移除以 `removeItem` 為前提的敘述。修改 spec.md scenario「名稱符合形態的目錄與 symbolic link 保留」的 Example，移除把 `removeItem` 當成本系統刪除 API 的措辭。

**S2 — 修復**（非 blocking，一併處理）。修改 design.md Contract 第 3 點，明訂 `deleted` 與 `failed` 在呼叫 observer 之前 SHALL 以檔名遞增排序，並記錄 APFS 列舉順序的實測結果。修改 tasks.md 1.12 與 1.17 的斷言，明訂以排序後的預期值比較。

**S3、S4 — 修復**（非 blocking，一併處理）。修改 tasks.md task 1.16，明訂 `attemptExecutor` MUST 在改動權限之前建立最終輸出檔本身與候選檔（並說明未建立最終輸出檔會使檢查在更早一步以 `.finalPathUnavailable` 放棄）；task 1.10 明訂 `outputDirectory` MUST 實際存在且快照可取得，並提醒既有 seam 測試傳入的 `/Downloads` 不可照抄。

**S5 — 修復**（非 blocking，一併處理）。修改 proposal.md `## Proposed Solution`，在條件清單後補一句說明刪除以不會遞迴刪除目錄的系統呼叫執行。

**主 agent 自行發現並修復**：決策 6 的致命失敗清單只列三項（快照、最終輸出檔、目錄列舉），漏了決策 5 的「父目錄不符」，與 Contract 第 3 點的四個 `AbandonReason` case 不一致。已補為四項並註明各自對應一個 `AbandonReason`；決策 6 後段「三個致命失敗全部可注入」同步改為四個。

**Downgrade trace — Reviewer A `confidence` 45 的 finding 已丟棄**：task 2.1 只引用 Contract 第 3 點，未涵蓋其同時實作的第 1、4 點。雖已丟棄，主 agent 仍順手把引用補為「第 1、3、4 點」，此處置不改變任何契約內容。

**Downgrade trace — Reviewer B `confidence` 45 的 finding 已丟棄**：Contract 把所有 `unlink` 的 `rc == -1` 一律記入 `failed`，不區分 `errno`；`ENOENT` 表示目標狀態已達成，記為失敗會產生誤導性的 warning 與 `failed` 條目。Reviewer B 自評影響有限（不改變下載結果與任何檔案，且該競態多數會先被屬性讀取以 260 攔下落入同一分支），僅為日誌品質問題。未修改，保留現行處置。

**驗證**：修復涉及 proposal、design、spec、tasks 四個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；並重跑 mechanical self-check，確認 14 個 scenario 全數被 tasks 覆蓋、spec 條件為 5 項、決策 1–10 連續、Contract 1–9 連續、tasks 編號 1.1–1.18／2.1–2.3／3.1–3.4 連續、全域無「條件 6」殘留。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

next_round

cumulative blocking set 中有 1 個 Critical 與 4 個 Warning 已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第一輪，下一輪位置為第二輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 M1、W1–W4 逐一給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
