## Context

Tubify 使用 yt-dlp 取得 metadata 與執行下載。YouTube 直播結束後，yt-dlp 可能在短時間內回傳 This live event has ended.，但同一支影片稍後或在不同 extractor client 下會出現帶有 force_finished=1 的 DASH replay manifest。現有流程在 metadata 階段看到 live_status = post_live 就直接標記為直播處理中並停止；若下載階段收到已結束直播錯誤，則落入一般 failed 狀態。

這個 change 的重點是把 YouTube post-live 回放視為暫態狀態，而不是永久錯誤。實作需要橫跨 metadata 判斷、下載錯誤分類、任務狀態與 UI 顯示，但不需要替換 yt-dlp 或新增大型排程系統。

## Goals / Non-Goals

**Goals:**

- live_status = post_live 且 formats 已可用時，任務可以進入正常下載流程。
- This live event has ended. 類錯誤會被分類為 post-live 暫態，不會直接顯示一般失敗。
- 使用者手動重試會重新檢查 metadata 與下載狀態，讓回放可用後可成功下載。
- 測試覆蓋 metadata post_live 分流、下載錯誤分類與 retry 狀態重置。

**Non-Goals:**

- 不新增非 yt-dlp 下載後端。
- 不新增長時間自動輪詢服務或背景 scheduler。
- 不調整 playlist selection 或 ambiguous playlist/video URL 行為。
- 不變更 Safari cookies 解析與匯出格式。

## Decisions

### Decision: post_live metadata must check downloadable formats before blocking

當 `VideoInfo.liveStatus == "post_live"` 時，`DownloadManager` 不應立即 return。它應透過現有 media options/formats 查詢確認是否已有可下載格式。usable media formats 指 yt-dlp JSON `formats` 中可供現有下載流程形成完整下載選項的媒體格式：包含 combined video/audio format、可配對的 separate video/audio formats、DASH/HLS media format；DASH/HLS entry 仍必須能由現有 option builder 形成完整 audio/video download option。單一孤立的 video-only 或 audio-only entry、thumbnails、storyboards、metadata-only entries、manifest-only entries、codec 不完整或無法 pairing 的 stream entry、或沒有 audio/video codec 的項目不算 usable。若 formats 可用，任務依一般影片流程繼續取得字幕、音軌並排入下載；若 formats 查詢仍回傳已結束直播、沒有可用格式，或回傳 ended-live 暫態錯誤，才標記為 `.postLive`。

替代方案是永遠等待 `live_status` 變成 `was_live` 或 `not_live`。這會錯過 YouTube 已提供 replay manifest 但仍回報 post_live 的窗口，造成可下載內容被阻擋。

### Decision: ended-live yt-dlp errors are transient post-live errors

`YTDLPService` 或上層錯誤處理需要提供明確分類，本 change 必須支援的最小 matcher 是錯誤訊息包含 substring `This live event has ended.`。其他 YouTube ended-live 變體不需要在本 change 中窮舉，但分類邏輯應集中在同一 helper 或小型 enum，方便後續擴充。`DownloadManager` 接到此分類時，應把任務設為 `.postLive` 並保存可讀錯誤訊息，而不是 `.failed`。

替代方案是在 command template 加上 `--wait-for-video` 作為唯一修正。這會把等待策略藏在使用者設定字串裡，而且不處理手動重試與 UI 狀態語意，因此只能作為未來可選強化，不作為本次核心修正。

### Decision: retry re-runs the normal metadata and download flow

`retryTask` 或等價重試入口應清除暫態錯誤、重置進度，並把 `.postLive` 任務送回 `.pending`。重試後必須重新走 metadata 判斷，而不是直接重用舊的 post_live 結果。

替代方案是為 `.postLive` 實作自動倒數輪詢。這會擴大生命週期管理與取消語意，本次先保留手動重試與明確狀態。

## Implementation Contract

- Behavior: 當使用者加入剛結束的 YouTube 直播 URL，如果 metadata 回報 `live_status = post_live` 且 formats 已可用，Tubify SHALL 把它視為可下載回放並繼續正常下載流程。
- Behavior: 當 yt-dlp 在下載階段回傳 `This live event has ended.`，Tubify SHALL NOT 將任務標記為一般 `.failed`。任務 SHALL 進入 `.postLive`，保留使用者可讀的狀態與重試入口。
- Behavior: 使用者對 `.postLive` 任務執行重試時，Tubify SHALL 清除舊錯誤、重置 progress，並重新執行 metadata 檢查與下載嘗試。
- Interface / data shape: `DownloadStatus.postLive` 可沿用為直播回放處理中狀態；若需要新增錯誤分類，應使用小型 enum 或 helper，避免把字串比對散落在 UI 與 view model。
- Failure modes: formats 查詢失敗且錯誤符合 ended-live 暫態時，任務 SHALL 顯示 `.postLive`；formats 查詢失敗且錯誤不符合 ended-live 暫態時，任務 SHALL 繼續使用既有 `.failed` 流程與失敗通知。
- Acceptance criteria: 單元測試 SHALL 覆蓋 post_live formats 可用時進入可下載流程、post_live formats 不可用時維持 `.postLive`、ended-live 下載錯誤轉為 `.postLive`、重試會重新排隊。
- Scope boundaries: 本 change 僅處理單一影片與已展開影片任務的 post-live replay 狀態，不修改 playlist 選擇流程或 Safari cookies 行為。

## Risks / Trade-offs

- [Risk] YouTube ended-live 訊息文字可能有變體 → Mitigation: 將分類集中在單一 helper，測試覆蓋目前已知字串，後續可用同一 helper 擴充。
- [Risk] post_live formats 查詢會增加一次 yt-dlp metadata 呼叫 → Mitigation: 僅在 post_live 分支執行，避免影響一般影片。
- [Risk] 可下載 formats 出現但後續 fragment 仍短暫失敗 → Mitigation: 下載階段仍保留暫態分類，讓使用者可重試而非永久失敗。
- [Risk] 過早自動重試可能打擾使用者或增加 YouTube 請求 → Mitigation: 本次不新增自動輪詢，只保留手動重試。

## Migration Plan

不需要資料遷移。既有 `.postLive` 任務在使用者按重試後會走新流程。若需要 rollback，還原 view model 與 service 的 post-live 分類邏輯即可，持久化資料格式不變。

## Open Questions

- 是否要在後續 change 增加可選的自動重試倒數，目前本 change 不處理。
