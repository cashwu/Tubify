## Why

目前貼上播放清單 URL 時，所有影片會自動加入下載佇列，使用者無法選擇只下載部分影片。對於大型播放清單（數十甚至上百集），這會造成不必要的下載，使用者需要事後手動刪除不想要的任務。

## What Changes

- 播放清單展開後，彈出選集視窗讓使用者勾選要下載的影片
- 選集視窗預設全選，並提供「全選」與「全部取消」按鈕
- 確認選集後，接續現有的字幕/音軌選擇流程，再將已選影片加入佇列
- 取消選集則移除佔位任務，不進行任何下載
- 字幕/音軌設定統一套用到所有已選影片，個別影片不支援時自動 fallback

## Capabilities

### New Capabilities

- `playlist-selection`: 播放清單選集功能，包含選集 UI、全選/全部取消操作、與現有下載流程的整合

### Modified Capabilities

（無）

## Impact

- 受影響的程式碼：
  - `Tubify/ViewModels/DownloadManager.swift` — 修改 `expandPlaylist()` 流程，改為觸發選集 callback 而非直接加入佇列
  - `Tubify/Views/ContentView.swift` — 新增 sheet 呈現選集視窗，串接選集 → 字幕/音軌選擇的兩段式流程
  - 新增 `Tubify/Views/PlaylistSelectionView.swift` — 選集視窗 UI
