## Context

目前 `DownloadManager.addURL()` 使用 `YouTubeMetadataService.isPlaylistSync()` 判斷 URL 是否為播放清單（檢查是否包含 `list=`）。一旦判定為播放清單，立即走播放清單流程——建立 placeholder task、抓取元資料、顯示選集 UI。

但許多 YouTube URL 同時包含 `v=`（影片 ID）和 `list=`（播放清單 ID），這類 URL 使用者的意圖不明確，需要先詢問。

## Goals / Non-Goals

**Goals:**

- 偵測同時含 `v=` 和 `list=` 的 URL，彈出對話框詢問使用者意圖
- 提供三個選項：影片、播放清單、取消
- 選擇「影片」時，去除 URL 中的 `list=` 相關參數，走單一影片流程
- 選擇「播放清單」時，走現有播放清單選集流程
- 純播放清單 URL（無 `v=`）維持現有行為

**Non-Goals:**

- 不需要「不再詢問」的記憶功能
- 不需要修改已有的 PlaylistSelectionView

## Decisions

### 使用 callback 模式觸發 UI

沿用現有 `onPlaylistSelectionNeeded` callback 模式，在 `DownloadManager` 新增 `onVideoOrPlaylistChoiceNeeded` callback，由 ContentView 設定並呈現 alert。

**理由**：與現有架構一致（PlaylistSelectionView、MediaSelectionView 都用此模式），不引入新的架構概念。

### URL 參數清理方式

選擇「影片」時，使用 `URLComponents` 移除 `list`、`index`、`t` 以外的播放清單相關 query parameters，保留 `v` 參數。

**理由**：精確控制參數，不會誤刪其他有用的 query parameters。

### 使用 SwiftUI Alert 而非 Sheet

對話框使用 `.alert()` 搭配三個按鈕（影片、播放清單、取消），而非 `.sheet()`。

**理由**：選項簡單（三選一），不需要複雜 UI；alert 更輕量，與 Downie 的體驗類似。

## Risks / Trade-offs

- [風險] 部分 YouTube URL 格式可能不含標準的 `v=` 參數（如短網址 youtu.be）但含 `list=` → 這類情況仍走現有播放清單流程，不受影響
- [權衡] 每次遇到混合 URL 都會彈出詢問 → 使用者明確要求不需要「不再詢問」功能，未來可加
