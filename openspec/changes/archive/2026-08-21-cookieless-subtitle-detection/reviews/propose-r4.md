# Cash Propose Review — Round 4

## Reviewer Findings

### Critical

（無）

### Warning

（無）

### Suggestion

- **Q1**（Reviewer B，`confidence` 55，由 Warning 降級，`disposition`: `new`）播放清單路徑的 `is_upcoming` → `.scheduled` 判定同樣只依賴 `fetchMediaOptions` 回傳的 `liveStatus` 與 `releaseTimestamp`，但 artifacts 只把查詢不對稱的影響寫到 `formats` 與 `hasUsableMediaFormats`，四個狀態機出口中 `.scheduled` 這條全篇未被點名為受影響面。
- **Q2 + A3**（Reviewer B `confidence` 55 與 Reviewer A `confidence` 40，同一 location 與同一機制，依聚合規則併為一項並取較高 `confidence` 55，由 Warning 降級，`disposition`: `new`）第一次 invocation 的引數已在 round 1 收緊為完整相等，第二次 invocation 卻只被要求「包含 cookies 元素」，一個遺漏 `--skip-download` 的重試實作能通過全部契約與測試；而 `--skip-download` 正是 D2 主張「video-data 403 訊號不適用於本路徑」的前提。
- **A1**（Reviewer A，`confidence` 45，`disposition`: `new`）delta requirement 主詞為「系統取得媒體選項時」，但同檔另有 `fetchSubtitles` 與 `fetchAudioTracks` 兩支同樣把 cookies 串進 yt-dlp 的方法，Non-Goals 未交代其是否在範圍內；實測兩者目前無呼叫端，屬範圍界定留白而非行為缺陷。
- **A2**（Reviewer A，`confidence` 35，`layer` text，`disposition`: `fix-introduced`，`introduced_by`: Round 3 Fix Actions 第 1 項）tasks 4.4 把「兩次皆失敗改以第二次 stderr 為準」列為輸入變更情形之一，但該分支的訊息來源與變更前同為帶 cookies 的 invocation，屬輕微過度包含，不會導致錯誤放行。
- **Q3**（Reviewer B，`confidence` 40，`disposition`: `new`）`## Alternatives Considered` 未評估「保留 cookies 但以 `--extractor-args` 指定 client」這個直指根因的手段。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：0
- 非 blocking 的 triaged finding 數：5（Q1、Q2+A3、A1、A2、Q3）
- `critical_gap`: false
- `round_type`: full
- rationale：本輪為本次 run 的第四輪，依規則為 full round checkpoint，兩位 reviewer 獨立重掃並各自對唯一的 blocking 成員 V1 給出判定，兩者皆為 resolved 且無分歧，因此 V1 依「verified resolution」離開累積 blocking set：`tasks.md` 4.4 已刪除錯誤的「唯一會改變」敘述、兩種輸入變更情形的方向與 Contract 第 4、5 點相符，且新檢查點具鑑別力——`YTDLPErrorClassification.classify` 比對字面 `This live event has ended.`，該字串不命中 `indicatesLoginRequired` 的任何訊號，fixture 佈置的 cookieless 失敗確實走「不重試、拋第一次 stderr」路徑，而 `MetadataError.fetchFailed` 的 `errorDescription` 完整包含 stderr，斷言與正式路徑同構。Reviewer A 另對前幾輪已離開的 W1、W3、F1、F2 逐一複檢，全部維持 resolved，無 `unresolved-prior`。累積 blocking set 已空，本輪通過。

## Fix Actions

本輪 pass condition 已達成，以下修正皆為非 blocking finding 的自願採納，非通過條件所需；每項都是 artifact 層的收緊或補述，不改變已通過驗證的任何契約語意方向。

1. `openspec/changes/cookieless-subtitle-detection/design.md`
   - 採納 Q2 + A3：Contract 第 4 點把第二次 invocation 的引數由「MUST 包含 `cookiesArguments` 的全部元素」收緊為「MUST 恰為 `["-J", "--skip-download", "--no-playlist"] + cookiesArguments + [url]`」，並逐字寫明 `--skip-download` 在重試路徑同樣不可省略及其兩項理由。
   - 採納 Q1：Risks 的「`post_live` 分支的查詢不對稱」條目更名為「`post_live` 與 `is_upcoming` 判定的查詢不對稱」，補述受影響欄位擴及 `liveStatus` 與 `releaseTimestamp`、播放清單首播影片可能由 `.scheduled` 退化為 `.failed` 的具體後果，並註明單一影片路徑走 `fetchVideoInfo` 提早 return 不受影響。
   - 採納 A1：Non-Goals 補述 `fetchSubtitles` 與 `fetchAudioTracks` 目前無呼叫端，本變更只改其路徑解析、不改 cookies 行為，兩階段策略的實作範圍限定於 `fetchMediaOptions`。

2. `openspec/changes/cookieless-subtitle-detection/specs/subtitle-selection/spec.md`
   - 採納 Q2 + A3 的 propagation：「需登入錯誤且有 cookies 時帶 cookies 重試」scenario 的 THEN 同步收緊為「其引數 SHALL 恰為第一次 invocation 的引數加上該 cookies 參數的全部元素，既有的 `-J`、`--skip-download`、`--no-playlist` 與目標 url MUST 全數保留」。

3. `openspec/changes/cookieless-subtitle-detection/tasks.md`
   - 採納 Q2 + A3 的 propagation：3.4 的斷言由「包含全部 cookies 參數元素」改為完整相等比對。
   - 採納 Q1：4.3 的 fixture 增加一組 `live_status` 為 `is_upcoming` 且含 `release_timestamp` 的 JSON，作為 `.scheduled` 判定的解析層迴歸落點。

4. `openspec/changes/cookieless-subtitle-detection/proposal.md`
   - 採納 Q3：`## Alternatives Considered` 新增「保留 cookies，改以 `--extractor-args "youtube:player_client=..."` 指定 client」一條，並附主 agent 的實測否決證據——帶帳號 cookies 時指定 `android_vr` 以 `Requested format is not available` 失敗、指定 `tv` 以 `The page needs to be reloaded.` 失敗、指定 `web_safari` 取回的 `subtitles` 仍為空，yt-dlp 在偵測到帳號 cookies 時的 client 選擇無法以該旗標繞過。此實測同時是 D6「不把 client 名稱寫進契約」的佐證。

未採納並記錄理由：

- A2（`confidence` 35，`layer` text）指出 4.4 把「兩次皆失敗」列為輸入變更情形屬過度包含。此敘述不會造成錯誤放行（Reviewer A 自身亦如此判定），且該項已標明由 3.5 驗證；改寫它需要重新描述一個本來就正確涵蓋的檢查範圍，收益低於再次改動已通過驗證之敘述的風險，因此保留現狀。

降級與丟棄追溯（confidence filter）：

- Q1、Q2 原標為 Warning、`confidence` 皆為 55，落在 `[50, 80)`，降級為 Suggestion，不計入 blocking set。
- A1（45）、A2（35）、A3（40）、Q3（40）`confidence` 低於 50，依 filter 丟棄，未計入 blocking 統計；其中 A1、A3、Q3 的建議成本極低且經查證成立，仍自願採納，A2 依上述理由未採納。
- A3 與 Q2 為同一 location（design Contract 第 4 點、tasks 3.4）與同一缺陷機制，依 `location + summary` 聚合併為一項，取較高 `confidence` 55；兩者 `layer` 皆為 `design`，無需套用 design 優先規則。
- A2 的 `layer` 為 `text`，主 agent 依規則複檢：其修正僅調整任務敘述的涵蓋範圍措辭，不改變任何行為或設計陳述，維持 `text` 分類。

pre-round 機械自檢（本輪 fix actions 完成後重跑）：

- 註解平衡：delta spec 無 `<!--`／`-->`。
- 數量一致性：design Implementation Contract 維持 11 條，tasks 引用涵蓋第 1 至第 11 點全部條號。
- 引數敘述傳播檢查：`--skip-download` 在 design、delta spec、tasks 三份 artifact 中皆出現且語意一致（第一次與第二次 invocation 均要求保留），無單邊收緊殘留。
- 識別字交叉檢查：`fetchSubtitles`、`fetchAudioTracks` 存在於 `Tubify/Services/YouTubeMetadataService.swift`；`is_upcoming` 存在於 `Tubify/ViewModels/DownloadManager.swift`；`release_timestamp` 存在於 `Tubify/ViewModels/DownloadManager.swift` 與 `Tubify/Services/YouTubeMetadataService.swift`，拼寫與 artifacts 一致。
- 平行標記檢查：`[P]` 仍只有 4.1、4.2 兩項且目標檔案互異。
- delta spec 標題身分檢查：仍只有 `## ADDED Requirements`，不適用。
- signal-derived 檢查：30 個 open signal 皆無 `check` 欄位，回退 best-effort；本輪相關的 `recovery-excluded-state-coverage`（Q1，`.scheduled` 出口未被點名）、`contract-spec-definition-mismatch`（Q2 的單邊收緊）皆已處理。
- 修正後重跑 `"$cash_cli" validate "cookieless-subtitle-detection"`：通過。

本輪 fix actions 未修改 change 目錄以外的任何檔案，因此不需執行 `touched record`。本輪無 `未修復：裁判面保護` 記錄；本次 run 四輪皆無此類記錄。

## Decision

passed
