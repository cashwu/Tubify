# 已完成的 change 與 task 紀錄

本文件整理 Tubify 過去以 OpenSpec／Cash 流程完成並封存的 10 個 change，共 **143 項 task，全部完成**。各 change 產出的規格已合併到 [`docs/specs/`](specs/README.md)；本文件保留「為什麼做、做了什麼、驗證到什麼程度、有哪些取捨」。更完整的資料見：各 change 的[設計文件](design/README.md)、[實作備註](implementation-notes.md)，以及 review 累積的[反覆缺陷整理](review-signals.md)。

| # | 日期 | Change | 主要規格 | Task |
| - | ---- | ------ | -------- | ---- |
| 1 | 2026-03-12 | [playlist-selection](#1-playlist-selection) | [playlist-selection](specs/playlist-selection.md) | 10 / 10 |
| 2 | 2026-04-09 | [playlist-or-video-prompt](#2-playlist-or-video-prompt) | [playlist-or-video-prompt](specs/playlist-or-video-prompt.md) | 4 / 4 |
| 3 | 2026-06-11 | [fix-post-live-replay-downloads](#3-fix-post-live-replay-downloads) | [youtube-post-live-replay](specs/youtube-post-live-replay.md) | 14 / 14 |
| 4 | 2026-06-29 | [route-download-command-by-site](#4-route-download-command-by-site) | [multi-site-download](specs/multi-site-download.md) | 12 / 12 |
| 5 | 2026-07-13 | [add-clear-all-subtitles](#5-add-clear-all-subtitles) | [subtitle-selection](specs/subtitle-selection.md) | 3 / 3 |
| 6 | 2026-07-13 | [improve-download-ui-workflows](#6-improve-download-ui-workflows) | [download-ui-workflows](specs/download-ui-workflows.md) | 7 / 7 |
| 7 | 2026-08-02 | [retry-transient-download-403](#7-retry-transient-download-403) | [download-reliability](specs/download-reliability.md) | 11 / 11 |
| 8 | 2026-08-21 | [cleanup-orphaned-part-files](#8-cleanup-orphaned-part-files) | [download-reliability](specs/download-reliability.md) | 25 / 25 |
| 9 | 2026-08-21 | [cookieless-subtitle-detection](#9-cookieless-subtitle-detection) | [subtitle-selection](specs/subtitle-selection.md) | 23 / 23 |
| 10 | 2026-08-22 | [dubbed-audio-track-selection](#10-dubbed-audio-track-selection) | [audio-track-selection](specs/audio-track-selection.md)、[subtitle-selection](specs/subtitle-selection.md) | 34 / 34 |

---

## 1. playlist-selection

**日期**：2026-03-12　**規格**：`playlist-selection`　**設計**：[design/2026-03-12-playlist-selection.md](design/2026-03-12-playlist-selection.md)

**動機**：貼上播放清單 URL 時所有影片會自動加入佇列，使用者無法只下載部分影片，大型清單（數十到上百集）要事後手動刪除。

**做了什麼**：播放清單展開後彈出選集視窗，預設全選，可全選／全部取消，按鈕顯示已選數量；確認後接續字幕／音軌選擇再入列；取消則移除佔位任務。字幕／音軌設定統一套用到所有已選影片，個別影片不支援時 fallback 到預設。

**完成的 task**

- [x] 1.1 新增 `PlaylistSelectionRequest` 結構（callback 模式觸發選集 UI）
- [x] 1.2 `DownloadManager.onPlaylistSelectionNeeded` callback；`expandPlaylist()` 改為觸發 callback 而非直接入列
- [x] 2.1 建立 `PlaylistSelectionView`（標題、總數、勾選列表、預設全選）
- [x] 2.2 全選／全部取消
- [x] 2.3 下載按鈕顯示已選數量，無選取時停用
- [x] 3.1 `ContentView` 以 sheet 呈現，兩段式流程銜接 `MediaSelectionView`
- [x] 3.2 取消時移除佔位任務
- [x] 3.3 字幕／音軌不支援時 fallback 預設
- [x] 4.1 `PlaylistSelectionView` 測試（預設全選、全選／取消、計數、空選取停用）
- [x] 4.2 `DownloadManager` 測試（觸發 callback 而非直接入列、取消移除佔位任務）

---

## 2. playlist-or-video-prompt

**日期**：2026-04-09　**規格**：`playlist-or-video-prompt`　**設計**：[design/2026-04-09-playlist-or-video-prompt.md](design/2026-04-09-playlist-or-video-prompt.md)

**動機**：從播放清單中點開某支影片的連結同時含 `v=` 與 `list=`，原本直接進入播放清單選集，但使用者可能只想下載那一支。仿 Downie 先詢問意圖。

**做了什麼**：URL 同時含 `v=` 與 `list=` 時彈出三選一對話框「影片／播放清單／取消」。選「影片」以 `URLComponents` 移除 `list`、`index` 後走單一影片流程；選「播放清單」走原流程；純 `list=` URL 與純 `v=` URL 行為不變。

**完成的 task**

- [x] 1.1 `DownloadManager.onVideoOrPlaylistChoiceNeeded` callback
- [x] 1.2 `addURL()` 偵測同時含 `v=` 與 `list=` 的 URL，觸發 callback
- [x] 1.3 `confirmVideoOrPlaylistChoice()` 處理三種選擇（以 `URLComponents` 清理參數）
- [x] 2.1 `ContentView` 以 SwiftUI Alert（非 Sheet）呈現三個按鈕

---

## 3. fix-post-live-replay-downloads

**日期**：2026-06-11　**規格**：`youtube-post-live-replay`　**設計**：[design/2026-06-11-fix-post-live-replay-downloads.md](design/2026-06-11-fix-post-live-replay-downloads.md)

**動機**：直播剛結束就下載回放時，yt-dlp 回傳 `This live event has ended.` 被當成永久失敗；metadata 階段也把 `live_status = post_live` 一律視為直播處理中而不嘗試下載。實際上 YouTube 在 post_live 期間可能已釋出可下載的 DASH 回放 manifest。

**做了什麼**

- `post_live` 時先檢查是否已有「可用媒體格式」（可配對的影片＋音訊、合併格式、DASH、HLS）；有就走正常下載，沒有則維持 `postLive`。單獨的 video-only／audio-only、縮圖、storyboard、無 codec 的項目不算。
- 下載階段把 `This live event has ended.` 分類為暫態 `postLive`，保留可讀訊息，不送出一般失敗通知；其他錯誤維持 `failed`。
- 使用者可手動重試 `postLive` 任務：清除錯誤、進度歸零、重新走 metadata 與下載流程。
- Non-goals：不做背景自動輪詢，不換下載後端，不動 playlist 行為。

**完成的 task**

- [x] 1.1 post-live 可下載分流測試（含 `137+140` 正向案例）
- [x] 1.2 ended-live 錯誤分類測試（`postLive` vs. `Video unavailable` → `failed`）
- [x] 1.3 手動重試測試
- [x] 1.4 無可用格式時維持 `postLive` 且不啟動下載
- [x] 1.5 formats 查詢錯誤測試（ended-live → `postLive`；其他 → `failed` 並保留訊息、送通知）
- [x] 1.6 usable media formats predicate 測試（各種排除項）
- [x] 2.1 post_live 先確認可下載格式的 helper／predicate
- [x] 2.2 ended-live 字串集中分類
- [x] 2.3 格式不可用時維持 `postLive` 並保留訊息
- [x] 2.4 formats 查詢錯誤依類型轉換狀態
- [x] 3.1 重試重新走 metadata 與下載流程
- [x] 3.2 確認 `DownloadItemView` 對 `postLive` 的狀態文字與重試按鈕
- [x] 4.1 完整測試通過
- [x] 4.2 規格驗證通過

---

## 4. route-download-command-by-site

**日期**：2026-06-29　**規格**：`multi-site-download`　**設計**：[design/2026-06-29-route-download-command-by-site.md](design/2026-06-29-route-download-command-by-site.md)　**實作備註**：[implementation-notes.md](implementation-notes.md#route-download-command-by-site)

**動機**：`DownloadManager.addURL` 的 `isValidYouTubeURL()` 是唯一阻止使用者下載 x.com、Instagram 等站台的關卡，但後端 yt-dlp 原生支援上千個網站。

**做了什麼**

- 入口驗證放寬為 `isValidURLFormat()`（http/https），移除 `URLValidationResult.notYouTubeURL` 與相關訊息。
- `isValidYouTubeURL()` 改為分流路由器：YouTube 網址用使用者設定的 `downloadCommand`，其餘用固定常數 `AppSettingsDefaults.genericDownloadCommand`（完整 yt-dlp 指令，僅 `-f` 改為 `bv*+ba/b`，不進設定頁、不可編輯）。
- 播放清單偵測／展開、影片或清單提示、`i.ytimg.com` 縮圖預取，全部閘控於 YouTube 網址。
- 移除 `ContentView.processTextInput` 多餘的 youtube 文字比對 fallback；空狀態文案中性化。

**完成的 task**

- [x] 1.1 新增 `genericDownloadCommand` 固定常數
- [x] 2.1 `effectiveDownloadCommand(for:)` helper（`internal`，供測試呼叫）
- [x] 2.2 `downloadSingleTask` 經 helper 取得模板；`getCookiesArguments` 不納入路由
- [x] 3.1 移除 YouTube 入口拒絕分支
- [x] 3.2 移除 `notYouTubeURL` case
- [x] 3.3 移除多餘的文字 fallback
- [x] 4.1 playlist 偵測與提示閘控於 YouTube
- [x] 4.2 ytimg 縮圖預取閘控於 YouTube
- [x] 5.1 空狀態文案中性化
- [x] 6.1 `effectiveDownloadCommand(for:)` 單元測試（含 `@channel`、無 `v=` 的 `list=` 等「YouTube 網域但非支援形狀」案例）
- [x] 6.2 `downloadSingleTask` 實際使用模板的 spy 測試
- [x] 6.3 手動 e2e 驗證非 YouTube 站台

**實測結果（task 6.3，yt-dlp 2026.06.09）**

| 站台 | 結果 |
| ---- | ---- |
| x.com | 完整成功，不需 cookies |
| Instagram | 需登入；通用指令內建的 `--cookies-from-browser safari` 依賴完整磁碟存取（FDA）與 Safari 登入態 |
| Threads | 此版 yt-dlp 無 extractor（`Unsupported URL`），屬上游限制 |

**備註**：測試放在既有 `DownloadManagerTests.swift`（`Tubify.xcodeproj` 未使用 file-system-synchronized groups，新增檔案需重生整個 project），屬 deviation。

---

## 5. add-clear-all-subtitles

**日期**：2026-07-13　**規格**：`subtitle-selection`

**動機**：字幕預設全選，只想要其中一種時得逐項取消。

**做了什麼**：字幕區塊加入「全部取消」，一次清空所有勾選、不關閉視窗、不影響音軌選擇；預設全選行為不變。以同檔案內的純函式 `clearSelectedSubtitles(_:)` 實作。

**完成的 task**

- [x] 1.1 `clearSelectedSubtitles(_:)` 測試（清空、不動音軌、可重新只勾一種）
- [x] 2.1 `MediaSelectionView` 加入「全部取消」操作，並以 SwiftUI preview 手動驗證預設全選與按鈕接線
- [x] 3.1 完整 `xcodebuild test` 通過

---

## 6. improve-download-ui-workflows

**日期**：2026-07-13　**規格**：`download-ui-workflows`　**設計**：[design/2026-07-13-improve-download-ui-workflows.md](design/2026-07-13-improve-download-ui-workflows.md)　**實作備註**：[implementation-notes.md](implementation-notes.md#improve-download-ui-workflows)

**動機**：全域貼上快捷鍵、重啟後任務恢復、失敗原因呈現與完成後導向，存在會阻斷或混淆使用者的行為。

**做了什麼**

- **貼上**：Command-V 只在主下載視窗處理 URL；文字輸入元件保有正常貼上；`PasteMonitorController` 確保 monitor 不重複累積。
- **任務恢復**：UI 啟動後（callbacks 就緒）才恢復 `downloading`／`pending`／`fetchingInfo`／`waitingForMediaSelection`；以 `resumePersistedTasksAfterUIActivation(sessionID:)` 保證冪等，新 UI session 重播未解決的請求且只一次；`completed`／`failed`／`cancelled`／`paused`／`scheduled`／`livestreaming`／`postLive` 不動。
- **錯誤呈現**：失敗列顯示最多 160 個 `Character` 的摘要（超長為前 159 個加 `…`），可檢視與複製完整錯誤。
- **完成導向**：新安裝預設保留完成項目；點擊完成通知在 Finder 選取檔案，無效路徑安全結束。
- **設定與可存取性**：統一為單一原生 Settings scene（工具列與 Command-, 同一入口）；語意字級、移除 `.focusable(false)`、補 localized accessibility labels；下載指令驗證（空白、缺 `$youtubeUrl`）；含空格的資料夾路徑可正確作為 picker 起點。

**完成的 task**

- [x] 1.1 任務恢復（TDD；含 request registries 與 session 重連）
- [x] 2.1 Focus-aware 貼上 monitor 生命週期
- [x] 2.2 可操作的錯誤呈現
- [x] 2.3 持久完成項目與通知導向
- [x] 3.1 單一原生 Settings scene 與設定驗證
- [x] 3.2 語意字級與可存取控制項
- [x] 4.1 整合驗證（完整 `xcodebuild test` ＋ 手動檢查清單）

**備註**

- Deviation：把 `PersistenceService.swift` 納入範圍，移除 `loadTasks()` 在 UI 啟動前將 `.downloading` 改為 `.pending` 的轉換，統一交給 `DownloadManager` 處理；並預先把三個新測試檔加入 Xcode target。
- 手動驗證通過項目：Settings 單一視窗、各情境的貼上範圍、關閉重開主視窗後 monitor 唯一（驗證中發現 SwiftUI restoration 會覆寫 `NSWindow.identifier`，已修正）、驗證訊息、含空格資料夾、錯誤詳情／複製、completed row 動作、AX tree。
- **系統限制**：實際點擊系統完成通知未能在 debug 環境完成（三種啟動路徑皆因 `UNErrorDomain 1` 拒絕通知授權）；通知路由、Finder reveal 與 completion handler 恰好一次由 `NotificationServiceTests` 自動驗證，未宣稱完成真實點擊。

---

## 7. retry-transient-download-403

**日期**：2026-08-02　**規格**：`download-reliability`　**設計**：[design/2026-08-02-retry-transient-download-403.md](design/2026-08-02-retry-transient-download-403.md)

**動機**：下載階段收到 `unable to download video data: HTTP Error 403: Forbidden` 就立即失敗，但使用者數秒後手動重下通常成功。yt-dlp 的 `--retries` 無法涵蓋建立媒體連線時的直接 403，且無法重現「完整重新解析格式與媒體 URL」的效果。

**做了什麼**

- 在 `YTDLPService` 單次下載外加入 403 專用重試迴圈：僅當 `YTDLPError.executionFailed` 訊息含上述片段且不含 `Giving up after` 時重試，initial 後最多 3 次，等待 2、5、10 秒，每次重新啟動完整 yt-dlp process。
- 保留「先不帶 cookies，只有明確登入訊號才帶 Safari cookies」策略；單純 403 不切換 cookies 模式；不改動 `--retries`。
- 取消優先於剩餘重試；backoff 以最長 100 ms 的 sleep slice 組成，取消最遲在當前 slice 後結束且不啟動新 process。
- 每次 `download` 建立唯一 `DownloadOperationID`，取消只作用於當前 operation，舊 operation 不得在新 operation 開始後啟動 process。
- 重試過程不產生中間 failed 狀態或通知；日誌記錄 task ID、重試序號、上限與 delay。

**考慮過但拒絕的方案**：在預設命令加 `--retries`（不涵蓋此情境）、在 `DownloadManager` 把 failed 任務重排（錯誤分類洩漏到佇列層）、對所有錯誤重試（永久錯誤不會因重啟恢復）。

**完成的 task**

- [x] 1.1 403 分類 helper 測試
- [x] 1.2 `executeDownloadFlow` 以 scripted executor 驗證重試序列（2／5／10 秒）
- [x] 1.3 取消與 cookies contract 測試
- [x] 2.1 internal 分類／重試 policy 與可測的 `executeDownloadFlow`
- [x] 2.2 兩種 cookies 模板都經同一 `executeDownloadFlow`
- [x] 2.3 取消與日誌接線
- [x] 3.1 `YTDLPServiceTests` 通過
- [x] 3.2 完整 suite 無回歸
- [x] 4.1 `DownloadOperationID` 隔離與分類排除 `Giving up after`
- [x] 4.2 可控 yt-dlp executable fixture：驗證真實 `Process` 終止、cleanup、overlapping operations
- [x] 4.3 新增測試與完整 suite 皆 0 failures

---

## 8. cleanup-orphaned-part-files

**日期**：2026-08-21　**規格**：`download-reliability`　**設計**：[design/2026-08-21-cleanup-orphaned-part-files.md](design/2026-08-21-cleanup-orphaned-part-files.md)　**實作備註**：[implementation-notes.md](implementation-notes.md#cleanup-orphaned-part-files)

**動機**：403 重試或 cookies fallback 會啟動另一個 yt-dlp process；若重試改選不同格式，前一個 process 留下的 `<stem>.f401.mp4.part` 永遠不會被續傳也不會被刪除（實例：40 MB 的殘留檔），使用者每遇一次就多一個看似未完成的檔案。

**做了什麼**：下載整體成功後，在同一輸出目錄清除孤兒中間檔。為避免誤刪共用下載目錄中其他任務或第三方工具的檔案，候選檔須同時滿足：同輸出目錄、不在流程啟動前的目錄快照中、檔名為 `<stem>.` 加上符合 yt-dlp 中間檔形態 `^(f[0-9]+\.)?[A-Za-z0-9]{1,5}\.(part|ytdl|part-Frag[0-9]+)$`、mtime 早於最終輸出檔、且為一般檔案。刪除使用 `Darwin.unlink`（對任何目錄一律失敗、不跟隨 symbolic link）。清理絕不改變下載回傳值或拋錯，放棄與失敗路徑皆有日誌與可觀察結果（`CleanupOutcome`）。

**Non-goals**：下載最終失敗時不刪 partial（保留續傳）；不加 `--no-part`；不清理無後綴的完整中間檔；不做全域清理。

**完成的 task**

- [x] 1.1 擴充 `YTDLPFixture` 支援多 attempt 成功與單次失敗
- [x] 1.2–1.9 production fixture 測試：被刪除的 `.part`、`.ytdl`、`.part-Frag<N>`；保留最終檔與字幕；保留其他影片的中間檔；保留 `Lecture 1.5.…` 這類前綴碰撞；保留下載前已存在的檔案；保留 mtime 不早於最終檔者；最終失敗時不刪
- [x] 1.10–1.13 `attemptExecutor` seam 測試：輸出目錄不符、最終檔不存在、`chflags uchg` 造成單一刪除失敗、`executeDownloadFlow` 無副作用
- [x] 1.14 名稱符合形態的目錄與 symbolic link 保留
- [x] 1.15–1.17 快照不可得、目錄列舉失敗（`0o333`）、屬性讀取失敗（ACL `deny readattr`）
- [x] 1.18 刪除原語測試：`unlink` 對（非空／空）目錄為 `EPERM`、不跟隨 symbolic link
- [x] 2.1 `CleanupOutcome`、`directoryEntryNames(_:)`、`cleanupObserver` 參數與單一成功出口
- [x] 2.2 `cleanupOrphanedPartFiles(finalPath:outputDirectory:preexistingEntryNames:taskId:observer:)`
- [x] 2.3 在成功出口呼叫清理
- [x] 3.1 完整測試通過
- [x] 3.2 成功刪除日誌（含 task ID 與檔名）
- [x] 3.3 四個致命放棄分支與兩個非致命分支的日誌與 observer 成對
- [x] 3.4 確認 proposal Impact 與實際修改檔案一致

**備註**：Deviation —— seam 測試（1.10–1.13、1.15–1.18）需要 2.1 建立的 `CleanupOutcome` 才能編譯，因此執行順序調整為 2.1 → 這批測試 → 2.2 → 2.3；要交付的行為與驗收標準不變。

---

## 9. cookieless-subtitle-detection

**日期**：2026-08-21　**規格**：`subtitle-selection`　**設計**：[design/2026-08-21-cookieless-subtitle-detection.md](design/2026-08-21-cookieless-subtitle-detection.md)

**動機**：影片明明有字幕卻不出現選擇視窗。根因是媒體選項查詢帶了 Safari cookies，yt-dlp 偵測到帳號 cookies 後改用 `tv` client，回傳 JSON 不含 `subtitles`；而 `parseSubtitles` 只採用使用者上傳字幕，任務因此直接入列。此缺陷僅在 Safari cookies 匯出成功時發生，容易被誤判為偶發。

**做了什麼**：`YouTubeMetadataService.fetchMediaOptions` 改為兩階段：第一次一律不帶 cookies；僅當以非 0 exit code 失敗、訊息符合下載路徑既有的「需登入」訊號、且呼叫端提供了 cookies 時，才帶 cookies 重試一次（最多 2 次 invocation）。登入訊號只維持一份定義（`YTDLPService.indicatesLoginRequired(message:)`），不沿用下載路徑的 video-data 403 訊號（媒體選項查詢帶 `--skip-download`）。另提供 `YouTubeMetadataService(ytdlpPathProvider:)` 可注入接縫，僅限測試使用。

**考慮過但拒絕的方案**：完全移除 cookies（會讓私人／會員影片抓不到）、改用 `automatic_captions`（改變產品決定）、兩次呼叫取聯集（每次入列固定多一次延遲）、以 `--extractor-args player_client=...` 繞過（實測在帳號 cookies 下 `android_vr` 失敗、`tv` 失敗、`web_safari` 的 `subtitles` 仍空）。

**完成的 task**

- [x] 1.1–1.3 登入分類單一入口 `indicatesLoginRequired(message:)`，`YTDLPError` 版本委派給它，`shouldRetryWithCookies` 不變
- [x] 2.1–2.2 `ytdlpPathProvider` 接縫，5 處路徑解析統一
- [x] 3.1–3.10 兩階段 cookies 策略與測試：首次引數完整相等、成功不重試（含空結果）、需登入才帶 cookies 重試、兩次皆失敗以第二次訊息回報、非登入錯誤（含 video-data 403）不重試、無 cookies 不重試、空 stderr 行為
- [x] 4.1 三個 `fetchMediaOptions` 呼叫端未被改動
- [x] 4.2 解析函式與 `ytdlpNotFound`／`process.run()` 錯誤路徑未被改動
- [x] 4.3 `post_live`／`is_upcoming` 解析層迴歸
- [x] 4.4 `handlePostLiveFormatLookupError` 輸入變更迴歸（ended-live 仍可被分類）
- [x] 4.5 code review：無第二份登入訊號清單
- [x] 4.6 完整測試無回歸
- [x] 4.7 手動驗證：Safari cookies 可匯出的環境下，字幕視窗出現且下載第一次 invocation 不含 cookies
- [x] 4.8 code review：正式程式碼只經 `YouTubeMetadataService.shared`

---

## 10. dubbed-audio-track-selection

**日期**：2026-08-22　**規格**：`audio-track-selection`、`subtitle-selection`　**設計**：[design/2026-08-22-dubbed-audio-track-selection.md](design/2026-08-22-dubbed-audio-track-selection.md)　**實作備註**：[implementation-notes.md](implementation-notes.md#dubbed-audio-track-selection)

**動機**：多配音影片的媒體選擇視窗不顯示音軌區塊。實測（yt-dlp 2026.07.04）預設 client 只回傳 4 筆純音訊（皆為 `en`）；加上 `--extractor-args "youtube:player_client=default,web_embedded"` 後為 116 筆 formats、22 種語言。第二個獨立缺陷：選定配音語言後，format 改寫會保留一個未帶語言限制的 fallback，缺少 JS runtime 時配音格式消失，最終靜默下載成英文原聲且流程成功結束。

**做了什麼**

1. 媒體選項查詢兩次 invocation 都加上 `--extractor-args youtube:player_client=default,web_embedded`（合併而非取代 default client，避免影響既有下載覆蓋率）；值只在 `YTDLPService.youtubePlayerClientArgumentValue` 一處定義。
2. 僅在使用者明確選定音軌語言時，把同一組 extractor args 注入下載指令；範本已含時不覆蓋；注入早於 cookies 判斷，故 cookies 重試同樣帶上。
3. `injectLanguageIntoFormat` 改寫：依 bracket-aware 的 `,`／`/`／`+` 切分，語言限制附加在每個 alternative 的最後一個 part，並移除未受限的原始 fallback；範本沒有 `-f` 時補 `bv*+ba[language=xx]/b[language=xx]`。取不到語言時以 yt-dlp 的 `Requested format is not available` 失敗（單次 invocation、不觸發任何重試）。

**Non-goals**：不擴大 `LanguageFilter`（維持 `en`／`ja`／`zh`）、不改 `filteredAudioTracks.count > 1` 門檻、不處理 JS runtime／PO Token 安裝、不為非 YouTube 另立分支（`youtube:` 前綴對其他 extractor 惰性，已實測）。

**完成的 task**

- [x] 1.1–1.5 共用常數與媒體選項查詢引數（獨立字面值作為測試 oracle）
- [x] 2.1–2.2 `YTDLPFixture` 逐行記錄 argv（`arguments(at:)`、`invocationCount`）
- [x] 3.1–3.9 下載路徑注入 extractor args：選定語言注入、未選定／`selectedLanguage == nil` 不注入、範本已含不覆蓋、早於 cookies 轉換、cookies 重試保留、`removeSafariCookies` 保留
- [x] 4.1–4.8 format 語言限制：每個 alternative、最後一個 `+` 部分、中括號內分隔字元不切分、逗號群組、無 `-f` 時補預設
- [x] 5.1 code review：`youtube:player_client` 字面值只出現一次
- [x] 5.2 code review：解析函式與其他 `fetch*` 引數未被改動
- [x] 5.3 code review：音軌顯示門檻與 `LanguageFilter` 未被改動
- [x] 5.4 「取不到選定語言」失敗測試（`shouldRetryWithCookies` 為 `false`，invocation 恰 1 次）
- [x] 5.5 code review：`transformCommand` 保留 extractor args、注入順序
- [x] 5.6 post_live 解析層迴歸
- [x] 5.7 完整測試無回歸
- [x] 5.8 手動驗證：非 YouTube 網址不迴歸
- [x] 5.9 手動驗證：多配音影片（`Af6i6ChAVTw`）
- [x] 5.10 手動驗證：單一音軌影片不迴歸

**備註（deviation 與已知取捨）**

- 5.6 改以既有測試 `testPostLiveMediaOptionsStillParseLiveStatusAndFormats` 作為證據，不重複新增。
- 5.9 實際以 `zh-Hant` 取代 `ja` 驗證（兩者經過同一條程式路徑）；輸出檔以 `399+140-12` 的 format id 屬性證明為 `zh-Hant`，而非 `ffprobe` 標籤。
- **已知限制（使用者決定不處理）**：輸出檔的音訊串流語言標籤為 `und`，因下載指令未帶 `--embed-metadata`；使用者表示實際不會對同一支影片下載多種語言。
- **已知 flake（使用者決定接受）**：`DownloadManagerTests.testRecoveryStartsInterruptedAndPendingDownloadsOnlyOnce()` 偶發 test host crash，會讓 `./Scripts/package-app.sh` 的測試關卡間歇性擋下打包；無法穩定重現，與本 change 無因果關係。遇到時可確認失敗項目後以 `--skip-tests` 重跑。

---

## 後續變更（未經 OpenSpec 流程）

以下功能是在 OpenSpec／Cash 流程移除後直接開發並 commit，沒有 proposal、design 與 task 清單；規格已由實作與測試反推，補進對應的 `docs/specs/`。

### YouTube 自動字幕（commit `63d9f63`，版本 1.2.0）

**動機**：只有上傳字幕可選，沒有上傳字幕的影片拿不到繁體中文或英文字幕。

**做了什麼**

- 媒體選項查詢加上 `--write-auto-subs`，從 `automatic_captions` 提供繁體中文與英文的自動字幕選項（上傳字幕已涵蓋該語言時不提供）。
- 選擇視窗標示來源（自動翻譯／自動產生）、預設不勾選；視窗高度改為主視窗的 75%（至少 250）。
- 字幕與影片同一次下載；自動字幕被 YouTube 限流（HTTP 429）時，依序退回：帶 cookies 重試 → 逐一略過失敗的自動字幕。

**規格**：[subtitle-selection](specs/subtitle-selection.md)（新增 4 個 requirement、修改 2 個）、[download-ui-workflows](specs/download-ui-workflows.md)（新增視窗高度）。

**驗證**：commit 附帶新增測試（`SubtitleInfo` 模型、`parseSubtitles` 的 key 挑選、下載引數與各 fallback 分支）。2026-11-05 執行完整 `xcodebuild test`，385 個測試、0 failures。尚未以真實影片驗證實際遇到 HTTP 429 時的退路，也尚未經 `code-reviewer`／`code-simplifier` 審查。

