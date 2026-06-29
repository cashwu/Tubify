<!-- apply-plus implementation notes | change: route-download-command-by-site | initialized: 2026-06-29 09:23 | no entries below means no deviations or open questions were recorded -->

## 2026-06-29 09:23 — 測試置於既有檔案而非新檔
- 類別：deviation
- 任務：6.1
- 內容：task 6.1 的單元測試置於既有的 `TubifyTests/DownloadManagerTests.swift`（重用其 setUp 注入的 `manager` 真實 `DownloadManager` 實例直接呼叫 `effectiveDownloadCommand(for:)`），而非新建測試檔。task 6.2 的 spy 測試同樣加入此檔並擴充既有 `MockYTDLPService` 捕捉 `commandTemplate`。
- 原因：`Tubify.xcodeproj` 未使用 file-system-synchronized groups（`PBXFileSystemSynchronizedRootGroup` 計數為 0），測試檔以明確 file reference 列入。新建檔案需 `xcodegen generate` 重新產生整個 project.pbxproj，屬非必要的較大改動；置於既有已納入的測試檔可達成「@testable import 呼叫真實方法」的目標，且符合 Surgical Changes 紀律。

## 2026-06-29 09:23 — task 6.3 手動 e2e 待使用者驗證
- 類別：open-question
- 任務：6.3
- 內容：task 6.3 需以實際 x.com 與 Instagram 公開貼文網址跑端到端下載、確認 metadata（標題、縮圖）與通用指令可成功，並記錄 `--cookies-from-browser safari` 對這些網站是否有效／必要。此環境無法執行 app（亦無法執行 `xcodebuild`，active 為 Xcode 15.4，專案為 format 77 需 Xcode 16+）。
- 原因：屬實機手動驗證，需使用者在自己的 Xcode 16+ 環境完成；保留為未完成（[ ]）。所有程式碼任務（1.1–6.2）已實作完成，但 `xcodebuild test` 亦需由使用者執行。
