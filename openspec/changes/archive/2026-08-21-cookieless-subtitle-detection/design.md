## Context

`YouTubeMetadataService.fetchMediaOptions(url:cookiesArguments:)` 目前把呼叫端傳入的 cookies 參數直接串進 yt-dlp 引數：`["-J", "--skip-download", "--no-playlist"] + cookiesArguments + [url]`。

三個呼叫端都位於 `Tubify/ViewModels/DownloadManager.swift`，且都以 `getCookiesArguments()` 取得參數：

- 單一影片路徑 `fetchMetadataForTask`，決定是否進入 `.waitingForMediaSelection`
- 播放清單路徑，逐一填入 `task.availableSubtitles` 後合併出媒體選擇請求
- `post_live` 影片重新查詢可用 formats 的分支

`getCookiesArguments()` 只有在下載指令樣板含 `--cookies-from-browser safari`（目前的預設值就含有）且 Safari cookies 匯出成功時才回傳非空陣列。

實測（同一支影片、同一時間點連續多輪，結果穩定）：

| 查詢方式 | yt-dlp client | `subtitles` | audio-only 且有 `language` 的格式 |
| --- | --- | --- | --- |
| 不帶 cookies | `android vr` | `['zh']` | 4 個，語言集合 `{zh-Hant}` |
| 帶 cookies | `tv downgraded`（記錄 `Found YouTube account cookies`） | 空 | 0 個 |

`parseSubtitles` 只讀 JSON 的 `subtitles`、刻意不讀 `automatic_captions`，因此帶 cookies 時字幕軌完全消失。`parseAudioTracks` 只採計「純音訊且有 `language` 標記」的格式，在這支樣本上不帶 cookies 同樣不劣於帶 cookies。

下載路徑已有相近形狀的既有策略，但其 cookies fallback 的 gate 是 `YTDLPService.shouldRetryWithCookies(_:)`，由兩個訊號組成：`indicatesLoginRequired(_:)` 與 `isDownloadVideoData403(_:)`（見 `Tubify/Services/YTDLPService.swift`）。`openspec/specs/download-reliability/spec.md` 的 cookies contract 即以 `shouldRetryWithCookies` 表述。本變更只重用其中的 `indicatesLoginRequired` 訊號清單，不納入 video-data 403 訊號。

metadata 路徑的錯誤型別是 `MetadataError.fetchFailed(String)`，而 `indicatesLoginRequired` 目前只接受 `YTDLPError`，兩者無法共用同一個入口。

`YouTubeMetadataService` 是 `actor`，以 `static let shared` 搭配 `private init()` 建立，內部有 5 處以 `await YTDLPService.shared.findYTDLPPath()` 取得執行檔路徑，沒有可供測試替換的接縫。`YTDLPService` 則已有 `init(ytdlpPathProvider:)`，`TubifyTests/YTDLPServiceTests.swift` 以 fixture 執行檔搭配該接縫驗證 invocation 參數。`YouTubeMetadataServiceProtocol` 雖可在 `DownloadManager` 層被 mock 取代，但它替換的是整個 service，無法觀察 `fetchMediaOptions` 內部送出的 yt-dlp 引數。

## Goals / Non-Goals

Goals：

- 讓公開影片在 Safari cookies 匯出成功時，仍能偵測到使用者上傳的字幕軌並顯示媒體選擇視窗。
- 需登入的影片（私人、會員限定、bot 驗證）仍能取得媒體選項。
- metadata 路徑的「需登入」判定重用下載路徑既有的登入訊號清單，不自建第二份定義。
- 兩階段行為有可被自動測試觀察的接縫。

Non-Goals：

- 不改 `fetchVideoInfo`、`fetchPlaylistInfo` 的 cookies 行為。同檔的 `fetchSubtitles(url:cookiesArguments:)` 與 `fetchAudioTracks(url:cookiesArguments:)` 目前在 `Tubify/` 與 `TubifyTests/` 皆無呼叫端，本變更只把它們的路徑解析改為經由共用入口（D3），不改其 cookies 行為；兩階段策略的實作範圍限定於 `fetchMediaOptions`。
- 不改下載指令的 cookies 策略與 `download-reliability` 既有 contract。
- 不改 `parseSubtitles` 排除 `automatic_captions` 的既有決定。
- 不改媒體選擇視窗的 UI 與預設選取行為。
- 不新增使用者可見設定。

## Decisions

**D1：兩階段策略實作在 `fetchMediaOptions` 內部，而非三個呼叫端。**
呼叫端維持傳入 `cookiesArguments` 不變，語意從「請帶上這些 cookies」轉為「需要時可用的 cookies」。這樣三個呼叫端與未來新增的呼叫端自動獲得一致行為，也避免在呼叫端各自複製重試邏輯。

**D2：登入錯誤分類維持單一事實來源，且刻意不納入 video-data 403 訊號。**
新增接受錯誤訊息字串的 `YTDLPService.indicatesLoginRequired(message:)`，既有的 `indicatesLoginRequired(_ error: YTDLPError)` 改為抽出 `executionFailed` 的訊息後委派給它，訊號清單只保留一份。`fetchMediaOptions` 以 `MetadataError.fetchFailed` 帶出的 stderr 訊息呼叫字串版本。

不重用完整的 `shouldRetryWithCookies`：其另一半 `isDownloadVideoData403` 匹配的是下載 video data 時的 403，而媒體選項查詢帶 `--skip-download`、根本不下載 video data，該訊號在此路徑不適用。因此 metadata 路徑與下載路徑共用的是「登入訊號清單」，不是「整體重試決策」。

**D3：以可注入的路徑提供者作為測試接縫，涵蓋 actor 內全部路徑解析點。**
`YouTubeMetadataService` 新增 `init(ytdlpPathProvider:)`（預設 `nil`，`shared` 維持既有行為），並把 actor 內 5 處 `await YTDLPService.shared.findYTDLPPath()` 統一改為呼叫同一個私有解析方法：provider 非 nil 時使用 provider，否則沿用 `YTDLPService.shared.findYTDLPPath()`。統一涵蓋是為了避免留下半套接縫；這只改變路徑來源，不改變任何方法的 cookies 行為，因此不牴觸 Non-Goals。

**D4：最多重試一次，且僅在有 cookies 可用時重試。**
`cookiesArguments` 為空時不重試，直接把第一次的錯誤拋出。非登入類錯誤（網路、影片不存在、yt-dlp 執行失敗）也不重試，避免把單純失敗變成兩倍等待。

**D5：第一次成功就回傳，不做第二次呼叫、不合併兩份 JSON；重試條件只看 exit code，不看內容是否豐富。**
不比較帶與不帶 cookies 的字幕集合，避免定義衝突取捨規則。也刻意不把「exit 0 但解析結果為空」納入重試條件：空結果與「這支影片本來就沒有字幕、沒有多音軌」在 JSON 上無法區分，若以空結果觸發重試，所有真的沒有字幕的影片都會固定多付一次 yt-dlp 呼叫。此決定的殘餘風險記於 Risks。

**D6：契約以「是否帶 cookies」表述，不寫入特定 client 名稱。**
`android vr` 與 `tv downgraded` 是本次觀察到的 yt-dlp 上游行為，屬於證據而非契約。spec 的 scenario 以 invocation 是否含 cookies 參數、以及是否回傳字幕軌來描述，避免上游改版時 spec 立刻失效。

## Implementation Contract

1. `YouTubeMetadataService.fetchMediaOptions(url:cookiesArguments:)` 的第一次 yt-dlp invocation 的引數 MUST 恰為 `["-J", "--skip-download", "--no-playlist", url]`，即 MUST NOT 包含 `cookiesArguments` 的任何元素，且 MUST 保留既有的三個旗標與目標 url。
2. 第一次 invocation 以 exit code 0 結束時，`fetchMediaOptions` MUST 回傳其解析結果，且 MUST NOT 啟動第二次 invocation；解析結果是否為空 MUST NOT 影響此判定。
3. 第一次 invocation 以非 0 exit code 結束時，實作 MUST 以其 stderr 訊息呼叫 `YTDLPService.indicatesLoginRequired(message:)`。
4. 當第 3 點判定為 `true` 且 `cookiesArguments` 非空時，實作 MUST 執行第二次 invocation，其引數 MUST 恰為 `["-J", "--skip-download", "--no-playlist"] + cookiesArguments + [url]`，即第一次的引數加上 `cookiesArguments`——`--skip-download` 在重試路徑同樣不可省略，它既是既有註解所述「避免 yt-dlp 驗證下載格式導致 403」的必要旗標，也是 D2 主張 video-data 403 訊號不適用於本路徑的前提；第二次 invocation 的結果即為 `fetchMediaOptions` 的結果，包含第二次亦失敗時 MUST 拋出以第二次 stderr 訊息建構的 `MetadataError.fetchFailed`。
5. 當第 3 點判定為 `false`，或 `cookiesArguments` 為空時，實作 MUST NOT 執行第二次 invocation，並 MUST 拋出以第一次 stderr 訊息建構的 `MetadataError.fetchFailed`。
6. 重試次數上限為 1：整個 `fetchMediaOptions` 呼叫中 yt-dlp invocation 次數 MUST NOT 超過 2。
7. 與 exit code 無關的失敗出口 MUST NOT 觸發重試：找不到 yt-dlp 執行檔時 MUST 直接拋出既有的 `MetadataError.ytdlpNotFound`；`process.run()` 拋錯時 MUST 直接拋出既有的 `MetadataError.fetchFailed`。stderr 無法以 UTF-8 解碼時，分類輸入 MUST 為既有的 `"未知錯誤"` fallback 字串；stderr 為空時，分類輸入 MUST 為空字串——既有的 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"` 只在解碼失敗回傳 `nil` 時套用 fallback，空 `Data` 會解碼成空字串而非 `nil`。兩種情形的分類結果同為非登入錯誤，皆 MUST NOT 觸發重試；本變更 MUST NOT 改變此既有的訊息建構方式。
8. `YTDLPService.indicatesLoginRequired(message:)` 為新的公開入口，其訊號比對邏輯 MUST 與變更前 `indicatesLoginRequired(_ error: YTDLPError)` 的行為一致；後者 MUST 改為委派給前者，且 MUST 維持「非 `executionFailed` 的錯誤回傳 `false`」的既有行為。`shouldRetryWithCookies(_:)` 的組成與行為 MUST NOT 改變。
9. `YouTubeMetadataService` MUST 提供 `init(ytdlpPathProvider:)`，且 actor 內全部 5 處 yt-dlp 路徑解析 MUST 經由同一個解析入口；provider 為 `nil` 時該入口 MUST 沿用 `YTDLPService.shared.findYTDLPPath()`，使 `shared` 的行為與變更前相同。
10. `DownloadManager` 的三個 `fetchMediaOptions` 呼叫端 MUST NOT 因本變更調整傳入的 `cookiesArguments`。
11. `parseSubtitles` 只採用 JSON `subtitles` 欄位、排除 `automatic_captions` 的既有行為，以及 `parseAudioTracks`、`parseFormats`、`hasUsableMediaFormats` 的判定邏輯 MUST NOT 改變。

驗證責任歸屬：

- 第 1、2、4、5、6 點由 `TubifyTests/YouTubeMetadataServiceTests.swift` 以 fixture 執行檔的 invocation 記錄驗證（含引數完整相等比對、invocation 次數、兩次皆失敗時的訊息來源）。
- 第 3 點（`fetchMediaOptions` MUST 呼叫該入口）由 tasks 3.4／3.6 的行為測試觀察：登入訊號訊息會重試、非登入訊號訊息不會，兩者共同證明分類確實依該入口的判定運作。
- 第 8 點由針對 `indicatesLoginRequired(message:)` 的單元測試驗證，並保留既有 `shouldRetryWithCookies` 的行為測試作為迴歸。
- delta spec「媒體選項查詢重用下載路徑的登入訊號定義」requirement 中「MUST NOT 另行維護第二份訊號清單」的部分無法由行為測試觀察——在 `fetchMediaOptions` 內複製一份訊號清單同樣會讓所有行為測試通過——因此改由 tasks 第 4 節的 code review 任務逐字檢查承接。
- 第 7 點由 fixture 佈置「exit code 非 0 且 stderr 為空」的情境驗證不重試且分類輸入為空字串；`ytdlpNotFound` 與 `process.run()` 失敗屬既有行為，由 tasks 4.2 的 diff 檢查承接。
- 第 9 點由 provider 指向 fixture 執行檔時 `fetchMediaOptions` 確實呼叫該 fixture、以及 provider 指向不存在路徑時拋出 `MetadataError` 的行為式測試驗證，不以「預設實例與 `shared` 互比」這種恆真斷言為據。
- 第 10、11 點由 code review 對照 diff 驗證，對應 tasks 中的獨立檢查任務。
- Risks 的「`shared` 之外的新初始化入口」由 tasks 4.8 的 code review 承接：確認 `Tubify/` 內未新增 `YouTubeMetadataService(` 直接建構，`init(ytdlpPathProvider:)` 僅在 `TubifyTests/` 使用。
- `post_live` 分支的迴歸由兩部分承接：`fetchMediaOptions` 改寫後仍正確回傳 `liveStatus`、`releaseTimestamp` 與 `formats`，且 `hasUsableMediaFormats` 對同一組 formats 的判定不變，由 `TubifyTests/YouTubeMetadataServiceTests.swift` 以 provider 接縫搭配 fixture JSON 驗證；`handlePostLiveFormatLookupError` 的輸入變更則由 tasks 4.4 承接：本變更使其輸入在非登入類失敗時改為不帶 cookies 的第一次 stderr、在兩次皆失敗時改為第二次 stderr，因此該任務以 fixture 斷言 cookieless 訊息仍能被 `YTDLPErrorClassification.classify` 判為 `.endedLive`，再以 code review 確認該函式的分支邏輯未被改動；不以 `DownloadManager` 層測試為據，因為該函式是 private func，而既有唯一接縫 `YouTubeMetadataServiceProtocol` mock 會取代整個 service、繞過兩階段邏輯。
- 端到端中「真實 yt-dlp 在帶／不帶 cookies 下的字幕回傳差異」沒有自動化接縫，指定為手動驗證任務。至於「`filteredSubtitles` 非空即進入 `.waitingForMediaSelection` 並觸發 `onMediaSelectionNeeded`」屬既有行為，已有 `DownloadManager` 的既有測試接縫（`YouTubeMetadataServiceProtocol` mock）覆蓋，本變更不改動該段。

## Risks / Trade-offs

- **本變更新增的風險：登入訊號清單漏判會把成功變成失敗。** metadata 路徑原本一律帶 cookies，改為 cookieless 優先後，任何不在既有訊號清單內的需登入錯誤訊息會在第一次失敗後不重試，導致媒體選項查詢失敗（單一影片路徑落入標題顯示「無法獲取標題」，播放清單路徑落入 `handlePostLiveFormatLookupError`）。這不是與下載路徑等價的既有風險——下載路徑的基線本來就是 cookieless。緩解方式是重用既有清單而非另寫一份，並在實作時以私人、會員限定、年齡限制、bot 驗證各一則真實訊息確認分類命中。
- **下載階段的 cookies fallback 可能讓已選字幕靜默缺席。** 選單是以 cookieless 結果建立的，但下載若因登入錯誤或 video-data 403 fallback 到帶 cookies 的 template，該 client 可能沒有使用者選的字幕語言，yt-dlp 對 `--sub-lang` 找不到的語言只會 warning 不會失敗，結果是影片下載成功但沒有字幕檔。這是同一根因的另一半，本變更依 Non-Goals 不處理下載端策略。手動驗證任務的驗收點**無法**觀察這個失敗模式：yt-dlp 先寫字幕、後抓 video data，因此 cookieless 的第一次嘗試會在 video-data 403 發生前就把字幕檔寫到磁碟上，帶 cookies 的重試即使完全取不到該語言的字幕，輸出目錄仍會有字幕檔而使驗收通過。這個失敗模式的可觀察訊號是日誌中的 `missing subtitles languages` 警告，而非字幕檔是否存在；tasks 4.7 因此要求一併註明該警告是否出現，但不以它作為驗收判準（它落在本變更的 Non-Goals 內）。
- **播放清單的成本是 2N 而非 +1。** 播放清單展開後是逐支影片循序呼叫 `fetchMediaOptions`；若整份清單都需登入（例如會員頻道），invocation 次數從 N 變成 2N 且為循序，使用者會在選集確認後感受到明顯停滯。本變更接受此取捨，不做「同清單內第一支已判定需登入就直接帶 cookies」的最佳化，以免引入跨影片的隱含狀態。
- **降級成功不重試（D5 的殘餘風險）。** yt-dlp 可能以 exit 0 回傳內容殘缺的 JSON；此時不會重試，原本帶 cookies 可取得的資料就此遺失且無錯誤訊息。接受此取捨的理由見 D5。
- **音軌證據僅一個樣本。** 表中的音軌比較只涵蓋一支單語音軌影片（cookieless 1 種語言、cookies 0 種，兩者都不會觸發多音軌選單）。多語音軌影片在兩種 client 下的差異未實測，若 cookieless client 的 `formats` 缺少 `language` 標記，多音軌選單可能不再出現。spec 因此只對字幕軌作出保證，音軌僅要求既有解析邏輯不被改動（Contract 第 11 點）。
- **`post_live` 與 `is_upcoming` 判定的查詢不對稱。** `fetchVideoInfo` 仍帶 cookies、`fetchMediaOptions` 改為 cookieless，因此 post_live 分支變成「帶 cookies 的初查說沒有可用 formats，再以不帶 cookies 重查一次」。兩次查詢已非同一個 client，受影響的不只 `formats` 與 `hasUsableMediaFormats`：播放清單路徑的 `is_upcoming` → `.scheduled` 判定同樣只依賴 `fetchMediaOptions` 回傳的 `liveStatus` 與 `releaseTimestamp`（單一影片路徑走 `fetchVideoInfo` 提早 return，不受影響）。若 cookieless client 對尚未首播的影片改以錯誤回應而非回傳 `live_status: is_upcoming`，播放清單中的首播影片會落入 `handlePostLiveFormatLookupError` 而被標為 `.failed` 並發出失敗通知，而非 `.scheduled`。本變更接受此取捨，並以 tasks 4.3 的 fixture 同時涵蓋 `post_live` 與 `is_upcoming` 兩組欄位作為解析層的迴歸落點。
- **依賴 yt-dlp 上游行為。** 字幕是否出現在 JSON 取決於 yt-dlp 依 cookies 選擇的 client，屬上游實作。以 D6 的表述方式降低 spec 對上游細節的耦合；若上游未來讓帶 cookies 的 client 也回傳字幕，本變更會變成多餘而非有害。
- **`shared` 之外的新初始化入口。** `init(ytdlpPathProvider:)` 讓 `YouTubeMetadataService` 不再只能透過 `shared` 建立。限制在測試使用，正式程式碼維持使用 `shared`，由 tasks 4.8 的 code review 把關。
