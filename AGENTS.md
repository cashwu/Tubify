

本專案所有面向使用者的回覆一律以繁體中文撰寫，除非使用者明確要求其他語言。shell 指令、檔案路徑、程式識別字、schema 欄位名與引用原文逐字保留。

規格、測試規則與開發紀錄放在 `docs/`（索引見 [docs/README.md](docs/README.md)）：

- [docs/specs/](docs/specs/README.md)：目前生效的功能規格（Requirement + Scenario），實作與測試的依據。
- [docs/tdd.md](docs/tdd.md)：Red／Green／Refactor 循環、離線測試隔離規則、驗證指令與完成條件。
- [docs/review-signals.md](docs/review-signals.md)：review 反覆抓到的缺陷類型，撰寫規格與測試時當檢查清單。
- [docs/design/](docs/design/README.md)、[docs/completed-tasks.md](docs/completed-tasks.md)：過去變更的設計決策與完成紀錄，只在追溯「為什麼這樣做」時查閱。

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

## 不可違反的設計約束

以下是跨功能的核心行為，細節與完整 scenario 以 `docs/specs/` 為準。若需求與約束衝突，先停下來向使用者確認，不要自行放寬。

- **指令模板**：下載指令必須含 `$youtubeUrl` 佔位符；非 YouTube 網站使用固定的通用指令常數，播放清單展開、提示與縮圖等 YouTube 專屬處理只套用於 YouTube（`multi-site-download`）。
- **HTTP 403 重試**：只對 video-data HTTP 403 重新執行完整 yt-dlp process，有界次數與固定 backoff；不得改用 yt-dlp `--retries` 取代，403 本身不得觸發 Safari cookies 退路（`download-reliability`）。
- **取消優先**：使用者取消優先於任何剩餘 retry 或 cookies 退路，取消後不得再啟動 yt-dlp process，也不得把任務呈現為失敗（`download-reliability`）。
- **cookies 最小化**：媒體選項查詢先不帶 cookies，只有在「需登入」時才帶 cookies 重試一次（`subtitle-selection`）。
- **清理不得傷害使用者檔案**：孤兒中間檔清理只刪符合條件的一般檔案，不跟隨 symbolic link，不刪目錄，也不得改變下載結果或拋出錯誤（`download-reliability`）。
- **並行模型**：`DownloadManager` 維持 `@MainActor`，`YTDLPService` 維持 `actor`；`Process` 執行、檔案系統與 JSON 編解碼不放進 SwiftUI View。

## 開發流程

### TDD

適用於 Models、Services、Utilities 與 `DownloadManager` 的狀態邏輯，完整規範見 [docs/tdd.md](docs/tdd.md)；純 SwiftUI View 排版以 Preview 與手動驗收為主。

1. **Red**：先寫測試，實際執行並確認它以預期原因失敗（型別未定義無法編譯時，先補最小介面空殼至「可編譯但斷言失敗」）。
2. **Green**：只寫足以通過測試的最小實作。
3. **Refactor**：測試保持通過的前提下整理程式碼。

- 修 Bug 前必須先有能重現問題的回歸測試。
- 日常測試必須離線且零外部副作用：不執行真實 yt-dlp、不連網、不碰真實的持久化目錄與 `UserDefaults.standard`，改用注入的 fixture 與 mock。
- 不得以刪除、略過或放寬斷言的方式讓測試通過。

### 完成後的檢查

每次完成需求開發後，必須執行以下步驟：

1. **程式碼審查**：使用 `code-reviewer` agent 審查當次修改的程式碼
2. **程式碼簡化**：使用 `code-simplifier` agent 確認是否有更簡潔的寫法

回報時列出執行過的測試與結果；未執行的檢查與手動驗收要明確列為未執行，不宣稱已通過。

## 文件同步

文件是契約的一部分，行為變更必須在同一次修改中同步文件：

- 功能行為、錯誤分類或使用者可見流程改變 → 更新 `docs/specs/` 對應規格與其「對應程式碼」。
- 測試指令、scheme 或測試隔離方式改變 → 更新 `docs/tdd.md`。
- 頂層目錄、架構或資料流程改變 → 更新本文件。

### 維護本文件

本文件每個 session 都會完整載入，只放跨任務穩定、且無法從程式碼或其他文件直接取得的資訊。

- 詳細規格放 `docs/specs/`，測試細節放 `docs/tdd.md`，不在多份文件重複；本文件以連結指回。
- 修改規則時直接寫成現行規則，不寫「改為」「不再」等相對舊版的描述，也不留修改歷史。
- 新增規則前，確認它適用於多數任務，而不是只為了避免某一次的錯誤；規則附上原因。
- 本文件的「不可違反的設計約束」與 `docs/tdd.md` 的「完成條件」只能在使用者明確要求時修改，不得為了完成任務自行放寬。

## 註解撰寫

註解使用繁體中文，技術名詞與識別字維持英文。註解說明程式碼本身無法表達的「為什麼」、必須維持的條件與刻意不處理的情況，不逐行翻譯程式碼。

測試註解只補充測試名稱無法表達的資訊，需要時依序說明：驗證目的（違反時會造成什麼錯誤）、案例設計（特定資料或步驟代表的行為）、特殊順序（順序影響語意時）、證據邊界（例如 fixture 不能證明真實 yt-dlp 的行為）。不要誇大測試涵蓋範圍。

## Commit 慣例

Conventional Commits 格式，描述使用繁體中文。scope 可省略；需要時依主要變更位置使用 `models`、`services`、`viewmodels`、`views`、`tests`、`docs`。

```text
feat: 支援 YouTube 自動字幕（繁體中文、英文）選項
fix(services): 修正取消下載後仍啟動 403 重試的問題
test(viewmodels): 補上完成任務自動移除設定的回歸測試
docs: 規格補上媒體選擇視窗高度
```
