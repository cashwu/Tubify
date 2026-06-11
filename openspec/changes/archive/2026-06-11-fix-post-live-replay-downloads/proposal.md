## Problem

使用者在 YouTube 直播結束後不久下載回放時，Tubify 會把 yt-dlp 回傳的 This live event has ended. 當成永久失敗，或在 metadata 階段把 live_status = post_live 一律視為直播處理中而不嘗試下載。實際上 YouTube 在 post_live 期間可能已經釋出可下載的 DASH 回放 manifest，Downie 類工具會等待或重試直到回放可用。

## Root Cause

Tubify 目前把 post_live 視為不可下載狀態，且下載階段沒有把 This live event has ended. 當成直播回放暫態錯誤處理。yt-dlp 只執行一次，沒有針對剛結束直播的回放釋出窗口進行狀態轉換、延遲重試，或重新檢查 formats 是否已可用。

## Proposed Solution

- 讓 metadata 階段在 live_status = post_live 時確認是否已有可下載 formats；有 formats 時允許進入正常下載流程。
- 讓下載階段辨識 This live event has ended. 這類已結束直播暫態錯誤，將任務轉為直播處理中並保留手動重試入口，而不是直接標記失敗。
- 保留使用者手動重試能力，並讓重試重新走 metadata 與下載流程。
- 增加針對 post_live 可下載、post_live 尚未可下載、下載階段暫態錯誤的測試。

## Non-Goals

- 不新增新的下載後端或替換 yt-dlp。
- 不實作長時間自動輪詢服務、背景 scheduler、或大型工作系統。
- 不變更 playlist 選擇或 playlist/video prompt 行為。
- 不更動 Safari cookies 匯出格式，除非測試證明此 bug 需要。

## Success Criteria

- live_status = post_live 但 yt-dlp 已提供可下載 formats 時，Tubify 可以開始並完成下載。
- yt-dlp 回傳 This live event has ended. 時，Tubify 顯示可理解的直播處理中狀態或可重試狀態，而不是一般失敗。
- 使用者按下重試後，任務會重新檢查 YouTube 狀態並在回放可用時下載。
- 新增測試覆蓋 metadata 判斷與下載錯誤分類。

## Capabilities

### New Capabilities

- `youtube-post-live-replay`: 定義 YouTube 已結束直播回放在 post_live、暫態錯誤、可下載 manifest 之間的任務狀態與重試行為。

### Modified Capabilities

(none)

## Impact

- Affected code:
  - Modified: Tubify/ViewModels/DownloadManager.swift
  - Modified: Tubify/Services/YouTubeMetadataService.swift
  - Modified: Tubify/Services/YTDLPService.swift
  - Modified: Tubify/Models/DownloadTask.swift
  - Modified: Tubify/Views/DownloadItemView.swift
  - Modified: TubifyTests/DownloadManagerTests.swift
  - Modified: TubifyTests/YouTubeMetadataServiceTests.swift
  - Modified: TubifyTests/YTDLPServiceTests.swift
  - New: TubifyTests/PostLiveReplayTests.swift
  - Removed: (none)
