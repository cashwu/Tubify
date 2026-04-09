## Why

當使用者貼入或拖入一個同時包含 `v=` 和 `list=` 的 YouTube URL 時（例如從播放清單中點開某支影片的連結），目前會直接進入播放清單選集流程。但使用者可能只是想下載那一支影片，而非整個播放清單。應仿照 Downie 的做法，先詢問使用者意圖再決定流程。

## What Changes

- 當 URL 同時包含 `v=` 和 `list=` 時，彈出一個三選一對話框：「影片」、「播放清單」、「取消」
- 選擇「影片」→ 去除 `list=` 參數，走單一影片下載流程
- 選擇「播放清單」→ 走現有播放清單選集流程
- 選擇「取消」→ 不做任何事
- 純播放清單 URL（只有 `list=` 沒有 `v=`）維持現有行為，直接進入播放清單流程

## Capabilities

### New Capabilities

- `playlist-or-video-prompt`: 偵測同時包含影片 ID 與播放清單 ID 的 URL，彈出對話框讓使用者選擇下載模式

### Modified Capabilities

（無）

## Impact

- 受影響的程式碼：
  - `Tubify/ViewModels/DownloadManager.swift` — `addURL()` 需加入分流邏輯
  - `Tubify/Views/ContentView.swift` — 新增對話框呈現與 callback 處理
