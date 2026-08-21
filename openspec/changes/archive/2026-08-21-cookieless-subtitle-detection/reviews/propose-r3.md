# Cash Propose Review — Round 3

## Reviewer Findings

### Critical

（無）

### Warning

**V1**（Reviewer V）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: `tasks.md` 4.4
- `summary`: 4.4 括號內宣稱「唯一會改變 `handlePostLiveFormatLookupError` 輸入的情形是兩次皆失敗時改以第二次 stderr 為準」，方向與事實相反：變更前唯一的 invocation 一律帶 cookies，變更後依 Contract 第 5 點，非登入類失敗改以「不帶 cookies 的第一次」stderr 為準——那才是輸入真正改變的主要情形；而兩次皆失敗時的第二次正是帶 cookies 那次，反而最接近變更前。該輸入直接決定 `.postLive` 或 `.failed`，照字面執行會讓這條唯一承接 `youtube-post-live-replay` 既有 scenario 迴歸的檢查失去鑑別力。
- `recommendation`: 改寫為正確的輸入變更集合，並把檢查點改為可實際執行的動作（斷言 cookieless 訊息仍能被 `YTDLPErrorClassification.classify` 判為 `.endedLive`）。
- `disposition`: `fix-introduced`
- `introduced_by`: Round 2 Fix Actions 第 2 項「修 F3、F4：…原 4.3 中屬於 `DownloadManager` 層的部分改為新的 4.4 code review 任務」

### Suggestion

- **V2**（`confidence` 60，`layer` text，`disposition`: `unresolved-prior`）`tasks.md` 1.3 仍保留 round 1 留下的「承接 delta spec 登入訊號共用 requirement」無限定標註，而 design 的驗證責任歸屬已把該 requirement 改派給 3.4／3.6 與 4.5，兩份 artifact 出現殘留的歸屬不一致。此為 F1 recommendation 後半未執行的部分，不影響 F1 主體已解決的判定。
- **V3**（`confidence` 50，`disposition`: `new`）design 第 7 點的驗證責任寫明 `ytdlpNotFound` 與 `process.run()` 失敗「由 code review 對照 diff 確認未被改動」，但第 4 節四項 code review 沒有任何一項承接這條。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：1（V1）
- 非 blocking 的 triaged finding 數：2（V2、V3）
- `critical_gap`: false
- `round_type`: micro
- rationale：Reviewer V 對兩個 blocking 成員的判定皆為 resolved。F1 依「verified resolution」離開累積 blocking set：`tasks.md` 4.5 是逐字可證偽的檢查（實作若複製一份訊號清單必定不通過），且 design 的責任指派與 tasks 標註一致。F2 同樣 resolved：修正後的敘述與 `Tubify/Services/YouTubeMetadataService.swift` 的既有訊息建構方式相符，3.8 斷言與敘述、實作三者一致。本輪新增 V1 為 blocking 成員，主 agent 已獨立對照程式碼確認其事實成立——變更前 `fetchMediaOptions` 的唯一 invocation 帶 cookies，變更後非登入類失敗改以 cookieless 訊息為準，而 `YTDLPErrorClassification.classify` 比對字面 `This live event has ended.`。V1 與 F2 同型：驗證任務內嵌了錯誤的事實前提，會讓執行者依錯誤前提放行，因此本輪不通過。

## Fix Actions

修正的檔案與理由：

1. `openspec/changes/cookieless-subtitle-detection/tasks.md`
   - 修 V1：4.4 全文改寫，逐字列出本變更改變 `handlePostLiveFormatLookupError` 輸入的兩種情形（非登入類失敗改以 cookieless 第一次 stderr，對應 Contract 第 5 點；兩次皆失敗改以第二次 stderr，對應 Contract 第 4 點且已由 3.5 驗證），並把檢查點改為可執行的動作：以 fixture 佈置 stderr 含 `This live event has ended.` 的 cookieless 失敗，斷言拋出的訊息仍被 `YTDLPErrorClassification.classify` 判為 `.endedLive`，再以 code review 確認分支邏輯未被改動。刪除原本錯誤的「唯一會改變」敘述。
   - 修 V2：1.3 的括號改為只承接 Contract 第 8 點與「訊號清單只有一份」的實作前提，並明寫 spec requirement 本身由 3.4／3.6 與 4.5 承接，與 design 的責任指派對齊。
   - 修 V3：4.2 的 diff 檢查範圍加入 `MetadataError.ytdlpNotFound` 與 `process.run()` 失敗兩條 catch 分支維持既有直接拋出行為、未被納入重試（對應 Contract 第 7 點）。

2. `openspec/changes/cookieless-subtitle-detection/design.md`
   - 修 V3：第 7 點的驗證責任由籠統的「由 code review 對照 diff 確認未被改動」改為明確指派給 tasks 4.2。
   - 修 V1：`post_live` 迴歸的責任歸屬改寫，說明本變更使 `handlePostLiveFormatLookupError` 的輸入在兩種情形下改變，並敘明 tasks 4.4 的驗證方式；保留「不以 `DownloadManager` 層測試為據」的理由。

降級與丟棄追溯（confidence filter）：

- V2 `confidence` 60、V3 `confidence` 50，皆落在 `[50, 80)` 或已為 Suggestion，維持非 blocking；兩者成本極低且成立，已一併修正。
- V2 的 `layer` 為 `text`，主 agent 依規則複檢：其修正只調整 tasks 的責任標註措辭，不改變任何行為或設計陳述，維持 `text` 分類。
- 本輪無 `confidence < 50` 的丟棄項。

pre-round 機械自檢（本輪 fix actions 完成後重跑）：

- 註解平衡：delta spec 無 `<!--`／`-->`。
- 數量一致性：design Implementation Contract 維持 11 條，tasks 引用涵蓋第 1 至第 11 點全部條號（本輪 4.4 新增對第 4、5 點的引用，4.2 新增對第 7 點的引用）。
- 識別字交叉檢查：`YTDLPErrorClassification`、`This live event has ended.`、`handlePostLiveFormatLookupError` 均在程式碼中存在且拼寫一致；`This live event has ended.` 確認為 `YTDLPErrorClassification.classify` 比對的字面字串。
- 平行標記檢查：`[P]` 仍只有 4.1、4.2 兩項且目標檔案互異。
- 殘留錯誤敘述掃描：確認 tasks 中已無「唯一會改變」字樣。
- delta spec 標題身分檢查：仍只有 `## ADDED Requirements`，不適用。
- signal-derived 檢查：30 個 open signal 皆無 `check` 欄位，回退 best-effort；本輪相關的 `unverified-design-claim`（V1）、`unassigned-verification-responsibility`（V3）、`tasks-stale-cross-reference`（V2）皆已處理。
- 修正後重跑 `"$cash_cli" validate "cookieless-subtitle-detection"`：通過。

本輪 fix actions 未修改 change 目錄以外的任何檔案，因此不需執行 `touched record`。本輪無 `未修復：裁判面保護` 記錄。

## Decision

next_round
