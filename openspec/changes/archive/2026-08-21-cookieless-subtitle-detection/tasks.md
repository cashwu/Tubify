## 1. 登入分類的單一入口

- [x] 1.1 在 `TubifyTests/YTDLPServiceTests.swift` 新增 `YTDLPService.indicatesLoginRequired(message:)` 的測試：既有訊號清單中的代表性訊息（私人影片、會員限定、年齡限制、bot 驗證各至少一則真實 yt-dlp 訊息）判定為 `true`，一般失敗訊息（網路逾時、影片不存在）與 `未知錯誤` fallback 字串判定為 `false`；測試須先失敗（尚未有該入口）
- [x] 1.2 在 `Tubify/Services/YTDLPService.swift` 新增 `static func indicatesLoginRequired(message: String) -> Bool`，把既有訊號清單移入其中，並讓 `indicatesLoginRequired(_ error: YTDLPError)` 抽出 `executionFailed` 的訊息後委派給它；非 `executionFailed` 的錯誤維持回傳 `false`
- [x] 1.3 執行 `TubifyTests/YTDLPServiceTests.swift` 既有的 `shouldRetryWithCookies` 測試，確認委派後行為未變，且 `shouldRetryWithCookies` 的組成未被改動（對應 Implementation Contract 第 8 點；delta spec「媒體選項查詢重用下載路徑的登入訊號定義」requirement 本身由 3.4／3.6 與 4.5 承接，本項只承接其「訊號清單只有一份」的實作前提）

## 2. 媒體選項查詢的可測接縫

- [x] 2.1 在 `TubifyTests/YouTubeMetadataServiceTests.swift` 新增行為式測試：以 `YouTubeMetadataService(ytdlpPathProvider:)` 指向 fixture 執行檔呼叫 `fetchMediaOptions`，斷言 fixture 的 invocation 記錄確實產生；另以 provider 指向不存在的路徑，斷言拋出 `MetadataError`。不得以「預設實例與 `shared` 互比」作為驗證（對應 Implementation Contract 第 9 點）；測試須先失敗
- [x] 2.2 在 `Tubify/Services/YouTubeMetadataService.swift` 新增 `init(ytdlpPathProvider:)`（預設 `nil`）與對應的私有屬性，並新增單一私有路徑解析方法：provider 非 `nil` 時使用 provider，否則沿用 `YTDLPService.shared.findYTDLPPath()`；把 actor 內 5 處 `await YTDLPService.shared.findYTDLPPath()`（`Tubify/Services/YouTubeMetadataService.swift` 第 212、293、463、559、673 行附近）全部改為呼叫該方法；`static let shared` 維持不變

## 3. 兩階段 cookies 策略

- [x] 3.1 在 `TubifyTests/YouTubeMetadataServiceTests.swift` 建立可記錄 invocation 引數的 yt-dlp fixture 執行檔輔助方法，fixture 須能依序對第 1 次與第 2 次呼叫分別指定 exit code、stdout 與 stderr，並保留每次呼叫的完整引數供斷言
- [x] 3.2 新增測試：呼叫端提供非空 cookies 參數時，第一次 invocation 的引數完整相等於 `["-J", "--skip-download", "--no-playlist", url]`（對應 Implementation Contract 第 1 點）；測試須先失敗
- [x] 3.3 新增測試：第一次 invocation 以 exit code 0 結束時回傳其解析結果且只發生 1 次 invocation，並額外佈置一組「exit 0 但 `subtitles` 與 `formats` 皆為空」的 JSON，確認同樣不重試（對應 Implementation Contract 第 2 點）
- [x] 3.4 新增測試：第一次 invocation 失敗且 stderr 屬於需登入訊號、cookies 參數非空時，發生第二次 invocation 且其引數完整相等於 `["-J", "--skip-download", "--no-playlist"] + cookiesArguments + [url]`，並以第二次結果為準（對應 Implementation Contract 第 3、4 點）
- [x] 3.5 新增測試：兩次 invocation 皆失敗時，拋出的 `MetadataError.fetchFailed` 訊息為第二次的 stderr 而非第一次，且 invocation 次數為 2（對應 Implementation Contract 第 4、6 點）
- [x] 3.6 新增測試：第一次 invocation 失敗但 stderr 不屬於需登入訊號時，不發生第二次 invocation，且拋出以第一次 stderr 訊息建構的 `MetadataError.fetchFailed`；訊息集合 MUST 包含一則 `unable to download video data: HTTP Error 403: Forbidden` 樣本，直接對應 delta spec 的「video-data 403 不使媒體選項查詢重試」scenario（對應 Implementation Contract 第 3、5 點）
- [x] 3.7 新增測試：cookies 參數為空且第一次失敗訊息屬於需登入訊號時，不發生第二次 invocation（對應 Implementation Contract 第 5 點）
- [x] 3.8 新增測試：第一次 invocation 以非 0 exit code 結束但 stderr 為空時，不發生第二次 invocation，且拋出的 `MetadataError.fetchFailed` 訊息為空字串（既有 `String(data:encoding:) ?? "未知錯誤"` 對空 `Data` 解碼成空字串、fallback 不生效，本變更不改此行為）（對應 Implementation Contract 第 7 點）
- [x] 3.9 在 `Tubify/Services/YouTubeMetadataService.swift` 改寫 `fetchMediaOptions(url:cookiesArguments:)`：抽出單次 invocation 的執行與解析，第一次一律不帶 cookies；非 0 exit code 時以 stderr 訊息呼叫 `YTDLPService.indicatesLoginRequired(message:)`，判定為需登入且 cookies 參數非空才帶 cookies 重試一次；其餘情況直接拋出第一次的錯誤；`ytdlpNotFound` 與 `process.run()` 失敗維持既有直接拋出的行為（對應 Implementation Contract 第 7 點）
- [x] 3.10 執行第 3.2 至 3.8 的測試，確認全部通過

## 4. 範圍與回歸檢查

- [x] 4.1 [P] 對照 diff 確認 `Tubify/ViewModels/DownloadManager.swift` 的三個 `fetchMediaOptions` 呼叫端（單一影片、播放清單、`post_live` 分支）傳入的 `cookiesArguments` 未被本變更調整（對應 Implementation Contract 第 10 點）
- [x] 4.2 [P] 對照 diff 確認 `parseSubtitles`、`parseAudioTracks`、`parseFormats`、`hasUsableMediaFormats` 的判定邏輯未被改動（對應 Implementation Contract 第 11 點），並確認 `MetadataError.ytdlpNotFound` 與 `process.run()` 失敗兩條 catch 分支維持既有的直接拋出行為、未被納入重試（對應 Implementation Contract 第 7 點）
- [x] 4.3 `post_live` 迴歸檢查（測試落點限定在 `TubifyTests/YouTubeMetadataServiceTests.swift`，不新增 `TubifyTests/DownloadManagerTests.swift` 的案例）：以 provider 接縫搭配 `live_status` 為 `post_live` 的 fixture JSON 呼叫改寫後的 `fetchMediaOptions`，斷言 `liveStatus`、`releaseTimestamp` 與 `formats` 仍正確回傳，且 `YTDLPFormat.hasUsableMediaFormats` 對該組 formats 的判定與既有測試一致；另佈置一組 `live_status` 為 `is_upcoming` 且含 `release_timestamp` 的 fixture JSON，斷言兩者同樣正確回傳，作為播放清單 `.scheduled` 判定的解析層迴歸落點
- [x] 4.4 `handlePostLiveFormatLookupError` 輸入變更的迴歸檢查：本變更改變其輸入的情形有兩種——非登入類失敗時改以不帶 cookies 的第一次 stderr 為準（Contract 第 5 點），兩次皆失敗時改以帶 cookies 的第二次 stderr 為準（Contract 第 4 點，已由 3.5 驗證）。針對第一種情形，在 `TubifyTests/YouTubeMetadataServiceTests.swift` 以 fixture 佈置 stderr 含 `This live event has ended.` 的 cookieless 失敗，斷言 `fetchMediaOptions` 拋出的訊息仍能被 `YTDLPErrorClassification.classify` 判為 `.endedLive`；再以 code review 對照 diff 確認 `Tubify/ViewModels/DownloadManager.swift` 的 `handlePostLiveFormatLookupError` 分支邏輯未被改動，使 `openspec/specs/youtube-post-live-replay/spec.md` 的 ended-live 與 non-ended-live 兩條既有 scenario 仍成立
- [x] 4.5 code review：逐字檢查 `Tubify/Services/YouTubeMetadataService.swift` 內沒有第二份登入訊號字串清單，且需登入判定一律經由 `YTDLPService.indicatesLoginRequired(message:)`（承接 delta spec「媒體選項查詢重用下載路徑的登入訊號定義」requirement 中無法由行為測試觀察的部分）
- [x] 4.6 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，確認既有測試無回歸
- [x] 4.7 手動驗證：在 Safari cookies 可成功匯出（完整磁碟存取權限已授權）的環境下，加入一支含使用者上傳字幕的公開 YouTube 影片；驗收點一為媒體選擇視窗出現且列出該字幕語言；接著保留該語言的勾選並確認送出。驗收點二限定在本變更可控制的範圍，並逐項對照 `~/Library/Logs/Tubify/` 當日日誌中該 TaskID 的記錄：(a) 該任務的**第一次** `執行命令` 不含任何 cookies 引數，且含 `--write-sub` 與該語言碼；(b) 該次 invocation 的進度輸出顯示字幕確實下載完成；(c) 輸出目錄中該語言的字幕檔 mtime 落在該次 invocation 期間，以排除既有殘留檔造成的偽通過。下載端若因 video-data 403 fallback 到帶 cookies 的 template 並出現 `missing subtitles languages` 警告，屬 design Risks 已記載、本變更 Non-Goals 範圍外的失敗模式，不作為本驗收點的判準，但 SHALL 在驗證記錄中一併註明是否出現
- [x] 4.8 code review：對照 diff 確認 `Tubify/` 內未新增 `YouTubeMetadataService(` 的直接建構，正式程式碼一律經由 `YouTubeMetadataService.shared`，`init(ytdlpPathProvider:)` 僅在 `TubifyTests/` 使用（承接 design Risks「`shared` 之外的新初始化入口」指派給 code review 的把關責任）
