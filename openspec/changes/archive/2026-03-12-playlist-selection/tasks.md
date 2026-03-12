## 1. 資料結構與 Callback 機制

- [x] [P] 1.1 新增 `PlaylistSelectionRequest` 結構（播放清單標題、影片列表、佔位任務 ID、callback 資訊），使用 callback 模式觸發選集 UI
- [x] 1.2 在 `DownloadManager` 新增 `onPlaylistSelectionNeeded` callback 屬性，並修改 `expandPlaylist()` — 取得影片列表後觸發 callback 而非直接加入佇列，實現 playlist selection UI 的觸發機制

## 2. 選集 UI

- [x] 2.1 建立 `PlaylistSelectionView`，包含播放清單標題、影片總數、勾選列表（playlist selection UI），預設全選（all videos are selected by default）
- [x] 2.2 實作 select all and deselect all 按鈕功能
- [x] 2.3 實作 download button reflects selection count（顯示已選數量），無選取時 download button is disabled when none selected

## 3. 流程整合

- [x] 3.1 在 `ContentView` 接收 playlist selection callback 並以 sheet 呈現 `PlaylistSelectionView`，實現兩段式 sheet 流程：選集確認後銜接 `MediaSelectionView`（confirm selection triggers media selection flow）
- [x] 3.2 實作 cancel removes placeholder task — 取消時移除佔位任務
- [x] 3.3 處理 media selection fallback for unsupported tracks — 字幕/音軌不支援時使用預設設定，沿用選集資料結構

## 4. 測試

- [x] [P] 4.1 為 `PlaylistSelectionView` 撰寫測試：驗證預設全選、全選/全部取消、選取計數、空選取停用按鈕
- [x] [P] 4.2 為 `DownloadManager` 的修改撰寫測試：驗證播放清單觸發 callback 而非直接加入佇列、取消移除佔位任務
