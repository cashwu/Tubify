## 1. DownloadManager — 偵測與 callback 機制

- [x] 1.1 在 `DownloadManager` 新增 `onVideoOrPlaylistChoiceNeeded` callback，用於觸發 video-or-playlist choice dialog（使用 callback 模式觸發 UI）
- [x] 1.2 在 `addURL()` 中加入邏輯：detect ambiguous playlist-video URL（同時含 `v=` 和 `list=`），觸發 callback 而非直接走播放清單流程
- [x] 1.3 新增 `confirmVideoOrPlaylistChoice()` 方法，處理使用者的選擇結果：影片（strip `list`/`index` 參數，走單一影片流程）、播放清單（走現有流程）、取消（URL 參數清理方式：使用 URLComponents）

## 2. ContentView — 對話框呈現

- [x] 2.1 在 ContentView 設定 `onVideoOrPlaylistChoiceNeeded` callback，使用 SwiftUI Alert 而非 Sheet 呈現 video-or-playlist choice dialog，包含「影片」「播放清單」「取消」三個按鈕
