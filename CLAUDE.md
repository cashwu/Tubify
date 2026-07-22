
<!-- CASH:START -->

# Cash Project Guidance

本專案只使用 Cash workflow invocations。Spectra CLI 與 `openspec/` artifact schema 仍具權威；Cash skills 會繼續使用 `spectra` commands 與 `openspec/` artifacts。標準 `spectra-*` skills 是否存在不改變 Cash-only routing。

- 結構化討論 → `/cash-discuss`
- 規劃或提出變更 → `/cash-propose`
- 實作或繼續 tasks → `/cash-apply`
- 實作期間需求變更 → `/cash-ingest`，再繼續 `/cash-apply`
- 封存完成的變更 → `/cash-archive`
- 提交單一選定變更 → `/cash-commit`

有效 workflow：`/cash-discuss`? → `/cash-propose` → `/cash-apply` ⇄ `/cash-ingest` → `/cash-archive` → `/cash-commit`。

## 向量模型未下載時的替代方式

Spectra 的語意搜尋依賴本機向量模型。若模型尚未下載，不需要中斷或要求先下載，直接改用路徑與檔案讀取：

- 使用者直接給 change 名稱 → 直接讀 `openspec/changes/<name>/` 底下的 artifacts（找不到時用 `spectra list --parked` 確認是否被 parked）
- 問程式碼或需求相關的問題 → 直接用 Grep／Read 搜尋 `openspec/specs/` 與程式碼來回答

<!-- CASH:END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

Tubify 是一款使用 SwiftUI 開發的 macOS YouTube 影片下載器，以 yt-dlp 作為下載後端。支援拖放 URL、播放清單展開、並行下載及任務持久化。

## 建置與執行

這是一個 Xcode 專案，開啟 `Tubify.xcodeproj` 即可建置與執行。

- **最低部署版本**：macOS 14.0 (Sonoma)
- **Swift 版本**：5.9
- **外部依賴**：需安裝 yt-dlp（`brew install yt-dlp`）

另有 `project.yml` 可搭配 XcodeGen 重新產生專案檔。

### 常用指令

```bash
# 執行測試
xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'

# 執行單一測試
xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' -only-testing:TubifyTests/DownloadTaskTests

# 打包發佈（測試 + 建置 + DMG）
./Scripts/package-app.sh

# 快速打包（跳過測試）
./Scripts/package-app.sh --skip-tests
```

## 架構

### MVVM 模式

- **Models**（`Tubify/Models/`）：資料結構
  - `DownloadTask`：Observable 類別，代表一個下載任務，包含狀態、進度、元資料
  - `AppSettings`：UserDefaults 鍵值與預設設定

- **ViewModels**（`Tubify/ViewModels/`）：
  - `DownloadManager`：單例（`@MainActor`），管理下載佇列，支援 1-5 個並行下載

- **Views**（`Tubify/Views/`）：SwiftUI 視圖，包含主視窗、下載項目、設定頁面、空白狀態

- **Services**（`Tubify/Services/`）：
  - `YTDLPService`：Actor，封裝 yt-dlp 程序執行與進度解析
  - `YouTubeMetadataService`：透過 yt-dlp JSON 輸出獲取影片/播放清單元資料
  - `PersistenceService`：JSON 格式的任務持久化，儲存於 `~/Library/Application Support/Tubify/`
  - `NotificationService`：macOS 使用者通知
  - `PermissionService`：偵測完整磁碟存取權限（用於讀取 Safari cookies）

### 關鍵設計模式

- 使用 `@Observable` 巨集管理 SwiftUI 狀態（非 ObservableObject）
- Services 為單例模式，使用 `actor`（YTDLPService）或帶有 `shared` 靜態屬性的類別
- 設定儲存於 `UserDefaults`，鍵值定義在 `AppSettingsKeys`
- yt-dlp 指令模板使用 `$youtubeUrl` 作為 URL 佔位符

### 資料流程

1. URL 拖放/貼上 → `DownloadManager.addURL()`
2. 透過 `YouTubeMetadataService` 獲取元資料（播放清單會展開為個別影片）
3. 任務加入佇列，由 `DownloadManager.processQueue()` 處理（可設定並行數量）
4. `YTDLPService.download()` 啟動 yt-dlp 程序，從 stdout 解析進度
5. 狀態與進度更新透過 `@Observable` 綁定反映至 UI

## 檔案位置

- **日誌**：`~/Library/Logs/Tubify/`
- **任務持久化**：`~/Library/Application Support/Tubify/`
- **預設下載目錄**：`~/Downloads/`

## 開發流程

每次完成需求開發後，必須執行以下步驟：

1. **程式碼審查**：使用 `code-reviewer` agent 審查當次修改的程式碼
2. **程式碼簡化**：使用 `code-simplifier` agent 確認是否有更簡潔的寫法
