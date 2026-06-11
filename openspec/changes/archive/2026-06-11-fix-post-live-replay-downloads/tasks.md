## 1. 測試先行與錯誤分類

- [x] 1.1 為 Downloadable post-live replay detection 建立 metadata 分流測試，驗證 `live_status = post_live` 且初始 metadata 或 follow-up format lookup 回傳 usable media formats 時任務會進入可下載流程；測試必須包含 raw formats 含 video-only `format_id = "137"` 與 audio-only `format_id = "140"`，existing flow 可形成 `137+140` download option 的正向案例；以新增或更新 `TubifyTests/DownloadManagerTests.swift` 或 `TubifyTests/PostLiveReplayTests.swift` 的單元測試通過作為完成驗證。
- [x] 1.2 為 Ended-live extractor errors are transient post-live states 建立錯誤分類測試，驗證 `This live event has ended.` 會轉成 post-live 暫態而非一般 failed、保留 replay processing 或 not yet available 的 user-readable message、且不送出 generic failed download notification；同一測試也要驗證 `ERROR: [youtube] abc123: Video unavailable` 維持 `.failed` 並送出 generic failed download notification；以 `TubifyTests/YTDLPServiceTests.swift` 或 `TubifyTests/PostLiveReplayTests.swift` 的分類測試通過作為完成驗證。
- [x] 1.3 為 Manual retry rechecks post-live replay availability 建立重試測試，驗證 `.postLive` 任務重試會清除錯誤、重置 progress 並重新排隊；同一測試必須建立 `.postLive` 任務，retry 後 mock metadata 回傳 usable media formats，例如可形成 `137+140` download option，並確認任務走 normal downloadable video flow 而不是重用舊的 post-live 結果；以 `TubifyTests/DownloadManagerTests.swift` 的 retry 測試通過作為完成驗證。
- [x] 1.4 為 Downloadable post-live replay detection 建立不可下載分流測試，驗證 `live_status = post_live` 且沒有 usable media formats 時任務維持 `.postLive` 並不啟動下載 process；以 `TubifyTests/PostLiveReplayTests.swift` 的不可用 formats 測試通過作為完成驗證。
- [x] 1.5 為 Downloadable post-live replay detection 建立 formats 查詢錯誤測試，驗證 post_live formats 查詢遇到 ended-live error 時為 `.postLive`、遇到非 ended-live error 時為 `.failed`、保留原始非 ended-live 錯誤訊息並送出 generic failed download notification；以 `TubifyTests/PostLiveReplayTests.swift` 的 formats-query error 測試通過作為完成驗證。
- [x] 1.6 為 Downloadable post-live replay detection 建立 usable media formats predicate 測試，驗證 unpaired video-only、unpaired audio-only、thumbnails、storyboards、metadata-only entries、manifest-only entries、codec 不完整或無法 pairing 的 stream entries、以及沒有 audio/video codec 的 entries 都不算 usable media formats；以 `TubifyTests/PostLiveReplayTests.swift` 的 predicate 測試通過作為完成驗證。

## 2. Metadata 與下載流程

- [x] 2.1 實作 Decision: post_live metadata must check downloadable formats before blocking，讓 `DownloadManager` 在 `post_live` 時先確認是否已有 usable media formats，並將判斷集中在 helper 或 predicate 以套用 MUST NOT count 排除條件；以 1.1、1.4、1.6 測試與既有 metadata 測試通過作為完成驗證。
- [x] 2.2 實作 Decision: ended-live yt-dlp errors are transient post-live errors，將 ended-live 字串分類集中在 helper 或小型錯誤分類，讓下載階段把暫態錯誤轉為 `.postLive`、保留 user-readable message，並避免一般失敗通知；以 1.2 測試與 `TubifyTests/YTDLPServiceTests.swift` 通過作為完成驗證。
- [x] 2.3 確保 post_live formats 不可用時任務維持 `.postLive` 並保留可讀訊息，不啟動下載 process；以 1.4 測試與 DownloadManagerTests 通過作為完成驗證。
- [x] 2.4 確保 post_live formats 查詢錯誤依類型轉換狀態，ended-live error 進入 `.postLive`，非 ended-live error 進入 `.failed`、保留原始錯誤並送出 generic failed download notification；以 1.5 測試通過作為完成驗證。

## 3. Retry 與 UI 狀態

- [x] 3.1 實作 Decision: retry re-runs the normal metadata and download flow，讓 `.postLive` 任務重試時清除暫態錯誤、重置進度並重新走 metadata 與下載流程；以 1.3 測試通過作為完成驗證。
- [x] 3.2 檢查 `DownloadItemView` 對 `.postLive` 的狀態文字與重試按鈕仍符合使用者可理解的直播處理中狀態，明確確認 row 顯示 replay processing 或 not yet available 類訊息且 retry control 可用；以現有 ContentView/DownloadItemView 測試或手動 UI 檢查紀錄作為完成驗證。

## 4. 驗證

- [x] 4.1 執行 `swift test` 或專案既有 Xcode 測試命令，驗證新增與既有測試通過；以測試命令成功完成作為完成驗證。
- [x] 4.2 執行 `spectra validate fix-post-live-replay-downloads`，驗證 proposal、design、specs、tasks 仍符合 Spectra analyzer；以 CLI 顯示 valid 作為完成驗證。
