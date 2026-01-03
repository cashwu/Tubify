# Tubify

一款簡潔的 macOS YouTube 影片下載器，使用 yt-dlp 作為後端。

## 系統需求

- macOS 14 (Sonoma) 或更新版本
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) 已安裝

## 安裝 yt-dlp

使用 Homebrew 安裝：

```bash
brew install yt-dlp
```

或使用 pip：

```bash
pip install yt-dlp
```

## 建立 Xcode 專案

1. 打開 Xcode
2. 選擇 **File → New → Project**
3. 選擇 **macOS → App**
4. 設定：
   - Product Name: `Tubify`
   - Team: 你的開發團隊（或 None）
   - Organization Identifier: `com.yourname`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - 取消勾選 "Include Tests"

5. 選擇專案儲存位置（可以是這個目錄的父目錄）

6. 刪除 Xcode 自動建立的檔案（ContentView.swift、TubifyApp.swift 等）

7. 將 `Tubify/` 資料夾中的所有 `.swift` 檔案拖入 Xcode 專案

8. 在專案設定中：
   - **General → Deployment Info → Minimum Deployments**: 設為 macOS 14.0
   - **Signing & Capabilities**:
     - 關閉 App Sandbox（或根據需要配置）
     - 新增 "Network" capability（Client）

9. Build and Run!

## 功能

- **拖放下載**：直接拖 YouTube 連結到視窗即可加入下載佇列
- **播放清單支援**：自動展開播放清單為多個獨立下載任務
- **自訂下載指令**：在設定中自訂 yt-dlp 指令
- **下載間隔**：設定每個下載之間的等待時間
- **任務持久化**：App 重啟後自動恢復未完成的下載
- **系統通知**：下載完成時發送通知
- **縮圖預覽**：顯示影片縮圖

## 設定選項

- **下載指令**：預設為 `yt-dlp -f mp4 --cookies-from-browser safari "$youtubeUrl"`
  - 使用 `$youtubeUrl` 作為 URL 佔位符
- **下載資料夾**：預設為 `~/Downloads`
- **下載間隔**：預設為 2 秒

## 檔案結構

```
Tubify/
├── TubifyApp.swift                # App 入口
├── Models/
│   ├── DownloadTask.swift         # 下載任務模型
│   └── AppSettings.swift          # 設定常數
├── ViewModels/
│   └── DownloadManager.swift      # 下載管理邏輯
├── Views/
│   ├── ContentView.swift          # 主視窗
│   ├── DownloadItemView.swift     # 單個下載項目
│   ├── EmptyStateView.swift       # 空白狀態
│   └── SettingsView.swift         # 設定頁面
├── Services/
│   ├── YTDLPService.swift         # yt-dlp 指令執行
│   ├── YouTubeMetadataService.swift # 獲取影片資訊
│   ├── NotificationService.swift  # 系統通知
│   └── PersistenceService.swift   # 任務持久化
└── Utilities/
    └── Logger.swift               # 日誌工具
```

## 日誌位置

日誌檔案儲存在：`~/Library/Logs/Tubify/`

任務資料儲存在：`~/Library/Application Support/Tubify/`

## 授權

MIT License
