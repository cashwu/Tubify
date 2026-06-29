## 1. 新增通用下載指令常數

- [x] 1.1 在 `AppSettingsDefaults` 新增固定常數 `genericDownloadCommand`。此常數 MUST 為一條**完整**的 yt-dlp 指令字串，結構與 `AppSettingsDefaults.downloadCommand` 相同（含 `yt-dlp`、`--cookies-from-browser safari` 與 `"$youtubeUrl"` 佔位符），僅 `-f` 格式選擇器改為通用值（如 `bv*+ba/b`）——因為 `commandTemplate` 會被 `YTDLPService` 整條解析執行，只存格式選擇器會產生無效呼叫。完成標準：常數為完整指令且含 `$youtubeUrl` 佔位符；不新增對應的 `AppSettingsKeys` 條目、不寫入 `UserDefaults`。驗證：建置通過，且原始碼檢視確認 `SettingsView` 未引用此常數。

## 2. 依網址分流下載指令（command routing）

- [x] 2.1 在 `DownloadManager` 新增 helper `effectiveDownloadCommand(for:)`：YouTube 網址回傳既有 `downloadCommand`，非 YouTube 網址回傳 `genericDownloadCommand`；判斷重用既有 `isValidYouTubeURL()`。存取層級設為 `internal`（非 `private`），使測試可透過 `@testable import` 實際呼叫此方法，而非複製邏輯。完成標準：YouTube 網址取得 `downloadCommand`、非 YouTube 取得 `genericDownloadCommand`。驗證：新增單元測試覆蓋兩種網址（見 6.1）。
- [x] 2.2 僅將 `downloadSingleTask` 的 `commandTemplate:` 改為透過 `effectiveDownloadCommand(for: task.url)` 取得模板；`getCookiesArguments` 維持讀取全域 `downloadCommand`，不納入路由（兩種指令皆含相同 `--cookies-from-browser safari`，且該 helper 僅由 metadata 路徑呼叫）。完成標準：YouTube 下載組裝出的指令與變更前完全一致；非 YouTube 下載使用通用指令；metadata 流程不變。驗證：執行 `xcodebuild test` 既有測試通過。

## 3. 放寬入口驗證並移除 notYouTubeURL

- [x] 3.1 在 `DownloadManager.addURL` 移除 `isValidYouTubeURL()` 拒絕分支，僅保留 `isValidURLFormat()` 作為入口驗證。完成標準：任何 http/https 格式正確的網址都能加入佇列；格式錯誤仍被拒絕。驗證：手動貼上 x.com 網址成功加入佇列。
- [x] 3.2 從 `URLValidationResult` 移除 `notYouTubeURL` case，並移除 `ContentView.handleURLValidationResult` 中對應的「僅支援 YouTube 網址」訊息分支。完成標準：列舉不再含 `notYouTubeURL`，且專案無未處理的 switch 分支殘留。驗證：建置通過（編譯器確保 switch 完整）。
- [x] 3.3 移除 `ContentView.processTextInput` 中現已多餘的 `youtube.com`／`youtu.be` 文字比對 fallback（保留 `http://`／`https://` 前綴判斷即可，該前綴文字本就會交給 `addURL`）。完成標準：貼上以 http(s) 開頭的非 YouTube 連結會交給 `addURL` 處理。驗證：手動貼上 Instagram 連結觸發加入流程。

## 4. 將 YouTube 專屬處理閘控於 YouTube 網址

- [x] 4.1 在 `DownloadManager.addURL` 將 playlist 偵測／展開（`isPlaylistSync`）與混合影片＋清單網址的「下載單支或整個清單」提示分支，以 `isValidYouTubeURL()` 包覆，使非 YouTube 網址一律走單一任務路徑。完成標準：非 YouTube 網址即使含 `list=` 也不觸發 playlist 展開或提示。驗證：手動貼上含 `list=` 的非 YouTube 測試網址，確認以單一任務入列。
- [x] 4.2 將 `addURL` 中由 `extractVideoIdSync` 推導的 `i.ytimg.com` 縮圖預取，以 `isValidYouTubeURL()` 閘控，僅 YouTube 網址設定 ytimg 縮圖。完成標準：非 YouTube 網址（如含 11 碼路徑片段的 Instagram 連結）不會被設定 ytimg 縮圖。驗證：原始碼檢視 + 手動觀察 Instagram 任務不顯示錯誤縮圖。

## 5. UI 文案中性化

- [x] 5.1 [P] 將 `EmptyStateView` 的「拖放或貼上 YouTube 連結」等 YouTube 字眼改為通用影片用語。完成標準：空狀態提示以一般影片連結措辭呈現，不暗示僅支援 YouTube。驗證：原始碼檢視確認文案已中性化。

## 6. 測試與驗證

- [x] 6.1 [P] 為 `effectiveDownloadCommand(for:)` 新增單元測試：透過 `@testable import` 實例化 `DownloadManager` 並呼叫真實方法（非複製邏輯），驗證 YouTube 網址（`youtube.com/watch`、`youtu.be`、`youtube.com/playlist?list=`）回傳 `downloadCommand`；非 YouTube 網址（`x.com`、`instagram.com`）以及不受支援的 YouTube-domain 形狀（`https://www.youtube.com/@channelname`、`https://www.youtube.com/watch?list=PL123`〔無 `v=`〕）回傳 `genericDownloadCommand`。完成標準：測試呼叫真實 helper、涵蓋三類網址（含 YouTube-domain 但非支援形狀者走 generic，藉此排除以 domain 為判斷的實作）並通過。驗證：`xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'` 通過。
- [x] 6.2 [P] 為 `downloadSingleTask` 的 YouTube 零回退新增測試：因 `downloadSingleTask` 為 `private`，以 spy/fake `YTDLPServiceProtocol`＋`persistenceService` stub 經完整 `init(persistenceService:metadataService:ytdlpService:notificationService:)` 注入，直接將一個 `.pending` 的 `DownloadTask` 放入 `manager.tasks`（不走 `addURL` 的 metadata／media selection async flow，以收窄測試範圍）後呼叫公開的 `startDownloadQueue()` 觸發 queue flow，由 spy 捕捉實際傳給 `download(...)` 的 `commandTemplate`，斷言 YouTube 網址使用既有 `downloadCommand`、非 YouTube 網址使用 `genericDownloadCommand`。若 queue flow 的 async／並行難以穩定測試，替代作法為將 `downloadSingleTask`（或模板解析接縫）改為 `internal` 直接測試。完成標準：測試驗證 `downloadSingleTask` 實際使用的最終模板，而非僅測 helper 回傳值。驗證：`xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'` 通過。
- [x] 6.3 手動驗證非 YouTube 網站端到端流程：分別以一個 x.com 與一個 Instagram 公開貼文網址實測，確認 metadata（標題、縮圖）能取得、通用指令可成功下載，並記錄 `--cookies-from-browser safari` 對這些網站是否有效／必要。完成標準：兩站皆能完成下載或留下明確失敗紀錄與成因。驗證：實際執行 app 觀察下載結果與日誌。
