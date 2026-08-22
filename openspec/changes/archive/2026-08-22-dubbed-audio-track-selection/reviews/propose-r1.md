# Cash Propose Review — Round 1

## Reviewer Findings

### Critical

1. `severity`: Critical｜`confidence`: 80｜`layer`: design｜`location`: `tasks.md` task 3.6（修正前）｜`summary`: 「帶 cookies 的重試同樣帶上 extractor args」scenario 的唯一承接任務要求以 `download` + fixture 觀察第 2 次 invocation，但 `download` 的 cookies fallback 由硬編碼的 `SafariCookiesService.shared.transformCommand` 提供，缺完整磁碟存取時回傳 `nil`、第 2 次 invocation 不會發生；既有測試為此全部改走 `executeDownloadFlow` 接縫，而該接縫以 `attemptExecutor` 取代真實 process，看不到 fixture argv，兩條路互斥｜`recommendation`: 拆成可執行的多段承接，並在 design 記錄無接縫的事實｜來源: Reviewer A

### Warning

2. `severity`: Warning｜`confidence`: 100｜`layer`: design｜`location`: `design.md` C4 與 `specs/audio-track-selection/spec.md`｜`summary`: C4 的切分規則未涵蓋 yt-dlp 的 `,` 多重下載語法，`bv+ba,b` 會被改寫為 `bv+ba,b[language=ja]`，`bv+ba` 這一路完全沒有語言限制，直接違反 C4 自己的「MUST NOT 產生任何不含 `[language=<code>]` 的 alternative」｜`recommendation`: 把 `,` 納入切分層級並補測試｜來源: Reviewer B（confidence 55）；主 agent 實測 `-f "ba[language=ja],b"` 輸出 `Downloading 2 format(s): 251-0, 18` 確認 `,` 為合法語法且違反成立，依 rubric「直接違反 artifact requirement」提升至 100

3. `severity`: Warning｜`confidence`: 95｜`layer`: design｜`location`: `tasks.md` task 5.3（修正前）｜`summary`: 該檢查點指名在 `DownloadManager.swift` 與 `MediaSelectionView.swift` 檢查 `LanguageFilter.supportedLanguagePrefixes`，但該識別字只存在於 `Tubify/Models/SubtitleInfo.swift:6`，檢查無法在指定範圍內執行｜`recommendation`: 拆成兩個檢查點並各自指向正確檔案｜來源: Reviewer A

4. `severity`: Warning｜`confidence`: 88｜`layer`: design｜`location`: `tasks.md` task 4.3（修正前）｜`summary`: 「結果的 alternative 數量與原字串一致」恆真：bracket-aware 與 naive 兩種實作、兩種計數慣例下斷言都通過，對切分是否 bracket-aware 沒有鑑別力｜`recommendation`: 改為完整字串相等斷言｜來源: Reviewer A

5. `severity`: Warning｜`confidence`: 85｜`layer`: design｜`location`: `specs/audio-track-selection/spec.md`「不得保留未受限的 fallback」scenario vs `design.md` C4｜`summary`: spec 以「以 `/` 切開」定義驗收、C4 以「不位於 `[` 與 `]` 之間的 `/`」定義實作；含中括號的 format 下符合 C4 的實作會判定為違反 spec｜`recommendation`: spec 的 alternative 定義與 C4 逐字對齊｜來源: Reviewer A

### Suggestion

6. `severity`: Suggestion｜`confidence`: 95｜`layer`: design｜`location`: `design.md` D6｜`summary`: D6 稱現行改寫留下「三個」未受限 alternative，實際為五個（尾端接上的 3 個之外，第一個匹配之後未被改寫的 `bv*+ba` 與 `b` 同樣未受限）｜來源: Reviewer A

7. `severity`: Suggestion｜`confidence`: 75｜`layer`: design｜`location`: `design.md` Goals／Non-Goals、`tasks.md` 第 5 節（修正前）｜`summary`: C2 改變 `fetchMediaOptions` 回傳 formats 的內容，而該 formats 正是 post_live 可下載性判定的輸入；artifacts 未記錄此耦合，也無 task 承接 `youtube-post-live-replay` 的迴歸；`fetchVideoInfo` 維持 default client 形成兩段判定不對稱｜來源: Reviewer A（75）與 Reviewer B（60）獨立提出，合併取較高值後仍低於 80，降級為 Suggestion

8. `severity`: Suggestion｜`confidence`: 70｜`layer`: design｜`location`: `tasks.md` task 5.4（修正前）｜`summary`: 檢查點一（`isErrorLine` 對 `ERROR:` 開頭訊息回傳 true）近乎恆真，檢查點二只驗「未被改動」，delta spec 的 `##### Example: 取不到選定語言時以失敗結束` 沒有任何演練｜來源: Reviewer B（70）與 Reviewer A（60）獨立提出

9. `severity`: Suggestion｜`confidence`: 70｜`layer`: design｜`location`: `design.md` Risks（修正前）｜`summary`: `Requested format is not available` 不符合 `indicatesLoginRequired` 與 `videoData403Marker` 任一訊號，因此不會觸發帶 cookies 的重試；此與 cookies 兩段式策略的互動未記入 Risks｜來源: Reviewer B

10. `severity`: Suggestion｜`confidence`: 70｜`layer`: text｜`location`: `design.md` Context｜`summary`: `YTDLPService.download` 的行號錨點應為 `:251`，寫成 `:252`｜來源: Reviewer A

11. `severity`: Suggestion｜`confidence`: 60｜`layer`: design｜`location`: `design.md` D1｜`summary`: D1 把「yt-dlp 自選 android vr」的 27 筆量測當成 `player_client=default` 的結果，該等同關係未經實測｜來源: Reviewer B

12. `severity`: Suggestion｜`confidence`: 60｜`layer`: design｜`location`: `specs/audio-track-selection/spec.md`「偵測與下載使用同一份 client 設定來源」scenario vs `tasks.md` 1.1／5.1｜`summary`: spec 的「程式碼中 MUST NOT 存在該值的第二處字面值定義」未限定範圍，但 task 1.1 刻意在測試寫入該字面值、task 5.1 的 grep 只掃 `Tubify/`｜來源: Reviewer A（60）與 Reviewer B（50）獨立提出

13. `severity`: Suggestion｜`confidence`: 55｜`layer`: design｜`location`: `design.md` D9／C6、`tasks.md` task 2.1（修正前）｜`summary`: fixture 的 argv 記錄自創「單一檔案 + 分隔標記」形狀，未沿用同 repo `MetadataFixture` 已驗證的 `invocation-$n.args` 做法｜來源: Reviewer A

14. `severity`: Suggestion｜`confidence`: 55｜`layer`: design｜`location`: `tasks.md` task 1.2（修正前）｜`summary`: 1.2 的斷言被 1.1 的完整相等比對完全涵蓋，1.1 通過時 1.2 不可能失敗｜來源: Reviewer A

15. `severity`: Suggestion｜`confidence`: 55｜`layer`: design｜`location`: `specs/audio-track-selection/spec.md`、`design.md` D2、`tasks.md` 第 5 節（修正前）｜`summary`: C2／C3 對非 YouTube URL 同樣生效，proposal 與 design 未記錄此觸及面，手動驗證全是 YouTube｜來源: Reviewer B（55）與 Reviewer A（50）獨立提出

### 低於門檻而未納入決策的 finding（降級 trace）

- Reviewer B「播放清單規模下的累積請求量」`confidence` 45 → 低於 50，丟棄；但其論點已併入 design 最後一條 Risk 的補述。
- Reviewer B「`AudioSelection(selectedLanguage: nil)` 未被演練」`confidence` 40 → 低於 50，丟棄；仍併入 C3 與 task 3.2，成本極低。
- Reviewer B「合併 client 後語言代碼可能出現 `en` 與 `en-US` 兩種而使門檻誤判」`confidence` 35 → 低於 50，丟棄。主 agent 以 `https://www.youtube.com/watch?v=dQw4w9WgXcQ` 實測合併查詢，純音訊語言集合為 `['en']`、大小為 1，未復現該機制；仍把「語言代碼集合大小為 1」寫進 task 5.10 的驗收點。

## Rating

- post-filter 累積 blocking set Critical 數：1
- post-filter 累積 blocking set Warning 數：4
- 非 blocking 的 triaged finding 數：10
- `critical_gap`: true
- `round_type`: full
- rationale：本輪為 run 的第一輪，全部 surviving Critical 與 Warning 皆為 blocking。1 個 Critical（task 3.6 無可用測試接縫，會在 apply 階段卡住）與 4 個 Warning（`,` 語法留下未受限 alternative、task 5.3 指名錯檔案、task 4.3 恆真斷言、spec 與 C4 的 alternative 定義不一致）都是可在 propose 階段修好的 artifact 缺陷，因此 `next_round`。

## Fix Actions

- **修 Critical 1**（`design.md`、`tasks.md`）：design C7 改為記錄「帶 cookies 的第二次 invocation 沒有可注入接縫」並拆成三段承接；tasks 把原 3.6 拆為 3.6（`download` 第一次 attempt 的 argv 同時斷言含 extractor args 且不含 cookies，藉此觀察注入順序）、3.7（直接呼叫 `executeDownloadFlow` 且不傳 `attemptExecutor`，由 fixture 實際執行兩次 attempt）、3.8（`removeSafariCookies` 的字串斷言），並新增 5.5 的 code review 承接 `transformCommand` 那一段。
- **修 Warning 2**（`design.md`、`specs/audio-track-selection/spec.md`、`tasks.md`）：C4 增加「先以不位於 `[` 與 `]` 之間的 `,` 切成獨立下載群組」的切分層級；spec 新增「逗號分隔的獨立下載群組各自受限」scenario；tasks 新增 4.4 以 `bv+ba,b` 為輸入的完整字串相等測試。同一 fix pass 併入 design Risks 的括號分組（`()`）不受支援條目。
- **修 Warning 3**（`tasks.md`）：5.3 拆為兩個檢查點，`filteredAudioTracks.count > 1` 指向 `DownloadManager.swift:500` 與 `MediaSelectionView.swift` 的 `:31`／`:40`／`:114`，`supportedLanguagePrefixes` 指向 `Tubify/Models/SubtitleInfo.swift:6`。
- **修 Warning 4**（`tasks.md`）：4.3 改為完整字串相等斷言（`ba[format_note*=A/B]+bv[language=ja]`），並在任務敘述寫明計數斷言為何沒有鑑別力。
- **修 Warning 5**（`specs/audio-track-selection/spec.md`）：requirement 正文加入 alternative 的明確定義（先以不在 `[]` 內的 `,` 切群組、再以不在 `[]` 內的 `/` 切段），「不得保留未受限的 fallback」scenario 改為引用該定義，並新增「中括號內的分隔字元不參與切分」scenario。
- **修 Suggestion 6**（`design.md`）：D6 的「三個」改為「五個」，並補述未受限 alternative 的兩個來源。
- **修 Suggestion 7**（`design.md`、`tasks.md`、`proposal.md`）：新增 D10 記錄 `fetchVideoInfo` 維持 default client 的決策與兩段判定不對稱，新增對應 Risk，新增 task 5.6 的 post_live 解析層迴歸測試，proposal Non-Goals 補一條。
- **修 Suggestion 8**（`tasks.md`、`specs/audio-track-selection/spec.md`）：5.4 改為兩個可執行斷言（`shouldRetryWithCookies` 對該訊息為 `false`；fixture 讓該訊息成為第 1 次結果時 `download` 拋出含該字串的錯誤且 invocation 次數恰為 1），spec 的 Example 補上「invocation 次數恰為 1」與「不觸發任何重試」兩條 THEN。
- **修 Suggestion 9**（`design.md`）：Risks 新增「`Requested format is not available` 不觸發帶 cookies 的重試」條目，說明取捨與不新增重試訊號的理由；Non-Goals 同步補一條。
- **修 Suggestion 10**（`design.md`）：行號錨點 `:252` 改為 `:251`。
- **修 Suggestion 11**（`design.md`）：主 agent 實測 `--extractor-args "youtube:player_client=default"` 單獨結果為 formats 27 筆、純音訊 4 筆、語言僅 `en`，與不帶引數時相同，D1 的前提因此成立並寫入 Context。同一次實測另發現合併後 `140`／`249`／`251` 被重新命名為 `140-21`／`249-21`／`251-21`，D1 原本「既有 format 仍在清單中」的措辭過強，已改為「等價項仍在、部分 format_id 被加上後綴」，並新增對應 Risk。
- **修 Suggestion 12**（`specs/audio-track-selection/spec.md`、`design.md`）：scenario 的 THEN 限定範圍為「產品程式碼（`Tubify/` 之下）」，D5 補述測試以獨立字面值作為 oracle 是刻意的。
- **修 Suggestion 13**（`design.md`、`tasks.md`）：D9 與 C6 改為沿用 `makeMetadataFixture` 的計數檔 + `invocation-$n.args` 形狀，`arguments(at:)` 簽章對齊。
- **修 Suggestion 14**（`tasks.md`）：1.2 改為斷言兩次 invocation 中等於 `--extractor-args` 的元素各恰為 1 個，取得防重複注入的獨立鑑別力。
- **修 Suggestion 15**（`design.md`、`proposal.md`、`tasks.md`）：design Risks 新增「非 YouTube 任務同樣會被注入」條目，proposal Non-Goals 補一條，tasks 新增 5.8 的非 YouTube 手動驗證。
- **fix propagation**：本輪所有改動的概念（alternative 定義、`,` 切分、fixture argv API、task 編號 3.6/3.7/3.8 與 5.4/5.5/5.6/5.8）已跨 `proposal.md`／`design.md`／`specs/audio-track-selection/spec.md`／`tasks.md` 逐一 grep 對齊；design C7 與 Risks 引用的 task 編號已對照 `tasks.md` 實際存在的 34 個 task 確認。
- **修改的檔案**：`openspec/changes/dubbed-audio-track-selection/proposal.md`、`design.md`、`specs/audio-track-selection/spec.md`、`tasks.md`。
- **post-fix 檢查**：重新執行 `.cash-skills/bin/cash validate dubbed-audio-track-selection`（通過）；重新執行 pre-round mechanical self-check：delta spec 無 `<!--`／`-->` 不匹配、design 對 tasks 的 10 處編號引用皆存在、識別字（`youtubePlayerClientArgumentValue`、`youtubeExtractorArguments`、`injectExtractorArgs`、`injectLanguageIntoFormat`、`injectAudioLanguage`、`makeYTDLPFixture`、`makeMetadataFixture`、`arguments(at:)`）跨 artifact 拼寫一致、MODIFIED requirement 標題與 master spec 逐字相符。

## Decision

next_round
