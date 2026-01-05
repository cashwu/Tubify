# Tubify

一款簡潔的 macOS YouTube 影片下載器，使用 yt-dlp 作為後端。

## 系統需求

- macOS 14 (Sonoma) 或更新版本
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) 已安裝
- [ffmpeg](https://ffmpeg.org/)（選用，用於合併高畫質影音串流）
- 完整磁碟存取權限（選用，用於讀取 Safari cookies 下載需要登入的影片）

> **注意**：由於 App 使用 ad-hoc 簽署，每次透過 DMG 更新後需要重新授權完整磁碟存取權限。這是 macOS 安全機制的限制。

## 安裝 yt-dlp

使用 Homebrew 安裝：

```bash
brew install yt-dlp
```

或使用 pip：

```bash
pip install yt-dlp
```

## 安裝 ffmpeg（選用）

```bash
brew install ffmpeg
```

## 建置與執行

直接開啟 `Tubify.xcodeproj` 即可建置與執行。

如需重新產生專案檔，可使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
xcodegen generate
```

## 功能

- **拖放下載**：直接拖 YouTube 連結到視窗即可加入下載佇列
- **播放清單支援**：自動展開播放清單為多個獨立下載任務
- **並行下載**：支援同時下載 1-5 個影片
- **高畫質支援**：預設格式支援最高 4K 畫質（需要 ffmpeg）
- **自訂下載指令**：在設定中自訂 yt-dlp 指令
- **Safari Cookies 整合**：自動使用 Safari cookies 下載需要登入的影片
- **首播影片支援**：自動偵測並排程首播影片
- **任務持久化**：App 重啟後自動恢復未完成的下載
- **系統通知**：下載完成或失敗時發送通知
- **縮圖預覽**：顯示影片縮圖

## 設定選項

- **下載指令**：預設為 `yt-dlp -f "bv[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" --cookies-from-browser safari "$youtubeUrl"`
  - 使用 `$youtubeUrl` 作為 URL 佔位符
  - 預設格式支援高畫質下載（最高可達 4K，需要 ffmpeg 合併影音串流）
- **下載資料夾**：預設為 `~/Downloads`
- **同時下載數量**：可設定 1-5 個並行下載，預設為 2

## 檔案結構

```
Tubify/
├── TubifyApp.swift                  # App 入口
├── Models/
│   ├── DownloadTask.swift           # 下載任務模型
│   └── AppSettings.swift            # 設定常數
├── ViewModels/
│   └── DownloadManager.swift        # 下載管理邏輯
├── Views/
│   ├── ContentView.swift            # 主視窗
│   ├── DownloadItemView.swift       # 單個下載項目
│   ├── EmptyStateView.swift         # 空白狀態
│   └── SettingsView.swift           # 設定頁面
├── Services/
│   ├── YTDLPService.swift           # yt-dlp 指令執行
│   ├── YouTubeMetadataService.swift # 獲取影片資訊
│   ├── NotificationService.swift    # 系統通知
│   ├── PersistenceService.swift     # 任務持久化
│   ├── PermissionService.swift      # 完整磁碟存取權限偵測
│   └── SafariCookiesService.swift   # Safari Cookies 代理服務
└── Utilities/
    ├── Logger.swift                 # 日誌工具
    └── PremiereErrorParser.swift    # 首播錯誤解析工具

TubifyTests/                         # 單元測試
├── DownloadTaskTests.swift
├── YouTubeMetadataServiceTests.swift
├── URLValidationTests.swift
├── YTDLPServiceTests.swift
└── PremiereErrorParserTests.swift
```

## 日誌位置

日誌檔案儲存在：`~/Library/Logs/Tubify/`

任務資料儲存在：`~/Library/Application Support/Tubify/`

## 授權

本專案採用 MIT 授權條款 - 詳情請參閱 [LICENSE](LICENSE) 檔案。
