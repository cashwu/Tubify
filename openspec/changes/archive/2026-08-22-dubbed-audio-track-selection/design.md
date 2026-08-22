## Context

`fetchMediaOptions`（`Tubify/Services/YouTubeMetadataService.swift`）目前以 `["-J", "--skip-download", "--no-playlist"]` 為基底引數查詢媒體選項，未指定 player client。`DownloadManager` 依查詢結果的 `filteredAudioTracks.count > 1`（`Tubify/ViewModels/DownloadManager.swift:500`）決定是否顯示媒體選擇視窗的音軌區塊。

下載側，`YTDLPService.download`（`Tubify/Services/YTDLPService.swift:251`）在使用者選定音軌語言時呼叫 `injectAudioLanguage`，後者再由 `injectLanguageIntoFormat`（`:1186`）改寫 format 字串。指令範本是使用者可編輯的字串，最終由 `parseCommandArguments`（`:1082`）以空白與引號切成 argv，不經過 shell。

以下事實由實測建立（yt-dlp 2026.07.04、影片 `https://www.youtube.com/watch?v=Af6i6ChAVTw`）：

- 不帶 `--extractor-args` 時 yt-dlp 選用 android vr client，`formats` 27 筆、純音訊 4 筆、語言僅 `en`。
- 單獨指定 `--extractor-args "youtube:player_client=default"` 的結果與不帶引數時相同：`formats` 27 筆、純音訊 4 筆、語言僅 `en`。
- 帶 `--extractor-args "youtube:player_client=default,web_embedded"` 時 `formats` 116 筆、純音訊 93 筆、語言 22 種，`subtitles` 維持 24 筆，stderr 無 WARNING 或 ERROR。
- 合併後既有音訊格式的等價項仍在清單中，但部分 format_id 被加上後綴：`140` 變為 `140-21`、`249` 變為 `249-21`、`251` 變為 `251-21`，`139` 維持原名。以屬性撰寫的選擇器（`ba[ext=m4a]`）不受影響，以明確 format id 撰寫的範本會受影響。
- 使用者若選了配音語言，現行 format 改寫產生的未受限 alternative 會在配音 format 不存在時靜默改用原聲：缺 JavaScript runtime 的環境下 yt-dlp 印出 `n challenge solving failed`，最終下載 `251`（英文原聲）而非 `251-0`（日文），流程以成功結束。
- yt-dlp 的 `-f` 支援以 `,` 分隔多個獨立下載：`-f "ba[language=ja],b"` 實測輸出 `Downloading 2 format(s): 251-0, 18`。
- 指定不存在的 client 名稱時 yt-dlp 只印出 `WARNING: [youtube] Skipping unsupported client "..."` 並以 exit code 0 繼續。
- `youtube:` 前綴的 extractor args 對其他 extractor 惰性：對 `https://archive.org/details/BigBuckBunny_124` 帶與不帶該引數，回傳的 title 與 3 筆 formats 完全相同。

## Goals / Non-Goals

Goals：

- 媒體選項查詢能取得 YouTube 的配音音軌，使多配音影片的音軌區塊出現。
- 下載 invocation 與偵測 invocation 使用同一組 player client 設定，兩者不得各自為政。
- 使用者明確選定的音軌語言若取不到，以明確失敗結束，不得靜默交付其他語言。

Non-Goals：

- 不擴大 `LanguageFilter.supportedLanguagePrefixes`（維持 `en`／`ja`／`zh`）。
- 不調整 `filteredAudioTracks.count > 1` 的顯示門檻。
- 不安裝或偵測 JavaScript runtime（deno／node）與 PO Token。
- 不改動既無生產呼叫端的 `fetchSubtitles` 與 `fetchAudioTracks`。
- 不改動 `fetchVideoInfo` 的引數（見 D10）。
- 不改動 `AppSettingsDefaults` 的任何指令範本字面值。
- 不為「format 不可得」新增 cookies 重試訊號（見 Risks）。

## Decisions

**D1：採用 `player_client=default,web_embedded` 而非單獨 `web_embedded`。** 實測 `web_embedded` 單獨使用同樣取得 22 種語言，但它會取代而非擴充 default client 的 format 清單。default client 是目前所有下載實際依賴的來源，取代它等於把未量測的迴歸風險加到每一次下載。合併寫法實測得到 116 筆 format，涵蓋 default 單獨量測到的 27 筆的等價項（部分 format_id 被加上後綴，見 Context 與 Risks）。

**D2：`--extractor-args` 無條件套用於媒體選項查詢，不做 YouTube URL 判斷。** `youtube:` 前綴的 extractor args 對其他 extractor 惰性，已由 archive.org 的對照實測確認。加入 URL 判斷會讓 `YouTubeMetadataService` 與 `YTDLPService` 依賴 `DownloadManager.isValidYouTubeURL`，跨層依賴的成本高於收益。

**D3：下載路徑只在使用者選定語言時注入 `--extractor-args`。** 未選語言時下載行為與現況完全一致，把本變更對既有下載的影響面限縮在「使用者確實選了配音」這條路徑上。

**D4：注入點在指令範本字串尾端。** `parseCommandArguments` 不經 shell，尾端附加的 token 會被正確切分；實測 yt-dlp 接受置於 URL 之後的選項（`-f "bv[height<=144]+ba[language=ja]" URL --extractor-args "youtube:player_client=default,web_embedded"` 正確選出 `394+251-0`）。尾端附加不需要定位範本中的可執行檔 token，規則單純且可逐字驗證。

**D5：偵測與下載共用單一常數。** 兩條路徑各自寫一次 client 字面值必然漂移。以 `YTDLPService` 的 static 常數作為單一事實來源，比對兩處取值相同即可驗證一致性。此約束的範圍是產品程式碼（`Tubify/`）。測試端分兩類：驗證「常數的值本身正確」的那一組斷言（task 1.1 的引數完整相等比對）MUST 以獨立字面值作為 oracle，否則測試與被測程式共用同一個值時無法偵測該值被改動；其餘只驗「有沒有注入、注入幾次」的斷言引用 `YTDLPService.youtubePlayerClientArgumentValue` 即可，因為它們要鑑別的不是該值本身。

**D6：語言限制套用到每一個 alternative，並移除未受限的整串 fallback。** 現行改寫只處理第一個匹配到的音訊選擇器，並把原始 format 字串整串接在後面。以預設範本 `bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b` 為例，改寫結果為 `bv*[ext=mp4]+ba[ext=m4a][language=ja]/bv*+ba/b/bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b`，共 6 個 alternative，其中 5 個沒有語言限制——除了尾端接上的 3 個之外，位於第一個匹配之後、未被改寫的 `bv*+ba` 與 `b` 同樣未受限。任何一個匹配成功都會交付原聲。實測移除 fallback 後，語言不可得時 yt-dlp 以 `ERROR: [youtube] ...: Requested format is not available.` 結束，屬明確失敗。

**D7：以「alternative 的最後一個 `+` part」作為語言限制的落點。** yt-dlp 慣例是 `video+audio`，預設範本與內建常用範本全部符合。單一 part 的 alternative（如 `b`）本身承載音訊，同樣落上限制。此規則不解析選擇器語意，只依位置，因此可逐字驗證。

**D8：不新增錯誤分類。** `Requested format is not available` 由 yt-dlp 以 `ERROR:` 前綴輸出，`YTDLPService.isErrorLine`（`:683`）認得該前綴，訊息沿既有 `YTDLPError.executionFailed` 路徑呈現。該訊息不符合 `indicatesLoginRequired` 的任何訊號，也不含 `videoData403Marker`，因此 `shouldRetryWithCookies` 對它回傳 `false`，不會觸發任何重試——這正是「不得以其他語言完成下載」所需的行為。新增分類會與 `download-ui-workflows` 既有的錯誤呈現要求重疊，且沒有新的處置動作可提供。

**D9：`makeYTDLPFixture` 沿用 `MetadataFixture` 既有的逐次獨立檔案形狀。** 現行 fixture 只以 `echo "$*"` 記錄整行，無法區分 token 邊界。`TubifyTests/YouTubeMetadataServiceTests.swift` 的 `makeMetadataFixture` 已有可用做法：以計數檔遞增 invocation 序號，把該次每個引數逐行寫入 `invocation-$n.args`，並以 `arguments(at:)` 讀取。沿用同一形狀可讓兩個 fixture 的 argv 讀取 API 一致，且既有斷言讀的仍是 `invocations.log`，不受影響。

**D10：`fetchVideoInfo` 維持不加 extractor args，接受兩段 post_live 判定使用不同 client 的不對稱。** post_live 的可下載性判定分兩段：第一段用 `fetchVideoInfo` 的 `hasUsableMediaFormats`（`Tubify/ViewModels/DownloadManager.swift:471`），第二段用 `fetchMediaOptions` 的 formats（`:474`、`:660`）。本變更只改第二段的輸入，使第二段看到的 format 集合嚴格變大。把 extractor args 一併加到 `fetchVideoInfo` 會擴大本變更對每一次 metadata 取得的影響面，而該路徑與配音音軌無關。此不對稱的後果寫入 Risks，並由 tasks 的 post_live 迴歸任務把關。

## Implementation Contract

**C1 — 共用常數（`Tubify/Services/YTDLPService.swift`）**

- 在 `YTDLPService` 新增 `static let youtubePlayerClientArgumentValue = "youtube:player_client=default,web_embedded"`。
- 新增 `static let youtubeExtractorArguments: [String] = ["--extractor-args", youtubePlayerClientArgumentValue]`。
- 媒體選項查詢與下載範本注入 MUST 只從這兩個常數取值；`Tubify/` 之下 MUST NOT 出現該值的第二處字面值。

**C2 — 媒體選項查詢引數（`Tubify/Services/YouTubeMetadataService.swift`，`fetchMediaOptions`）**

- `baseArguments` 改為 `["-J", "--skip-download", "--no-playlist"] + YTDLPService.youtubeExtractorArguments`。
- 第一次 invocation 的引數恰為 `baseArguments + [url]`。
- 需登入重試的第二次 invocation 的引數恰為 `baseArguments + cookiesArguments + [url]`。
- invocation 次數上限維持 2，兩階段 cookies 判定邏輯不變。
- `fetchVideoInfo`、`fetchPlaylistInfo`、`fetchSubtitles`、`fetchAudioTracks` 的引數 MUST NOT 改動。

**C3 — 下載範本注入 extractor args（`Tubify/Services/YTDLPService.swift`）**

- 新增 `nonisolated private func injectExtractorArgs(into template: String) -> String`。
- 範本以空白切分後若已存在等於 `--extractor-args` 的 token，或存在以 `--extractor-args=` 為前綴的 token，回傳原字串不做修改，並以 info 等級記錄「範本已含 extractor args，略過注入」。
- 否則回傳 `template + " --extractor-args \"" + YTDLPService.youtubePlayerClientArgumentValue + "\""`。
- 在 `download(taskId:url:commandTemplate:outputDirectory:subtitleSelection:audioSelection:onProgress:)` 中，僅於 `audioSelection?.selectedLanguage` 為非 nil 的分支呼叫，且 MUST 在 `hasCookies` 計算與 `removeSafariCookies`／`transformCommand` 之前完成，使不帶 cookies 的第一次與帶 cookies 的重試都帶上該引數。
- `audioSelection?.selectedLanguage` 為 nil 時 MUST NOT 注入；`audioSelection` 為 `AudioSelection(selectedLanguage: nil)` 時同樣 MUST NOT 注入。

**C4 — format 語言限制（`Tubify/Services/YTDLPService.swift`，`injectLanguageIntoFormat`）**

- 先以不位於 `[` 與 `]` 之間的 `,` 將 format 切成多個獨立下載群組；每個群組各自套用以下規則後，再以 `,` 重組。
- 每個群組以不位於 `[` 與 `]` 之間的 `/` 切成 alternatives。
- 每個 alternative 以不位於 `[` 與 `]` 之間的 `+` 切成 parts；在最後一個 part 的結尾附加 `[language=<code>]`，其餘 parts 不變。
- 以 `+` 重組 parts、以 `/` 重組 alternatives、以 `,` 重組群組，回傳結果。
- MUST NOT 在結果尾端附加原始 format 字串，也 MUST NOT 產生任何不含 `[language=<code>]` 的 alternative。

**C5 — 範本缺少 format 參數（`Tubify/Services/YTDLPService.swift`，`injectAudioLanguage`）**

- 既有六個 `-f`／`--format` 樣式皆未匹配時，回傳 `template + " -f \"bv*+ba[language=<code>]/b[language=<code>]\""`。
- 任一樣式匹配成功時行為不變：僅以 C4 的新規則改寫該 format 值。

**C6 — 測試 fixture（`TubifyTests/YTDLPServiceTests.swift`，`makeYTDLPFixture`）**

- fixture script 於既有 `echo "$*" >> "$log"` 之外，比照 `makeMetadataFixture` 以計數檔遞增 invocation 序號，並把該次每個引數逐行寫入 `invocation-$n.args`。
- `YTDLPFixture` 新增 `arguments(at:)` 與 `invocationCount`，簽章與 `MetadataFixture` 的同名成員對齊，序號以 1 為起點。
- 既有以 `invocations.log` 為據的斷言 MUST 維持通過。

**C7 — 驗證責任歸屬**

- C2 由 `TubifyTests/YouTubeMetadataServiceTests.swift` 的 fixture invocation 引數斷言承接（tasks 1.1、1.2），並更新既有 `baseArguments` 常數。
- C3 的「選定語言時注入」「未選定語言時不注入」「範本已含引數時不覆蓋」由 tasks 3.1、3.2、3.3 承接。
- C3 的「第一次 attempt 已帶 extractor args」由 task 3.6 承接：`download` 的第一次 invocation 已移除 cookies 但仍帶 extractor args，即可鑑別「注入晚於 `firstTemplate` 計算」的錯誤實作。注意 3.6 無法鑑別「注入套用在 `removeSafariCookies` 的輸出上」這種同樣正確的寫法，因此 C3 的完整順序約束由 task 5.5 的 code review 承接。
- 帶 cookies 的第二次 invocation 沒有可注入的接縫（`download` 硬編碼 `SafariCookiesService.shared.transformCommand`，其成敗取決於機器是否具備完整磁碟存取）。「兩次 attempt 的範本都帶 extractor args」因此由 task 3.6（第一次 attempt 的 argv）、task 3.8（`removeSafariCookies` 不會移除該引數）與 task 5.5（`transformCommand` 同樣不會移除，由 code review 承接）合併承接。task 3.7 覆蓋的是另一件事：cookies 重試路徑會把 `cookieTemplateProvider` 回傳的範本原樣送進 argv，且含 `,` 的引號值不被 `parseCommandArguments` 破壞。
- C4、C5 由 `TubifyTests/YTDLPServiceTests.swift` 以 `YTDLPService(ytdlpPathProvider:)` 加 fixture 執行檔的 argv 記錄承接（tasks 4.1 至 4.5）。
- D8 所述「不觸發任何重試」由 task 5.4 的 `shouldRetryWithCookies` 斷言與 fixture invocation 次數斷言承接。
- D10 所述 post_live 解析路徑不受引數改動波及，由 task 5.6 承接；判定門檻本身的變化無自動化把關，理由見 Risks。

## Risks / Trade-offs

- **最後一個 `+` part 不是音訊時，選擇器不會匹配。** 例如自訂範本寫成 `ba+bv`，語言限制會落在 `bv` 上。結果是 `Requested format is not available` 的明確失敗，不會靜默交付錯誤語言；接受此取捨。
- **範本使用明確 format id 時可能整串失效。** 例如 `-f 137+140`，附加 `[language=ja]` 後 yt-dlp 可能拒絕該選擇器；且合併 client 後 `140` 會被重新命名為 `140-21`，即使不加語言限制也可能匹配不到。兩者都落在明確失敗，且此類範本本來就無法表達語言選擇。此影響僅在使用者選定語言時發生（依 D3，未選語言時不注入 extractor args）。
- **括號分組語法不在 C4 的切分規則涵蓋範圍。** 例如 `(bv*+ba)/b`，最後一個 part 為 `ba)`，附加後成為 `ba)[language=ja]`，yt-dlp 會拒絕該選擇器。結果為明確失敗，不會靜默交付錯誤語言。
- **範本已含 `--extractor-args` 但未含 web_embedded 時，配音 format 不存在。** 依 C3 不覆蓋使用者設定，結果為明確失敗；訊息是 format 不可用，不會直接說明原因。
- **`Requested format is not available` 不觸發帶 cookies 的重試。** `download` 的第一次嘗試刻意移除 cookies，該訊息不符合 `indicatesLoginRequired` 與 `videoData403Marker` 任一訊號，因此不會進入帶 cookies 的第二次嘗試。這正是 D8 要的行為（避免以其他語言完成下載），代價是「該配音音軌只在帶 cookies 的 session 下可得」這類情境會直接失敗而非降級成功。本變更不新增重試訊號，理由是無法在不重新下載的前提下區分「這次失敗是因為缺 cookies」與「這支影片就是沒有該語言」。
- **缺少 JavaScript runtime 時配音 format 會從清單消失。** 實測 yt-dlp 印出 `n challenge solving failed` 的 WARNING 後繼續。本變更把該情境從「靜默交付原聲」改為「明確失敗」，但錯誤訊息不會指出需要安裝 deno 或 node，使用者需自行從 stderr 的 WARNING 判讀。此為已知殘餘風險。
- **client 別名若在未來 yt-dlp 版本中消失，偵測會退回現況而非報錯。** 實測不支援的 client 名稱只產生 `WARNING: [youtube] Skipping unsupported client "..."` 並以 exit code 0 繼續。屆時的表現是音軌區塊再度不出現，與修復前相同，不會造成下載失敗。
- **post_live 第二段判定看到的 format 集合變大。** `fetchMediaOptions` 的 formats 是 `hasUsableMediaFormats` 在 `DownloadManager.swift:474` 與 `:660` 的輸入，合併 client 後只可能讓判定更容易為 true，因此原本會被標記 `.postLive` 的任務有可能改為排入下載；該任務若沒有音軌選擇，依 D3 下載端不注入 extractor args，可能因 format 不可得而失敗。第一段判定（`fetchVideoInfo`）依 D10 維持 default client，兩段判定因此不對稱。task 5.6 把關的是 1.4 的引數改動未波及 `fetchMediaOptions` 的解析路徑（`MetadataFixture` 的 stdout 由 `call-$n.stdout` 決定、不隨 argv 改變，因此它在結構上無法觀察門檻的實際翻轉）；判定門檻本身的變化是本變更刻意接受的行為改變，無自動化把關。
- **非 YouTube 任務同樣會被注入。** 媒體選項查詢對所有 URL 執行，選定語言時的下載注入亦不分站台。extractor args 對其他 extractor 惰性（已實測），但 C4 移除 fallback 的效果對非 YouTube 任務同樣生效：原本「語言錯但下載成功」會變成明確失敗。這與本變更的目標一致，由 task 5.8 的非 YouTube 手動驗證把關下載本身不迴歸。
- **偵測查詢多取一組 client 的資料，延遲增加。** 合併查詢仍在同一個 yt-dlp process 內完成，未增加 invocation 次數；`fetchMediaOptions` 的 2 次上限不變。播放清單展開後會對每支影片各執行一次該查詢，累積請求量隨清單長度成長。
