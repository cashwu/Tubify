## Summary

修正「影片明明有字幕，但字幕／音軌選擇視窗不會出現」的缺陷。根因是抓取媒體選項的 metadata 呼叫帶了 Safari cookies，導致 yt-dlp 改用 `tv` client，回傳的 JSON 不含 `subtitles`。改為先以不帶 cookies 取得媒體選項，僅在錯誤訊息符合既有「需登入」分類時才帶 cookies 重試。

## Motivation

`DownloadManager.fetchMetadataForTask` 與播放清單路徑都會呼叫 `YouTubeMetadataService.fetchMediaOptions`，並把 `getCookiesArguments()` 的結果傳進去。使用者的下載指令樣板含 `--cookies-from-browser safari`，因此只要 Safari cookies 匯出成功，這個 metadata 呼叫就會帶 `--cookies`。

以同一支影片實測（`yt-dlp -J --skip-download --no-playlist`，同一時間點連續兩輪，結果穩定）：

- 不帶 cookies：yt-dlp 記錄 `Downloading android vr player API JSON`，`subtitles` 為 `['zh']`
- 帶 cookies：yt-dlp 記錄 `Found YouTube account cookies` 與 `Downloading tv downgraded player API JSON`，`subtitles` 為空，只剩 1 個 `automatic_captions`

`parseSubtitles` 只採用使用者上傳的 `subtitles`、不採用 `automatic_captions`，所以帶 cookies 時 `filteredSubtitles` 為空，任務不會進入 `.waitingForMediaSelection`，直接排入下載佇列，使用者看不到選擇視窗，下載出來的檔案也沒有字幕。

這個缺陷是條件性的：只有在 Safari cookies 匯出成功時才會發生，因此在缺少完整磁碟存取權限的環境下不會重現，容易被誤判為偶發。cookies 是為了修正「抓不到標題」而在既有變更中加入 metadata 路徑的，當時未考慮 cookies 會改變 yt-dlp 的 client 選擇。

下載路徑已有相近形狀的既有策略：先不帶 cookies，失敗後才視情況轉為帶 cookies。其 gate 是 `YTDLPService.shouldRetryWithCookies(_:)`，由 `indicatesLoginRequired(_:)` 與 `isDownloadVideoData403(_:)` 兩個訊號組成（見 `openspec/specs/download-reliability/spec.md` 的 cookies contract）。metadata 路徑應與之對齊，但只重用其中的登入訊號清單。

## Proposed Solution

在 `YouTubeMetadataService.fetchMediaOptions` 內採用兩階段策略：

1. 第一次呼叫一律不帶 cookies，即使呼叫端傳入了 cookies 參數。
2. 第一次呼叫失敗時，以既有的登入錯誤分類判斷 stderr 訊息；只有在判定為「需登入」且呼叫端確實提供了 cookies 參數時，才帶 cookies 重試一次。
3. 第一次呼叫成功時直接回傳結果，不做第二次呼叫。

登入錯誤分類重用 `YTDLPService.indicatesLoginRequired` 既有的訊號清單，避免 metadata 與下載兩條路徑對「什麼算需登入」出現兩套定義。由於該函式目前只接受 `YTDLPError`，需要提供一個接受錯誤訊息字串的入口，並讓既有的 `YTDLPError` 版本委派給它，維持單一事實來源。刻意不重用完整的 `shouldRetryWithCookies`：其另一半 `isDownloadVideoData403` 針對的是下載 video data 時的 403，而媒體選項查詢帶 `--skip-download`、不下載 video data，該訊號在此路徑不適用。

為了讓兩階段行為可被自動測試觀察，`YouTubeMetadataService` 需要一個可注入的 yt-dlp 執行檔路徑接縫，與 `YTDLPService(ytdlpPathProvider:)` 相同形狀；`shared` 維持不變。測試以 fixture 執行檔記錄每次 invocation 的參數，驗證第一次不含 `--cookies`、以及重試是否依分類發生。

## Non-Goals

- 不改變 `fetchVideoInfo`、`fetchPlaylistInfo` 的 cookies 行為；標題與播放清單展開不在本次範圍。
- 不改變下載指令本身的 cookies 策略，也不修改 `openspec/specs/download-reliability/spec.md` 既有的 403 與 cookies contract。
- 不改變 `parseSubtitles` 只採用使用者上傳字幕、排除 `automatic_captions` 的既有決定。
- 不改變字幕選擇視窗的 UI 行為與預設選取邏輯。
- 不新增使用者可見的設定項來控制 metadata 是否帶 cookies。

## Alternatives Considered

- **完全移除 metadata 路徑的 cookies**：最簡單，但會讓私人影片、會員限定影片與需要登入確認的影片抓不到媒體選項，等於回退當初加入 cookies 所修正的問題。
- **改為採用 `automatic_captions`**：能讓視窗在帶 cookies 時仍出現，但改變了既有「只提供使用者上傳字幕」的產品決定，且自動字幕品質與語言集合都不同，屬於另一個議題。
- **兩次呼叫合併結果（帶與不帶 cookies 各一次並取聯集）**：字幕偵測會最完整，但每次新增任務固定付出兩次 yt-dlp 呼叫的延遲，且需要定義兩份 JSON 衝突時的取捨規則，複雜度不成比例。
- **保留 cookies，改以 `--extractor-args "youtube:player_client=..."` 指定 client**：若可行會是單次呼叫、不新增登入訊號漏判風險、也沒有播放清單的成本放大。已實測否決：在帶帳號 cookies 的前提下指定 `android_vr` 會以 `Requested format is not available` 失敗、指定 `tv` 會以 `The page needs to be reloaded.` 失敗、指定 `web_safari` 取回的 `subtitles` 仍為空。yt-dlp 在偵測到帳號 cookies 時的 client 選擇無法用這個旗標繞過，因此不採用。
- **在 `DownloadManager` 呼叫端就不傳 cookies 給 `fetchMediaOptions`**：可行，但要在單一影片、播放清單、post_live 三處各改一次，且無法表達「失敗才帶 cookies」的重試，容易在未來新增呼叫端時再度漏掉。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `subtitle-selection`：新增「媒體選項偵測不得因 cookies 而遺失字幕軌」的行為契約，涵蓋第一次不帶 cookies、依登入訊號重試一次、成功時不重試，以及媒體選項查詢重用下載路徑的登入訊號定義（僅共用訊號清單，不共用整體重試決策）。
- `youtube-post-live-replay`：spec 文字不需修改，但其 `post_live` follow-up format lookup 就是本變更改動的 `fetchMediaOptions`，屬受影響範圍，需回歸驗證既有判定不變。

## Impact

- Affected specs: `subtitle-selection`（新增 requirement）、`youtube-post-live-replay`（不修改文字，僅需回歸驗證）
- Affected code:
  - New:
    - （無）
  - Modified:
    - `Tubify/Services/YouTubeMetadataService.swift`
    - `Tubify/Services/YTDLPService.swift`
    - `TubifyTests/YouTubeMetadataServiceTests.swift`
    - `TubifyTests/YTDLPServiceTests.swift`
  - Removed:
    - （無）
