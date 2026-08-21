# Cash Propose Review — Round 1

## Reviewer Findings

### Critical

（無）

### Warning

**W1**（Reviewer A）
- `severity`: Warning
- `confidence`: 100
- `layer`: design
- `location`: `design.md` `## Context`；`proposal.md` `## Motivation`
- `summary`: design 與 proposal 宣稱下載路徑的 cookies fallback 分類函式是 `indicatesLoginRequired(_:)`，但實際 gate 是其嚴格超集 `shouldRetryWithCookies(_:)`（= `indicatesLoginRequired(_:)` 或 `isDownloadVideoData403(_:)`）。
- `recommendation`: 改寫為 `shouldRetryWithCookies` 由兩個訊號組成，並明寫本變更只重用登入訊號清單、刻意排除 video-data 403 訊號及其理由。

**W2**（Reviewer A，與 Reviewer B 的同主題 finding 合併）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: `specs/subtitle-selection/spec.md` `### Requirement: 需登入分類在下載與媒體選項查詢間共用單一定義`
- `summary`: 「同一則訊息在兩條路徑判定一致」可被 video-data 403 反例推翻（下載路徑會重試、媒體選項查詢不會），且該 requirement 沒有任何 task 承接。
- `recommendation`: 把比較對象限縮為「共用同一個登入訊號入口」而非「整體重試決策一致」，並在 design 驗證責任歸屬指派承接的 task。

**W3**（Reviewer A，與 Reviewer B 的兩項同主題 finding 合併）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: `design.md` Implementation Contract 第 8 點與驗證責任歸屬；`tasks.md` 2.1、2.2
- `summary`: 「以預設初始化建立的實例仍可解析路徑」在目前程式碼沒有可觀察對象，且預設實例與 `shared` 走同一條解析路徑，屬恆真斷言；同時 D3 未界定 provider 涵蓋 actor 內 5 處路徑解析點中的哪些。
- `recommendation`: 改為行為式驗收（provider 指向 fixture 時實際呼叫該 fixture、指向不存在路徑時拋出 `MetadataError`），並逐字界定 provider 統一涵蓋全部 5 處解析點。

### Suggestion

- **S1**（A，`confidence` 75，由 Warning 降級）`design.md` Contract 第 1 點後半「其餘引數維持既有旗標」無 task 承接；建議 tasks 改為引數完整相等比對，並在 spec scenario 補一條 AND。
- **S2**（A，`confidence` 60）design 宣稱端到端「現有 test target 沒有可觀察接縫」範圍過寬，`DownloadManager` 的 `onMediaSelectionNeeded` 與 `YouTubeMetadataServiceProtocol` mock 其實是既有接縫。
- **S3**（A，`confidence` 55）手動驗證任務未要求「保留勾選並送出」，照字面執行不會產生 `--write-sub`。
- **S4**（A + B 合併，`confidence` 50）第二條 requirement 對下載路徑施加約束卻只掛在 `subtitle-selection`，與 Non-Goals 形成邊界模糊。
- **S5**（B，`confidence` 70，由 Warning 降級）下載階段若 fallback 到帶 cookies 的 template，使用者已選的字幕語言可能不存在於該 client，yt-dlp 只 warning 不失敗，字幕靜默缺席。
- **S6**（B，`confidence` 70，由 Warning 降級）`youtube-post-live-replay` 的 follow-up format lookup 就是 `fetchMediaOptions`，屬受影響 capability 但未列入 Impact，且 `fetchVideoInfo` 仍帶 cookies 造成兩次查詢不同 client 的不對稱。
- **S7**（B，`confidence` 60，由 Warning 降級）音軌偵測同樣依賴同一份 JSON 的 `formats`，但證據與論證只涵蓋字幕。
- **S8**（B，`confidence` 65，由 Warning 降級）重試條件只看 exit code，「exit 0 但內容殘缺」的降級成功無法重試，artifacts 未表態。
- **S9**（B，`confidence` 55，由 Warning 降級）Contract 未交代 `ytdlpNotFound`、`process.run()` 失敗、stderr 為空或非 UTF-8 這三條與 exit code 無關的失敗出口。
- **S10**（B，`confidence` 50）播放清單情境下成本是 2N 次循序 invocation，Risks 只以單支影片論述。
- **S11**（B，`confidence` 50）Risks 稱殘餘風險「與下載路徑相同」不成立；下載路徑基線本就是 cookieless，metadata 路徑基線是一律帶 cookies，此為新增風險。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：3（W1、W2、W3）
- 非 blocking 的 triaged finding 數：11（S1–S11）
- `critical_gap`: false
- `round_type`: full
- rationale：本輪為本次 run 的第一輪，所有存活的 Critical 與 Warning 皆為 blocking。無 Critical，但三項 Warning 都指向可稽核的事實錯誤或無鑑別力的驗收方式：W1 是 design 對既有程式碼的 code-facing 宣稱不成立（有直接程式碼證據，`confidence` 100）；W2 的 spec scenario 存在可構造的反例且無 task 承接；W3 的驗收方式即使實作正確也無法失敗，等於沒有驗收。三者都會讓下游 apply 依據錯誤前提實作或誤以為某面向已被涵蓋，因此不通過本輪。

## Fix Actions

修正的檔案與理由：

1. `openspec/changes/cookieless-subtitle-detection/design.md`（全文重寫）
   - 修 W1：`## Context` 改寫為「下載路徑的 gate 是 `shouldRetryWithCookies(_:)`，由 `indicatesLoginRequired(_:)` 與 `isDownloadVideoData403(_:)` 組成」，D2 標題與內文補上刻意排除 video-data 403 的理由（媒體選項查詢帶 `--skip-download`，不下載 video data）。
   - 修 W3：Contract 第 9 點（原第 8 點）改為行為式，並逐字界定 provider 統一涵蓋 actor 內全部 5 處路徑解析點；驗證責任歸屬同步改為行為式測試，明寫不以「預設實例與 `shared` 互比」為據。
   - 修 S1：Contract 第 1 點改為「引數 MUST 恰為 `["-J", "--skip-download", "--no-playlist", url]`」。
   - 修 S2：驗證責任歸屬最後一項限縮為「真實 yt-dlp 的字幕回傳差異」無自動化接縫，並註明 `.waitingForMediaSelection` 與 `onMediaSelectionNeeded` 屬既有行為、已有既有測試接縫覆蓋。
   - 修 S5：Risks 新增「下載階段 cookies fallback 可能讓已選字幕靜默缺席」。
   - 修 S6：Risks 新增「`post_live` 分支的查詢不對稱」，說明 `fetchVideoInfo` 仍帶 cookies 而 `fetchMediaOptions` 改為 cookieless。
   - 修 S7：`## Context` 補上以 app 實際判準（audio-only 且有 `language`）實測的音軌數據表（不帶 cookies 4 個格式、語言 `{zh-Hant}`；帶 cookies 0 個），Risks 新增「音軌證據僅一個樣本」並說明 spec 因此只對字幕軌作保證。
   - 修 S8：D5 標題與內文補上「重試條件只看 exit code，不看內容是否豐富」及其理由，Risks 新增「降級成功不重試」。
   - 修 S9：Contract 新增第 7 點，逐條交代 `ytdlpNotFound`、`process.run()` 失敗、stderr 無法解碼或為空三條出口。
   - 修 S10：Risks 新增「播放清單的成本是 2N 而非 +1」並寫明為刻意取捨。
   - 修 S11：Risks 首項改寫為「本變更新增的風險」，刪除與下載路徑等價的錯誤論述。
   - 另補：`## Context` 註明 `YouTubeMetadataService` 是 `actor`、`YouTubeMetadataServiceProtocol` 只能替換整個 service 而無法觀察內部 invocation 引數。

2. `openspec/changes/cookieless-subtitle-detection/proposal.md`
   - 修 W1：`## Motivation` 與 `## Proposed Solution` 同步 `shouldRetryWithCookies` 的正確組成與排除 403 訊號的理由。
   - 修 S4：`## Capabilities` 的 `subtitle-selection` 條目改寫為「僅共用訊號清單，不共用整體重試決策」。
   - 修 S6：`## Capabilities` 與 `## Impact` 的 Affected specs 加入 `youtube-post-live-replay`（不修改其 spec 文字，僅標記受影響並需回歸）。

3. `openspec/changes/cookieless-subtitle-detection/specs/subtitle-selection/spec.md`（全文重寫）
   - 修 W2 與 S4：第二條 requirement 更名為「媒體選項查詢重用下載路徑的登入訊號定義」，主詞收回媒體選項查詢，正文逐字寫明「共用的是訊號定義本身，不是整體 cookies 重試決策」，並新增 scenario「video-data 403 不使媒體選項查詢重試」。
   - 修 S1：第一條 scenario 補一條 AND，要求第一次 invocation 保留既有三個旗標與目標 url 且不含其他引數。
   - 修 S8：「第一次查詢成功則不重試」scenario 補一條 AND，明寫結果是否為空不改變判定。
   - 修 S9：新增 scenario「與 exit code 無關的失敗不觸發重試」。
   - 另補：新增 scenario「重試後仍失敗以第二次的訊息回報」，對齊 Contract 第 4 點。

4. `openspec/changes/cookieless-subtitle-detection/tasks.md`（全文重寫）
   - 修 W2：1.3 明寫承接 delta spec 的登入訊號共用 requirement。
   - 修 W3：2.1 改為行為式驗收並逐字禁止恆真斷言；2.2 明列 5 處解析點與統一的私有解析方法。
   - 修 S1：3.2 改為引數完整相等比對。
   - 修 S3：手動驗證任務（4.5）補上「保留勾選並確認送出」的前置步驟。
   - 修 S5：4.5 的驗收點改為「實際產生對應語言的字幕檔」，日誌 `--write-sub` 降為佐證之一。
   - 修 S6：新增 4.3 `post_live` 迴歸檢查任務。
   - 修 S8：3.3 增加「exit 0 但內容為空」的情境。
   - 修 S9：新增 3.8 驗證 stderr 為空時的分類輸入與不重試。
   - 另補：新增 3.5 驗證兩次皆失敗時以第二次 stderr 為準（對齊 Contract 第 4 點）；全檔 contract 條號因新增第 7 點而重新對應。

降級追溯（confidence filter）：

- S5、S6、S8、S1、B 的音軌 finding（S7）、B 的失敗出口 finding（S9）原由 reviewer 標為 Warning，`confidence` 分別為 70、70、65、75、60、55，落在 `[50, 80)` 區間，依 confidence filter 降級為 Suggestion，不計入 blocking set。
- Reviewer B 的「Contract 第 4 點的第二次失敗分支沒有對應測試」finding `confidence` 45，低於 50，依 filter 丟棄，未計入任何統計；惟其指出的缺口與 S1 的完整性訴求同向，已於 tasks 3.5 一併補上。
- Reviewer B 的 provider 涵蓋範圍 finding（`confidence` 60）與 Reviewer A 的 W3 為同一 location 與同一缺陷機制，依 `location + summary` 聚合併入 W3，取較高 `confidence` 85。
- Reviewer A 與 Reviewer B 各有一項關於 capability 歸屬的 finding，同樣聚合為 S4。

pre-round 機械自檢（本輪 fix actions 完成後重跑）：

- 註解平衡：delta spec 無 `<!--`／`-->`，無殘留 `---` 分隔符。
- 數量一致性：design Implementation Contract 共 11 條，tasks 引用涵蓋第 1 至第 11 點全部條號；「三個呼叫端」與 `Tubify/ViewModels/DownloadManager.swift` 實際 3 處 `fetchMediaOptions` 呼叫相符；「5 處路徑解析點」與 `Tubify/Services/YouTubeMetadataService.swift` 實際 5 處 `YTDLPService.shared.findYTDLPPath()` 相符，行號 212、293、463、559、673 逐一核對無誤。
- 識別字交叉檢查：`isDownloadVideoData403`、`handlePostLiveFormatLookupError`、`hasUsableMediaFormats`、`parseAudioTracks`、`parseFormats`、`未知錯誤`、`automatic_captions` 全數在程式碼中存在且拼寫一致；artifacts 引用的所有檔案路徑均存在。
- delta spec 標題身分檢查：本次 delta 只有 `## ADDED Requirements`，無 MODIFIED／REMOVED／RENAMED，不適用。
- signal-derived 檢查：`openspec/signals/` 下 30 個 signal 皆為 `status: open` 且皆無 `check` 欄位，依規則回退為 best-effort 判斷；本輪相關的 `unverified-design-claim`、`unassigned-verification-responsibility`、`test-setup-bypasses-target-condition`、`proposal-impact-file-scope-drift` 四類已分別由 W1、W2／W3、W3、S6 的修正涵蓋。
- 修正後重跑 `"$cash_cli" validate "cookieless-subtitle-detection"`：通過。

本輪 fix actions 未修改 change 目錄以外的任何檔案，因此不需執行 `touched record`。本輪無 `未修復：裁判面保護` 記錄。

## Decision

next_round
