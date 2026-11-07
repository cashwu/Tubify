# Tubify TDD 開發規範

文件狀態：Active

## 1. 適用範圍

本規範適用於 `Models`（`DownloadTask`、`AppSettings` 等資料與狀態）、`Services`（`YTDLPService` 的指令組裝、進度與錯誤解析、重試與取消，`YouTubeMetadataService` 的元資料與媒體選項解析，`PersistenceService`、`SafariCookiesService` 等）、`Utilities`（例如 `PremiereErrorParser`），以及 `ViewModels/DownloadManager` 的佇列與狀態轉換。

`Views` 中的純 SwiftUI 排版不強制執行 Red／Green 單元測試循環，以 SwiftUI Preview 與手動驗收為主。但**凡涉及 URL 判斷與分流、下載指令組裝、重試／取消、任務狀態轉換、設定輸入驗證**的邏輯，必須抽離至 ViewModel、Service 或 Model 並依本規範執行 TDD；修正 UI 互動 Bug 時，仍須先補上能重現問題的測試。

## 2. 基本原則

所有功能開發與錯誤修正皆採用 TDD（Test-Driven Development），依序重複以下循環：

1. **Red**：先寫一個描述預期行為的測試，執行並確認它因尚未實作該行為而失敗（若因型別或方法未定義而無法編譯，先補齊最小介面空殼，推進至「可編譯但斷言失敗」才算完成 Red）。
2. **Green**：只撰寫足以讓測試通過的最小實作，不提前加入尚未被測試要求的功能。
3. **Refactor**：在測試持續通過的前提下整理程式碼、消除重複，避免改變既有行為。

每次循環只處理一個小而明確的行為，完成後再進入下一個循環。

## 3. 實施規則

* 新增產品程式碼前，必須先有一個會失敗的測試。
* 修正 Bug 前，必須先新增一個能重現問題的回歸測試（Regression Test）。
* 測試應只驗證一個明確行為，名稱需能表達情境、輸入條件與預期結果。
* 測試必須可重複執行，且不依賴測試順序、外部網路狀態或其他測試留下的檔案與設定。
* **日常測試必須 100% 離線且零外部副作用**：不得執行真實的 yt-dlp、連線 YouTube 或其他網站、讀取 Safari cookies，也不得讀寫真實的任務持久化目錄（`~/Library/Application Support/Tubify/`）、日誌目錄、`~/Downloads/` 或使用者的 `UserDefaults.standard`。
* **透過可注入介面隔離外部邊界**：
  * yt-dlp 執行檔：`YTDLPService(ytdlpPathProvider:)` 指向測試暫時目錄中的 shell script fixture，由 fixture 記錄 argv、模擬輸出、失敗與長時間執行（參考 `YTDLPServiceTests` 的 `YTDLPFixture`）。
  * `DownloadManager`：以 `init(persistenceService:metadataService:ytdlpService:notificationService:fileInspector:)` 注入 `MockPersistenceService` 與各服務的 mock。
  * 設定：使用 `UserDefaults(suiteName:)` 建立獨立 suite，測試結束移除；檔案使用 `FileManager.default.temporaryDirectory` 下的唯一目錄，測試結束刪除。
  * 時間、延遲（例如重試 backoff）：注入可控制的替代實作，不在測試中真的等待正式秒數。
* **下載流程必須驗證成功、失敗與取消路徑**：涉及下載、重試、cookies 退路或清理的修改，要涵蓋成功、yt-dlp 失敗與使用者取消；取消時確認子程序確實結束、不再啟動下一次 attempt，且任務沒有被呈現為失敗或完成。
* 斷言必須能在實作寫錯時失敗：寫完測試後，確認錯誤實作（例如移除剛加入的判斷）會讓測試變紅；測試的 setup 不能讓目標條件在更早的分支就被排除。常見陷阱見 [review-signals.md](review-signals.md)「測試與驗證設計」。
* 每次修改後執行相關測試；提交前必須執行完整測試。
* 不得以刪除、略過（`XCTSkip`）或放寬有效測試斷言的方式讓實作通過。

## 4. 基本驗證指令

scheme 與 target 名稱以 `Tubify.xcodeproj`（或 `project.yml`）為準；改變時同步更新本節。

執行完整測試：

```sh
xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'
```

執行單一測試類別或方法：

```sh
xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' \
  -only-testing:TubifyTests/DownloadManagerTests
```

打包前的完整檢查（測試 + 建置 + DMG）：

```sh
./Scripts/package-app.sh
```

### 在 T3 Code 等工具內執行測試

部分開發工具會探測子行程新開的 loopback port。測試若開本機 listener，可能收到非自己 client 的請求；假端點應只認自己登記過的路徑或 client，不要假設每條連線都來自受測程式碼。

### 手動驗收

以下行為無法以離線測試證明，依變更內容手動驗收：

* 真實 YouTube／其他網站下載，以及 yt-dlp 版本更新後的輸出格式。
* Safari cookies 讀取與完整磁碟存取權限提示。
* macOS 通知、URL Scheme（Whispify 整合）與 Finder 顯示。
* 視窗尺寸、可存取性與實際操作手感。

手動驗收的結果（通過／不通過與實際觀察）記錄在該次變更的設計文件或 commit 說明；未執行時在回報中列為未執行，不宣稱已通過。

## 5. 完成條件

一項修改至少符合以下條件，才視為完成：

* 新增或調整的行為已有測試保護（下載流程已涵蓋成功、失敗與取消路徑）。
* 新增的測試曾先以預期原因失敗，完成實作後通過。
* 所有既有測試皆通過，執行期間沒有啟動真實 yt-dlp、連線外部網路或寫入使用者的真實資料。
* 建置沒有新增編譯警告。
* 未將 `Process` 執行、檔案系統操作或 JSON 編解碼放進 SwiftUI View。
* 行為改變時已同步更新 `docs/specs/` 對應規格；需要手動驗收的項目已執行或明確列為未執行。
