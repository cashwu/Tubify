# Cash Propose Review — Round 2

## Reviewer Findings

### 累積 blocking set 的 verdict（Reviewer V）

| 成員 | verdict | 依據摘要 |
|---|---|---|
| M1（Critical，task 3.6 無可用測試接縫） | resolved | C7 已記錄無接縫的事實並拆為 3.6／3.7／3.8＋5.5；Reviewer V 核對 `Tubify/Services/YTDLPService.swift:291-303` 的 `executeDownloadFlow` 簽章，`attemptExecutor` 之後的參數皆有預設值，不傳 `operationID` 時 `isCancelled`（`:578-587`）不會誤判取消，既有 fixture 的 `*DRAIN_403*` 分支正好提供「第 1 次失敗、第 2 次成功」；`removeSafariCookies`（`Tubify/Services/SafariCookiesService.swift:105-112`）只替換 cookies 字串，斷言成立 |
| M2（Warning，`,` 多重下載語法） | resolved | C4 已加入 `,` 切分層級，spec 新增對應 scenario，task 4.4 以 `bv+ba,b` 做完整字串相等 |
| M3（Warning，task 5.3 指名錯檔案） | resolved | 5.3 已拆為兩項，Reviewer V 逐一核對 `DownloadManager.swift:500`、`MediaSelectionView.swift:31`／`:40`／`:114`、`SubtitleInfo.swift:6` 全部正確 |
| M4（Warning，恆真計數斷言） | resolved | 4.3 已改為完整字串相等，且該預期字串對 naive `/` 切分具鑑別力 |
| M5（Warning，spec 與 C4 定義不一致） | resolved | requirement 正文已寫入與 C4 逐字對齊的 alternative 定義，兩個相關 scenario 改為引用該定義 |

Reviewer V 另確認 fix propagation 無遺漏：alternative 定義與 `,` 切分、fixture argv API 形狀、design 對 tasks 的 12 處編號引用、`Tubify/` 範圍限定、post_live 耦合與 `fetchVideoInfo` 不對稱，皆已跨 artifact 同步；`download:251`、`injectLanguageIntoFormat:1186`、`parseCommandArguments:1082`、`isErrorLine:683`、`DownloadManager.swift:471`／`:474`／`:660` 等行號錨點全部核對正確；`subtitle-selection` 的 MODIFIED requirement 標題與 master spec 逐字相符，7 個既有 scenario 全數保留。

### Critical

無。

### Warning

無。

### Suggestion

1. `severity`: Suggestion｜`confidence`: 70｜`layer`: design｜`disposition`: `fix-introduced`（`introduced_by`: round 1 的「修 Critical 1」）｜`location`: `tasks.md` task 3.6 末句、`design.md` C7｜`summary`: 3.6 宣稱其斷言可觀察 C3 的注入順序，但「注入套用在 `removeSafariCookies` 的輸出上」同樣會讓斷言通過，該推論不成立｜`recommendation`: 把理由改為精確敘述，順序的完整保證改由 code review 承接

2. `severity`: Suggestion｜`confidence`: 65｜`layer`: design｜`disposition`: `fix-introduced`（`introduced_by`: round 1 的「修 Critical 1」）｜`location`: `tasks.md` task 3.7｜`summary`: `executeDownloadFlow` 只把 template 原樣傳遞，測試又自行提供兩個已注入的範本，因此該斷言對產品端的注入決策沒有鑑別力｜`recommendation`: 誠實陳述其覆蓋範圍，並在 C7 改記由 3.6＋3.8＋5.5 承接

3. `severity`: Suggestion｜`confidence`: 72｜`layer`: design｜`disposition`: `fix-introduced`（`introduced_by`: round 1 的「修 Suggestion 7」）｜`location`: `design.md` Risks 的 post_live 條目、`tasks.md` task 5.6｜`summary`: `MetadataFixture` 的 stdout 由 `call-$n.stdout` 決定、不隨 argv 改變，5.6 在結構上不可能觀察「引數變更造成判定改變」，Risks 的把關宣稱過強｜`recommendation`: 限縮 Risks 的宣稱範圍

4. `severity`: Suggestion｜`confidence`: 70｜`layer`: design｜`disposition`: `fix-introduced`（`introduced_by`: round 1 的「修 Suggestion 12」與「修 Suggestion 14」）｜`location`: `design.md` D5、`tasks.md` 1.1 與 1.2／3.1／3.6／3.7／3.8｜`summary`: 同時要求「測試以獨立字面值作為 oracle」與在五個 task 中引用 `YTDLPService.youtubePlayerClientArgumentValue`，實作者無從判斷該用哪一種｜`recommendation`: 把獨立字面值的要求限縮到 1.1，其餘明確允許引用產品常數

5. `severity`: Suggestion｜`confidence`: 55｜`layer`: design｜`disposition`: `new`｜`location`: `tasks.md` task 2.1 vs 3.7／5.4(b)｜`summary`: 2.1 只新增 `arguments(at:)`，但 5.4(b) 要斷言 invocation 次數、3.7 要區分兩次 attempt，`invocationCount` 未納入範圍｜`recommendation`: 2.1 比照 `MetadataFixture` 一併新增 `invocationCount`

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：0
- 非 blocking 的 triaged finding 數：5
- `critical_gap`: false
- `round_type`: micro
- rationale：Reviewer V 對累積 blocking set 的 5 個成員全部給出 `resolved`，且逐一引用現行 artifacts 與程式碼作為依據，5 個成員因此以「verified resolution」離開集合。本輪新增的 5 條 findings 全為 Suggestion（confidence 55–72，皆低於 80），依規則不阻擋。post-filter 累積 blocking set 為空，因此 `passed`。

## Fix Actions

本輪已達 pass 條件，以下修正非為解除阻擋而做，而是因為 4 條 `fix-introduced` 的 Suggestion 指出的是「第 1 輪修正引入的過強宣稱」——留著會讓下游誤以為某些面向已有把關。逐項如下：

- **修 Suggestion 1**（`design.md`、`tasks.md`）：task 3.6 的理由改為「可鑑別『注入晚於 `firstTemplate` 計算』的錯誤實作」，並明寫它無法鑑別「注入套用在 `removeSafariCookies` 輸出上」這種同樣正確的寫法；C7 對應條目同步改寫，C3 的完整順序約束改由 task 5.5 承接。5.5 因此擴為兩個檢查點，新增 (b) 逐行確認 `injectExtractorArgs` 的呼叫早於 `hasCookies` 計算與兩個 cookies 方法、且兩條 template 分支都以注入後的字串為輸入。
- **修 Suggestion 2**（`design.md`、`tasks.md`）：task 3.7 的敘述改為誠實陳述覆蓋範圍（cookies 重試路徑把 provider 回傳的範本原樣送進 argv，含 `,` 的引號值不被 `parseCommandArguments` 破壞）；C7 改記「兩個範本都帶 extractor args」由 3.6、3.8、5.5 合併承接。
- **修 Suggestion 3**（`design.md`）：post_live 的 Risk 末句與 C7 對應條目改為「5.6 把關的是引數改動未波及解析路徑」，並明寫 `MetadataFixture` 的 stdout 不隨 argv 改變、門檻本身的變化無自動化把關。
- **修 Suggestion 4**（`design.md`、`tasks.md`）：D5 把測試端分為兩類——驗證「常數的值本身正確」的 task 1.1 MUST 以獨立字面值為 oracle，其餘只驗注入與否的 task 允許引用產品常數；task 1.1 的括號說明同步改寫。
- **修 Suggestion 5**（`design.md`、`tasks.md`）：C6 與 task 2.1 一併新增 `invocationCount`，簽章與 `MetadataFixture` 的同名成員對齊。
- **fix propagation**：本輪觸及的概念（3.6／3.7 的覆蓋範圍、5.5 的檢查點數量、`invocationCount`、D5 的 oracle 規則）已跨 `design.md` 與 `tasks.md` grep 對齊；`invocationCount` 在兩份 artifact 皆出現，C6 與 2.1 敘述一致。
- **修改的檔案**：`openspec/changes/dubbed-audio-track-selection/design.md`、`tasks.md`。
- **post-fix 檢查**：重新執行 `.cash-skills/bin/cash validate dubbed-audio-track-selection`（通過）；重新執行 pre-round mechanical self-check：delta spec 無註解不匹配、tasks 仍為 34 條且 design 的編號引用全部存在、識別字跨 artifact 拼寫一致、MODIFIED requirement 標題與 master spec 逐字相符。

## Decision

passed
