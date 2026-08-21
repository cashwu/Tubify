# Cash Apply Review — Round 3

## Reviewer Findings

本輪為 apply loop 新 run 的第一輪（full round，unseeded），所有 surviving `Critical` 與 `Warning` 皆為 blocking，不標註 `disposition`。觸發原因是 Round 1–2 以 `passed` 結束後，外部 review 指出 spec 對 symbolic link 的規範互相矛盾，主 agent 修復後啟動本輪驗證。

外部 review 的原始 finding：spec 一方面絕對要求「MUST NOT 刪除目錄、symbolic link 或其他非一般檔案」，另一方面又規定 TOCTOU replacement 的 symlink 會被刪除，design 決策 9 與 Risks 也接受此行為，因此同一份 spec 同時存在互相否定的規範。主 agent 依其建議選擇「限縮 MUST NOT 至條件 5 評估時」而非「新增路徑 identity 保證」。

兩位 reviewer 皆確認**該 Critical 矛盾已消除**：spec 內不再存在互相否定的規範性敘述，spec ↔ 實作一致，未引入新的可觀察行為要求，現有測試已完整覆蓋。Reviewer A 另確認修法選擇恰當——選項 B 需以 `openat`／`unlinkat` + fd 綁定取代路徑字串刪除，屬 design 層的新機制與新失敗模式，會使已通過的 310 tests 全面重寫。

### Warning

**M1**（Reviewer B）
- `severity`: Warning
- `confidence`: 90
- `layer`: design
- `location`: `openspec/changes/cleanup-orphaned-part-files/specs/download-reliability/spec.md` 的 symbolic link bullet
- `summary`: 修正新增的句子「要把這個例外也消除，需要以路徑 identity 保證取代路徑字串刪除（例如以 file descriptor 綁定受檢項目），本變更不提供」指名了一個 macOS 上**不存在**的機制。Reviewer B 實測三項：(1) `funlinkat`（FreeBSD 的「僅當 fd 與 path 指向同一 inode 時才 unlink」原語）在 macOS SDK 未宣告且 dyld cache 查無符號（`funlinkat ABSENT`／`unlinkat, openat, fstatat, unlink PRESENT`）；(2) `unlinkat` 的 flag 只有 `AT_REMOVEDIR`、`AT_SYMLINK_NOFOLLOW_ANY`、`AT_RESOLVE_BENEATH`，其中 `AT_SYMLINK_NOFOLLOW_ANY` 依定義只作用於**中間**路徑元件；(3) 實測 `unlinkat(AT_FDCWD, link, AT_SYMLINK_NOFOLLOW_ANY)` 與 `AT_RESOLVE_BENEATH` 對最終元件是 symlink 的路徑**都回傳 0 並刪除該連結**。`open(O_NOFOLLOW)` 可把項目綁到 fd 來*檢查*（對 symlink 以 `ELOOP` 失敗），但 macOS 沒有任何以該 fd 為條件的*刪除*原語，fd 綁定無法消除此窗口。spec 因此把「平台根本不提供」寫成了「本變更不提供」的範圍取捨，讀者會據此嘗試一個做不出來的修法。這是 `openspec/signals/unverified-design-claim.md`（occurrences 3）的第四個實例。
- `recommendation`: 改為陳述平台事實，並把機制可行性論述搬到 `design.md`——spec 的 requirement 本體應描述可觀察行為，不應承載機制推論。Reviewer B 另指出真正可行的方向是 rename-then-verify（`rename` 不跟隨最終元件的 symlink），但那是新機制，不應在本變更加入。
- `introduced_by`: `specs/download-reliability/spec.md` 本次修正新增的 symbolic link bullet

### Suggestion

**S1**（Reviewer B，`confidence` 75；Reviewer A 以 `confidence` 65 獨立提出同一問題，依 `location + summary` 合併，`layer` 取 `design`）
- `location`: spec requirement body 的 symbolic link MUST；scenario「刪除操作本身拒絕目錄」
- `summary`: 修正新增了 normative 要求「刪除操作 MUST NOT 跟隨 symbolic link，因此其指向的內容 MUST 保持完整」，但 14 個 scenario 中沒有任何一條驗收它——唯一驗收刪除原語性質的 scenario 只涵蓋目錄。這是一條無驗收條文的 MUST，屬 `unassigned-verification-responsibility` 型態。實作與測試其實都已覆蓋（`testUnlinkRefusesDirectoryAndDoesNotFollowSymlink` 後半段已斷言 `unlink(link.path) == 0`、連結消失、target 內容仍存在），缺的純粹是 spec 側的驗收條文，補齊成本為零。

**S2**（Reviewer B，`confidence` 65；Reviewer A 以 `confidence` 60 提出其中的「其他非一般檔案」部分，合併取 Reviewer B 的完整版）
- `location`: spec 的「兩種強度不同的保證」段落
- `summary`: 該段以「兩種保證」宣稱窮盡了條件 5 與刪除之間的替換窗口，但漏了兩類，且其中一類損失**高於**已被明文承認的 symlink 例外。(a) spec 第 17 行的 MUST NOT 明列三類（目錄、symbolic link、其他非一般檔案），但只有前兩類得到窗口內的保證；實測 `unlink` 對 FIFO 與 unix socket 都回傳 0 並刪除。(b) 窗口內若該路徑被換成另一個真實的一般檔案，`unlink` 會成功並刪掉**唯一名稱與其內容**——這是整個窗口最大的損失，而 spec 把最壞後果寫成「損失僅限於一個連結名稱」。design Risks 的「同名第三方下載」講的是通過全部五個條件、沒有 race 的情形，並未涵蓋窗口內的同型別替換。

**S3**（Reviewer B，`confidence` 65，`layer` text）
- `location`: spec 的「是上述『MUST NOT 刪除 symbolic link』的明文例外」
- `summary`: 修正把第 17 行限縮到「條件 5 評估時」之後，spec 中已不存在任何無限定的「MUST NOT 刪除 symbolic link」。窗口內才變成 symlink 的項目在條件 5 評估時是一般檔案，本來就落在適用範圍之外——它不是例外，而是限定條款未涵蓋的另一情形。以「例外」自我指涉等於在文本中重新引入一條並不存在的絕對要求，是原 Critical 矛盾的殘影。

**S4**（Reviewer B，`confidence` 60，`layer` text）
- `location`: spec 的「刪除操作本身 SHALL 使用不會遞迴刪除目錄的系統呼叫」；`proposal.md` 同樣措辭
- `summary`: 前提不足以支撐結論——`rmdir` 與 libc `remove(3)`（對目錄轉呼叫 `rmdir`）同樣不遞迴，但對**空目錄**會成功刪除，滿足 SHALL 卻違反同句的 MUST。現有 scenario 又把 GIVEN 限定在「含有其他檔案的目錄」，空目錄替換情形在條文層面沒有被擋住。實作面無風險：測試以 `XCTAssertEqual(unlink(...), -1)` 加 `XCTAssertEqual(errno, EPERM)` 釘住了 `unlink` 語意。

**S5**（Reviewer A，`confidence` 55，`layer` text）
- `location`: scenario「名稱符合形態的目錄與 symbolic link 保留」的 `##### Example:`
- `summary`: Example 的主詞「這類項目／它們」同時指目錄與 symbolic link，但後半段的兜底保證只對目錄成立。兩句各自為真，並列後容易讓讀者推出「symlink 也有兜底保證」，是同一類歧義的殘留。

**S6**（Reviewer A，`confidence` 50，`layer` text）
- `location`: `design.md` 決策 9
- `summary`: 決策 9 寫「spec 的絕對 `MUST NOT` 因此無法由檢查本身保證」，但修正後 spec 已不存在無條件的絕對 MUST NOT，這句 cross-reference 指向一個已不存在的措辭。語意上對目錄仍成立，故只是措辭陳舊。

### 經 confidence filter 丟棄的 findings

Reviewer A 的兩個 `confidence` 45／40 finding 依 confidence filter 丟棄，downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- 非 blocking triaged finding count: 6
- `critical_gap`: false
- `round_type`: full

rationale：本輪為新 run 的第一輪，唯一的 Warning M1 進入 cumulative blocking set。M1 由 Reviewer B 以三項實機測試提供決定性證據（符號缺席、flag 語意、實際行為），`introduced_by` 指向本次修正新增的具體位置，證據可驗證。外部 review 指出的原 Critical 矛盾已由兩位 reviewer 各自確認消除。存在 blocking Warning，因此 `decision: next_round`。

## Fix Actions

**M1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/specs/download-reliability/spec.md`：移除指名 file descriptor 綁定的句子，改為單句平台事實「此窗口無法以現有系統呼叫消除：macOS 未提供以 file descriptor 或 inode identity 為條件的刪除原語」。完整的機制可行性論述搬到 `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 9，逐項記錄 Reviewer B 的實測結果（`funlinkat` 在 macOS SDK 未宣告且 dyld cache 查無符號、`unlinkat` 三個 flag 中 `AT_SYMLINK_NOFOLLOW_ANY` 只作用於中間路徑元件、實測對最終元件是 symlink 的路徑仍回傳 0 並刪除、`open(O_NOFOLLOW)` 可檢查但無對應刪除原語），並記錄 rename-then-verify 是唯一可行方向但屬新機制、本變更不採用。

**S1 — 修復**（非 blocking，一併處理）。把 scenario「刪除操作本身拒絕目錄」改名為「刪除操作的型別性質」並擴充第二組 GIVEN/WHEN/THEN：指向目錄的 symbolic link 被刪除時 SHALL 只移除該連結本身、其 target 與其中的檔案 MUST 保持完整。既有測試 `testUnlinkRefusesDirectoryAndDoesNotFollowSymlink` 即為其驗收證據，未新增任何測試或實作。`tasks.md` task 1.18 的 scenario 引用同步為新名稱。

**S2 — 修復**（非 blocking，一併處理）。把「系統對這段時間差內發生的型別替換提供兩種強度不同的保證」改為「只提供一項保證，其餘情形明文不保證」，第二個 bullet 一般化為「其餘所有情形」，逐字列出 symbolic link、FIFO、socket 等其他非一般檔案與另一個一般檔案三類，並明說被替換成另一個一般檔案時會連同該檔內容一併失去、這是本窗口最壞的後果。`design.md` Risks 的對應條目同步改寫，標題由「型別檢查後被替換為 symbolic link」改為「型別檢查後的路徑替換」。

**S3 — 修復**（非 blocking，一併處理）。刪除「例外」框架，改為陳述限定條款的適用邊界：「上一段的要求以條件 5 的評估時點為準，因此在該時點之後才發生的型別替換不在其適用範圍內」。

**S4 — 修復**（非 blocking，一併處理）。把 SHALL 的性質由「使用不會遞迴刪除目錄的系統呼叫」改為「對任何目錄一律失敗且不移除該目錄項目」，並在結論補上「無論該目錄是否為空」。`proposal.md` 兩處對應措辭同步。`design.md` 決策 9 另補一段說明為何必須是「一律失敗」而非「不遞迴」——`rmdir` 與 `remove(3)` 同樣不遞迴卻會成功刪除空目錄。

**S5 — 修復**（非 blocking，一併處理）。改寫該 Example 為分別敘述：條件 5 排除這兩個項目使其不進入刪除路徑；若目錄是在條件 5 之後才出現於該路徑，刪除操作仍會拒絕它；symbolic link 沒有這層兜底，其情形見 requirement 對時間差的說明。

**S6 — 修復**（非 blocking，一併處理）。`design.md` 決策 9 的 cross-reference 改為「spec 對目錄的絕對保證（『即使在條件 5 通過之後才被替換成目錄，刪除仍 MUST 失敗』）因此無法由檢查本身承擔，必須由刪除原語提供」。

**Downgrade trace — Reviewer A `confidence` 45 已依 confidence filter 丟棄**。該 finding 指出 spec 新增的取捨聲明未同步到 design Risks 或 proposal Non-Goals。此問題已被 M1 的修復自然涵蓋：機制論述整段搬入 design 決策 9，Risks 條目亦同步改寫並引用該決策。

**Downgrade trace — Reviewer A `confidence` 40 已依 confidence filter 丟棄**。該 finding 指出 `proposal.md` 的條件清單 bullet 與其下方段落重複陳述同一敘述，日後只改一處會產生漂移點。未合併兩處：兩者受眾不同（bullet 是條件清單的一項，段落是對整體刪除機制的說明），且本輪已同步更新兩處措辭，暫無漂移。

**驗證**：修復涉及 `specs/download-reliability/spec.md`、`design.md`、`proposal.md`、`tasks.md` 四個 artifact，未動任何實作或測試。已執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；mechanical self-check 確認 14 個 scenario 全數被 tasks 覆蓋、spec 條件仍為 5 項、annotation 平衡、舊 scenario 名與「不會遞迴刪除目錄」「本變更不提供」等舊措辭均無殘留（`design.md` 中一處「刪除操作本身拒絕目錄」為散文描述測試目的的引號，非 scenario cross-reference，語意仍正確，保留）。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

next_round

cumulative blocking set 中有 1 個 Warning（M1）已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第一輪，下一輪位置為第二輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 M1 給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
