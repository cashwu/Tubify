# Cash Propose Review — Round 4

## Reviewer Findings

本輪為新 run 的第一輪（full round）。觸發原因是前一個 run 以 `decision: passed` 結束後，一份外部 review 提出兩個問題，主 agent 驗證並修復後啟動本輪驗證。本輪 cumulative blocking set 從空開始，所有 surviving `Critical` 與 `Warning` 皆為 blocking。

外部 review 的兩個原始 finding 與主 agent 的處置摘要：

- **外部 finding 1（Critical）**：刪除條件未排除目錄或其他非一般檔案。主 agent 以 Swift 實測確認 `removeItem` 對目錄會遞迴刪除連同其中的使用者檔案，判定成立並修復（新增條件 6）。
- **外部 finding 2（Warning）**：失敗處置 scenario 的分支測試不完整。主 agent 實測後判定四項建議中兩項可穩定注入（快照取得失敗、目錄列舉失敗）、兩項無穩定手段，只補前兩項，後兩項改為 code review 涵蓋。

### Warning

**W1**（Reviewer B）
- `severity`: Warning
- `confidence`: 80
- `layer`: design
- `location`: design.md 決策 6 與 Implementation Contract 第 2 點；tasks.md 3.3
- `summary`: 條件序列改成「形態 → `isRegularFileKey` → mtime」之後，非致命分支「單一候選檔 mtime 讀取失敗」成為原理上不可達的死分支。`isRegularFileKey` 與 `contentModificationDateKey` 來自同一次 `getattrlist`，任何讀不到 mtime 的項目其型別必然也讀不到，會先被「型別讀取失敗 → 跳過」吃掉。Reviewer B 實測唯一穩定的注入手段（ACL `deny readattr`）確認該候選檔仍出現在 `contentsOfDirectory(atPath:)` 結果中，但 `resourceValues` 對兩個 key 整批以 `NSCocoaErrorDomain` 257 失敗，不可能只失敗 mtime 一個 key。本輪修復把該分支從「有一個未被發現的注入手段」變成「原理上不可達」，而 design 決策 6 反過來以「沒有穩定注入手段」豁免它的測試。
- `recommendation`: 把候選檔的兩次屬性讀取合併為單次 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])`，將兩條分支收斂為單一「屬性讀取失敗 → 跳過」非致命分支；合併後該分支有穩定注入手段，補一個真正會進入該分支的測試，並移除 code review 豁免。
- `disposition`: fix-introduced
- `introduced_by`: 本輪為修復外部 finding 1 而新增的第六項條件，並在 Contract 第 2 點把 `isRegularFileKey` 排在 mtime 檢查之前。

**W2**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: design.md Implementation Contract 第 5 點；tasks.md 1.1、1.14；specs/download-reliability/spec.md scenario「名稱符合形態的目錄與 symbolic link 保留」
- `summary`: 新增 task 1.14 驗證 finding 1 的修復，但 Contract 第 5 點的 fixture case 規格未同步擴充——只說「建立指定的候選檔」，未涵蓋「建立含檔案的目錄」與「建立 symbolic link」。後果是 1.14 的自然寫法變成由測試自己在呼叫 `download` 前建立，那樣它們會落入決策 3 的目錄快照、被條件 2 排除而保留，斷言仍全綠卻**完全不會走到條件 6 的型別檢查**，使 Critical 的修復失去可驗證的測試。Reviewer B 另實測確認：不帶 `-h` 的 `touch -t` 對 symlink 會 follow 到 target（設到的是 target 的 mtime，symlink 自身仍是「現在」，GIVEN 不成立），對 dangling symlink 甚至會憑空建立 target 檔案；目錄的 `touch -t` 若在建立內層檔案之前執行，會被內層檔案的建立覆寫。
- `recommendation`: 擴充 Contract 第 5 點的 fixture case 涵蓋目錄與 symlink，明訂 symlink 用 `touch -h -t`、目錄的 `touch -t` 在建立內層檔案之後；並在 task 1.1 與 1.14 明寫這些項目必須由 fixture 在 invocation 期間建立。
- `disposition`: fix-introduced
- `introduced_by`: 本輪為修復外部 finding 1 而新增的 scenario「名稱符合形態的目錄與 symbolic link 保留」與 task 1.14，未同步 Contract 第 5 點。

**W3**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: design.md 決策 6 第二段與 Implementation Contract 第 2 點
- `summary`: 決策 6 用來解釋候選檔 mtime 分支不可測的理由「列舉後才刪除的候選檔仍會讀到 URL 的快取值」只在 prefetch API 下成立。Contract 第 1 點對快照明確指定 `contentsOfDirectory(atPath:)`，但對清理階段的列舉只寫「列舉該 parent 目錄」，未指定 API。兩位 reviewer 分別實測：`contentsOfDirectory(at:includingPropertiesForKeys:)` 取得的 URL 在檔案被刪除後仍回傳快取值，而 `contentsOfDirectory(atPath:)` 加新建 `URL(fileURLWithPath:)` 則以 `NSCocoaErrorDomain` 260 真實失敗。該理由對半數可能實作是錯的，會誤導實作者以為分支不可達而省略處置。Reviewer B 另指出：若採用 prefetch API，`isRegularFileKey` 用的是列舉當下的快取值而非 `removeItem` 當下的實況，TOCTOU 窗口從微秒級擴大到整個列舉迴圈——而條件 6 正是為了防守「目錄被遞迴刪除」。決策 6 中依賴 dangling symlink 的另一半理由也已被條件順序架空（型別檢查排在 mtime 之前，dangling symlink 根本進不到 mtime 讀取）。
- `recommendation`: 在 Contract 第 2 點明確指定清理階段使用 `contentsOfDirectory(atPath:)` 並對每個項目以新建的 URL 即時讀取屬性，禁止使用 prefetch 快取；同時移除決策 6 中依賴快取語意與 dangling symlink 的兩個錯誤理由。
- `disposition`: fix-introduced
- `introduced_by`: 本輪對外部 finding 2 的修復（決策 6 新增的「不寫測試理由」段落），以及把型別判定納入候選條件後列舉 API 選擇開始影響型別檢查時效性。

**W4**（Reviewer A）
- `severity`: Warning
- `confidence`: 90
- `layer`: design（Reviewer A 原標 `text`，經主 agent 更正）
- `location`: tasks.md 2.3
- `summary`: task 2.3 仍寫「執行任務 1.2 至 1.13 的測試確認全部通過」，但本輪已把測試擴充到 1.16。1.14（唯一驗證 finding 1 修復的測試）、1.15、1.16 三項全部落在該範圍之外，依此 task 執行時不會被跑到。
- `recommendation`: 將 2.3 的範圍改為涵蓋所有新增的 test task。
- `disposition`: fix-introduced
- `introduced_by`: 本輪新增 tasks 1.14、1.15、1.16 時未同步 2.3 的範圍。

### Suggestion

**S1**（Reviewer A，`confidence` 70，`disposition` unresolved-prior）
- `location`: proposal.md `## Proposed Solution`
- `summary`: 外部 finding 1 的修復傳播到 spec 條件、design 決策 2、Contract 第 2 點與第 6 點、tasks 2.2 與 1.14 六處，但沒有傳播到 proposal——條件清單仍是舊的四項，缺少「該項目是一般檔案」，使 proposal 對外陳述的刪除條件比 spec 寬。

**S2**（Reviewer A 與 Reviewer B 獨立提出，`confidence` 65，合併）
- `location`: tasks.md 1.15、1.16；design.md Implementation Contract 第 7 點
- `summary`: 兩個新測試的唯一斷言是「不刪除任何檔案且回傳原本的最終輸出路徑」，但都沒有要求輸出目錄中存在「若沒有該致命失敗就一定會被刪除」的候選檔。缺少該前提時斷言真空成立，即使把致命處置整段移除測試仍全綠。`0o111` 注入尤其如此——該權限同時使 unlink 失敗。

**S3**（Reviewer B，`confidence` 55，`disposition` new）
- `location`: tasks.md 1.12、1.16；design.md Implementation Contract 第 7 點
- `summary`: 兩個測試都要求把檔案系統置於「阻止刪除」的狀態再於測試結束前還原，但沒有規定還原必須放在 `defer` 或 `addTeardownBlock`。測試是 `async throws`，中途任何 `try` 拋出都會跳過尾端還原；而 `makeYTDLPFixture` 從不刪除自己的暫存目錄，未還原的 `uchg` 檔與 `0o111` 目錄都會擋下遞迴刪除，在 CI 上留下無法回收的殘留。

**S4**（Reviewer A，`confidence` 55，`layer` text）
- `location`: design.md 決策 6
- `summary`: 同一決策內對致命失敗的計數不一致：一處說「三者都使判斷前提不成立」，另一處說「四個致命失敗中」。

### 經 confidence filter 丟棄的 finding

Reviewer B 另回報一個 `confidence` 35 的 finding，依 confidence filter 丟棄，其 downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 4
- 非 blocking triaged finding count: 4
- `critical_gap`: false
- `round_type`: full

rationale：本輪為新 run 的第一輪，4 個 Warning 全部進入 cumulative blocking set。W1 與 W3 由 Reviewer B 與 Reviewer A 各自撰寫 Swift 腳本實測驗證，主 agent 另行覆核 `getattrlist` 共用屬性與兩種列舉 API 的快取語意差異；W2 的 `touch` symlink 行為經 Reviewer B 實測；W4 由主 agent 直接覆核 tasks.md 確認。四者皆為本輪修復動作引入，`disposition` 均為 `fix-introduced`。存在 blocking Warning，因此 `decision: next_round`。

## Fix Actions

**Disposition correction — W4 的 `layer` 由 `text` 更正為 `design`**。Reviewer A 原標 `text`。主 agent 覆核：該 task 的範圍數字決定實作者會執行哪些測試，若不修，驗證 Critical 修復的 task 1.14 不會被執行，屬於影響驗收行為而非純措辭同步。依「無法判斷時一律 design」與「main agent MUST NOT 把 design 降為 text」的規則，更正為 `design`。更正後仍為 Warning、`confidence` 90，維持 blocking。

**W1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md`：決策 6 改寫，說明候選檔的型別與 mtime 來自同一次 `getattrlist`、拆成兩條分支會使後者被完全遮蔽成死分支，並明訂兩個屬性 SHALL 以單次 `resourceValues(forKeys:)` 一併讀取、讀取失敗收斂為單一非致命分支，該分支的注入手段為 ACL `deny readattr`。Implementation Contract 第 2 點同步改為單次屬性讀取。修改 `openspec/changes/cleanup-orphaned-part-files/specs/download-reliability/spec.md`：scenario「單一候選檔處理失敗時繼續處理其餘候選檔」的 GIVEN 由「content modification date 讀取失敗」改為「屬性讀取失敗」，requirement 本文補「條件 4 與條件 6 所需的屬性 SHALL 以單次讀取一併取得」。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md`：新增 task 1.17 以 ACL `deny readattr` 驅動該分支，2.2 同步要求單次讀取，並移除原 task 3.3 的 code review 豁免（原 3.4 重編為 3.3）。

**W2 — 修復**。修改 design.md Implementation Contract 第 5 點：「多 attempt 成功」case 擴充為可建立候選檔、名稱符合形態的目錄（內含一個檔案）與 symbolic link，明訂這些項目 MUST 由 fixture 在 invocation 期間建立（否則落入快照被條件 2 排除而走不到條件 6），並明訂 symlink 的 mtime MUST 用 `touch -h -t`、目錄的 `touch -t` MUST 在建立內層檔案之後執行，附上不帶 `-h` 會 follow symlink 與憑空建立 target 的實測依據。修改 tasks.md task 1.1 與 1.14 同步這些要求。

**W3 — 修復**。修改 design.md Implementation Contract 第 2 點：明確指定清理階段以 `FileManager.default.contentsOfDirectory(atPath:)` 列舉，並對每個項目新建 `URL(fileURLWithPath:)` 即時讀取屬性，明文禁止取用 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取快取，並說明預取會把 TOCTOU 窗口從微秒級擴大到整個列舉迴圈。決策 6 中依賴快取語意與 dangling symlink 的兩個錯誤理由已隨 W1 的改寫一併移除。修改 tasks.md task 2.2 同步禁止預取快取。

**W4 — 修復**。修改 tasks.md task 2.3，測試範圍由「1.2 至 1.13」改為「1.2 至 1.17」，涵蓋本輪新增的全部 test task。

**S1 — 修復**（非 blocking，一併處理）。修改 proposal.md `## Proposed Solution` 的候選條件清單，補上「是一般檔案；名稱符合形態的目錄、symbolic link 或其他非一般檔案一律不刪除」。

**S2 — 修復**（非 blocking，一併處理）。修改 design.md Implementation Contract 第 7 點，要求每個致命失敗測試必須在輸出目錄放置至少一個滿足其餘全部條件的區辨性候選檔並斷言其仍存在，並說明 `0o111` 注入尤其需要此斷言。修改 tasks.md task 1.15 與 1.16 同步該要求，1.16 另明訂候選檔須在改動權限之前建立。

**S3 — 修復**（非 blocking，一併處理）。修改 design.md Implementation Contract 第 7 點，要求所有改動檔案系統狀態的注入（`chflags uchg`、`0o111`、ACL）MUST 以 `defer` 或 `addTeardownBlock` 註冊還原動作，並說明未還原會在 CI 留下無法回收的殘留。修改 tasks.md task 1.12、1.16、1.17 同步該要求。

**S4 — 修復**（非 blocking，一併處理）。修改 design.md 決策 6：致命失敗統一表述為三項（快照取得失敗、最終輸出檔不可用、目錄列舉失敗），其中「最終輸出檔不存在」與「無法讀取 content modification date」是同一個 guard 的兩個觸發條件。全文已無「四個致命失敗」的表述。

**Downgrade trace — Reviewer B `confidence` 35 的 finding 已依 confidence filter 丟棄**。該 finding 指出 `isRegularFileKey` 對 hardlink 回傳 true，決策 2 只列舉一般檔案／目錄／symbolic link 三種型別，讀者會誤以為型別檢查已窮盡。Reviewer B 自評實際損失有限（hardlink 蘊含至少兩個名稱，刪除其一不會使內容消失）並判定屬可接受範圍。雖已丟棄，主 agent 仍採納其文件面建議以避免誤導：決策 2 補一句說明 `isRegularFileKey` 對 hardlink 回傳 true，Risks 新增一條殘餘風險條目。此處置不改變任何刪除條件。

**驗證**：修復涉及 proposal、design、spec、tasks 四個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

next_round

cumulative blocking set 中有 4 個 `fix-introduced` 的 Warning（W1–W4）已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第一輪，下一輪位置為第二輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 W1–W4 逐一給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
