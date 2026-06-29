## Context

Tubify 以 yt-dlp 作為下載後端，而 yt-dlp 原生支援上千個網站。但 `DownloadManager.addURL` 目前以 `isValidYouTubeURL()` 作為硬性關卡，只放行 YouTube 網址，使其他網站完全無法下載。

下載執行的單一接縫位於 `DownloadManager.downloadSingleTask`，它讀取全域的 `downloadCommand` 設定並交給 `YTDLPService.download`。`downloadCommand` 預設值為 YouTube 最佳化指令（`bv[ext=mp4][vcodec^=avc]+ba[ext=m4a]/b[ext=mp4][vcodec^=avc]` 搭配 `--cookies-from-browser safari`），此格式選擇器對非 YouTube 網站常常對不上而導致下載失敗。

metadata 取得（`YouTubeMetadataService`）與進度解析（`YTDLPService`）本身與網站無關，解析的是 yt-dlp 通用 JSON 輸出，因此不需修改即可運作於其他網站。但 `addURL` 內既有的 YouTube 專屬分支並非全部優雅降級：`extractVideoIdSync` 的 `[\w-]{11}` 樣式會誤命中 Instagram 等 11 碼路徑片段而產生錯誤的 `i.ytimg.com` 縮圖，`isPlaylistSync` 的 `list=`／`/playlist` 比對也會對恰含這些 token 的非 YouTube 網址誤判——因此本變更需為這些分支加上 site gate（見下方決策）。

## Goals / Non-Goals

**Goals:**

- 開放下載 yt-dlp 支援的任何網站，YouTube 路徑行為維持「一個位元組都不變」的零回退。
- 非 YouTube 網址自動套用較通用的格式選擇器，達到開箱即用，使用者無須手動編輯指令。
- 將改動面積壓到最小，集中在入口驗證、下載指令選擇、既有 YouTube 專屬分支閘控，以及連帶的 `notYouTubeURL` 移除、`ContentView` fallback 清理與 `EmptyStateView` 文案中性化。

**Non-Goals:**

- 不修改現有 `downloadCommand` 預設值，也不在設定頁新增可編輯的通用指令欄位（通用指令採固定常數）。
- 不重寫 metadata 取得、進度解析、`YouTubeMetadataService` 既有解析邏輯；本變更僅為既有的 YouTube 專屬分支（playlist 偵測、混合 URL 提示、ytimg 縮圖預取）新增 site gate，使其只作用於 YouTube 網址，不改寫其內部流程。
- 不針對特定網站（x.com／Instagram）做客製化的 cookies 或格式特例處理；僅提供單一通用指令。
- 不重新命名 app 品牌或 `$youtubeUrl` 佔位符（避免不必要的 churn）。

## Decisions

### 依網址分流下載指令

在 `downloadSingleTask` 取得下載指令模板時，依任務網址在「YouTube 指令」與「通用指令」之間選擇，而非沿用單一全域指令。理由：可讓 YouTube 路徑完全不動（零回退風險），同時讓非 YouTube 網站套用合適的通用指令。新增一個小型 helper（例如 `effectiveDownloadCommand(for:)`）封裝此選擇，僅 `downloadSingleTask` 的下載指令組裝透過它取得模板。cookies 參數判斷（`getCookiesArguments`，僅由 metadata 路徑呼叫）維持讀取全域 `downloadCommand`，不納入路由——因 `downloadCommand` 與 `genericDownloadCommand` 皆含相同的 `--cookies-from-browser safari`，分流對 cookies 決策無實質影響，且可避免改動 metadata 流程。替代方案：放寬單一預設指令讓所有網站共用——已否決，因為會改動 YouTube 既有的編碼挑選行為，帶來回退風險。

### isValidYouTubeURL 轉為路由器角色

保留既有的 `isValidYouTubeURL()` 判斷邏輯，但用途從「入口拒絕關卡」改為「指令分流的判斷依據」。理由：判斷規則本身正確且已驗證，重用它可避免新增重複的網址判斷邏輯。替代方案：新增獨立的 YouTube 偵測函式——已否決，屬重複邏輯。

### YouTube 專屬處理一併納入路由

除了下載指令，`addURL` 內既有的 YouTube 專屬分支也以同一個 `isValidYouTubeURL()` 判斷加以收斂，使其只作用於 YouTube 網址：playlist 偵測／展開（`isPlaylistSync`）、混合影片＋清單網址的「下載單支或整個清單」提示，以及由 `extractVideoIdSync` 推導的 `i.ytimg.com` 縮圖預取。理由：這些分支對非 YouTube 網址會誤判——`isPlaylistSync` 只比對 `list=`／`/playlist`，非 YouTube 網址若恰含 `list=` 會誤入清單展開或誤觸提示；`extractVideoIdSync` 的 `[\w-]{11}` 樣式會誤命中 Instagram 等 11 碼路徑片段而產生錯誤的 ytimg 縮圖。將它們閘控於 YouTube 網址，可確保非 YouTube 網址一律走單一任務路徑、由 yt-dlp 自行處理清單，並交由 metadata 補上真實縮圖。替代方案：信任原註記的「優雅降級」不動這些分支——已否決，經檢視確認會對非 YouTube 網址產生實際誤判。

### 通用指令採用固定常數

新增 `AppSettingsDefaults.genericDownloadCommand` 作為程式內固定常數。它是一條完整的 yt-dlp 指令字串，結構對齊內建預設 `AppSettingsDefaults.downloadCommand`（含 `yt-dlp`、`--cookies-from-browser safari` 與 `"$youtubeUrl"` 佔位符），僅 `-f` 格式選擇器改為通用值（如 `bv*+ba/b`）；`commandTemplate` 由 `YTDLPService` 整條解析執行，故不可只存格式選擇器。因 `genericDownloadCommand` 為固定常數，它對齊的是預設值而非使用者改過的 YouTube 指令，不隨使用者設定變動。此常數不寫入 `UserDefaults`、不在設定頁顯示、不可由使用者編輯。理由：把改動面積與 UI 複雜度壓到最小；待未來確有需求再升級為可編輯。替代方案：在設定頁新增第二個可編輯指令欄位——已否決，現階段過度設計。

### 放寬入口驗證並移除 notYouTubeURL

`DownloadManager.addURL` 移除 `isValidYouTubeURL()` 拒絕分支，改以 `isValidURLFormat()`（http/https 格式檢查）作為唯一入口驗證；連帶移除 `URLValidationResult.notYouTubeURL` case 及 `ContentView` 對應的「僅支援 YouTube 網址」錯誤訊息，並移除 `ContentView.processTextInput` 中現已多餘的 `youtube.com`／`youtu.be` 文字比對 fallback（任何 `http://`／`https://` 開頭的文字本就會交給 `addURL`，此 fallback 僅對無 http 前綴的文字生效，開放多網站後不再需要）。理由：`addURL` 的 `isValidYouTubeURL()` 關卡是唯一阻擋其他網站的限制，移除後任何有效網址都能進入佇列。

### UI 文案中性化

將使用者可見的 YouTube 字眼（如 `EmptyStateView` 的「拖放或貼上 YouTube 連結」）改為通用影片用語，使名實相符。理由：開放多網站後，YouTube 專屬文案會誤導使用者。

## Implementation Contract

**Behavior:**

- 使用者貼上或拖放任何 http/https 格式正確的網址時，該網址都能加入下載佇列，不再因「非 YouTube」被拒絕。
- 下載 YouTube 網址時，實際傳給 yt-dlp 的指令模板與本變更前完全相同（沿用 `downloadCommand`）。
- 下載非 YouTube 網址時，使用 `genericDownloadCommand` 通用指令模板。
- 格式錯誤（非 http/https、markdown 連結等）的輸入仍被 `isValidURLFormat()` 拒絕，並顯示格式錯誤訊息。

**Interface / data shape:**

- 新增 helper：依網址回傳對應的指令模板字串（YouTube → `downloadCommand`；其他 → `genericDownloadCommand`）。僅 `downloadSingleTask` 的指令組裝改用此 helper；`getCookiesArguments` 維持不變。
- 新增常數：`AppSettingsDefaults.genericDownloadCommand`（String），含 `$youtubeUrl` 佔位符。
- 閘控：`addURL` 內的 playlist 偵測／混合 URL 提示分支，以及 video ID 縮圖預取，皆以 `isValidYouTubeURL()` 包覆，非 YouTube 網址略過。
- 移除：`URLValidationResult` 列舉的 `notYouTubeURL` case。

**Failure modes:**

- 非 YouTube 網站若仍因格式選擇器或網站限制而下載失敗，沿用既有的 yt-dlp 失敗處理流程（錯誤狀態 + 日誌），不新增特例。
- 縮圖預取經閘控後對非 YouTube 網址不執行，UI 顯示無縮圖佔位，待 metadata 補上真實縮圖。
- 非 YouTube 網址即使 URL 恰含 `list=` 或 11 碼路徑片段，也不觸發 playlist 展開、混合 URL 提示或 ytimg 縮圖。

**Acceptance criteria:**

- 貼上一個 x.com 或 Instagram 網址能成功加入佇列（不再回報「僅支援 YouTube 網址」），且以單一任務入列、不觸發 playlist 提示、不帶 ytimg 縮圖。
- 既有測試（如 `DownloadTaskTests` 及 `DownloadManager` 相關測試）通過；針對指令分流新增單元測試：YouTube 網址回傳 `downloadCommand`、非 YouTube 網址回傳 `genericDownloadCommand`。
- YouTube 網址下載流程的指令組裝結果與變更前一致。`downloadSingleTask` 為 `private` 且僅經 `startDownloadQueue()` → `processQueue()` 觸發，故此「零回退」MUST 以 spy/fake `YTDLPServiceProtocol`（連同必填的 `persistenceService` stub，經完整 `init(persistenceService:metadataService:ytdlpService:notificationService:)` 注入）驅動公開的 queue/start flow：直接將一個 `.pending` 的 `DownloadTask` 放入 `manager.tasks`（不走 `addURL` 的 metadata async flow）、呼叫 `startDownloadQueue()`、待 spy 捕捉實際傳給 `download(...)` 的 `commandTemplate`，斷言其等於既有 `downloadCommand`。若 queue flow 因 async／並行而難以穩定測試，替代作法為將 `downloadSingleTask`（或其模板解析接縫）改為 `internal` 以便直接測試。單測 `effectiveDownloadCommand(for:)` 僅驗證 template 選擇，不足以單獨證明 `downloadSingleTask` 的最終組裝未變。
- 專案建置通過：`xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`。

**Scope boundaries:**

- In scope：入口驗證放寬、指令分流 helper、`genericDownloadCommand` 常數、將 playlist 偵測／混合 URL 提示／ytimg 縮圖預取閘控於 YouTube 網址、移除 `notYouTubeURL`、UI 文案中性化。
- Out of scope：設定頁 UI 變更、`YouTubeMetadataService` 內部解析邏輯、`getCookiesArguments` 與 metadata 取得流程、針對特定網站的 cookies／格式特例、品牌與佔位符改名。

## Risks / Trade-offs

- [非 YouTube 網站 metadata 結構可能與現有解析不完全相容] → 透過實測 x.com／Instagram 驗證標題、縮圖、playlist 判定；此驗證列為 tasks 項目。
- [通用指令 `bv*+ba/b` 對某些網站仍可能挑不到理想格式或下載失敗] → 沿用既有失敗處理；通用指令以「盡量成功」為目標而非「最佳畫質」，屬可接受取捨。
- [`--cookies-from-browser safari` 對 x.com／Instagram 不一定有效或必要] → 保留以利登入限定內容，無 cookies 時 yt-dlp 仍會嘗試公開下載並優雅降級；其有效性列入 tasks 驗證。
- [放寬入口驗證後使用者可能貼入 yt-dlp 不支援的網址] → 由 yt-dlp 既有失敗處理回報，不在本變更新增白名單。
