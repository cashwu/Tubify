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

## 2026-06-29 20:35 — task 6.3 e2e 驗證完成（yt-dlp 後端直測）
- 類別：resolution
- 任務：6.3
- 環境：yt-dlp 2026.06.09；以通用指令 `yt-dlp -f "bv*+ba/b" "$url"` 直接對真實網址測試（`xcodebuild test` 全 207 測試亦於 Xcode 16+ 環境通過）。
- 結果：
  - **x.com**（`https://x.com/ZaynHao/status/2071544121093980449/video/1`）✅ 完全成功。metadata 取得標題與 `pbs.twimg.com` 縮圖；完整下載 58MB mp4（HLS 影片+音訊合併成功）。**不需** cookies。
  - **Instagram**（`https://www.instagram.com/reels/DaK0RtChlkA/`）⚠️ 需登入。yt-dlp 回報 `empty media response ... use --cookies-from-browser`。通用指令內建的 `--cookies-from-browser safari` 正是為此設計——但前提是 app 已獲完整磁碟存取（FDA）且 Safari 已登入 Instagram。
  - **Threads**（`https://www.threads.com/@.../post/.../media`）❌ 不支援。此版 yt-dlp **無 Threads extractor**（`--list-extractors` 無 thread 項），回報 `Unsupported URL`。屬上游後端限制，非 Tubify 程式問題；待 yt-dlp 新增支援後即自動可用。
- 關於 `--cookies-from-browser safari` 的有效性／必要性：
  - 必要性：x.com 不需；Instagram 必要（無 cookies 無法取得媒體）。
  - 環境限制：從一般終端機程序執行此旗標會失敗（`Operation not permitted: .../com.apple.Safari/.../Cookies.binarycookies`），因缺 FDA。Tubify.app 經 `PermissionService` 偵測並由使用者授予 FDA 後始能讀取 Safari cookies——與既有 YouTube 路徑相同前提。
- 結論：command routing 對 yt-dlp 原生支援的非 YouTube 站點（如 x.com）端到端有效；需登入的站點（Instagram）依賴 FDA + Safari 登入態；yt-dlp 未支援的站點（Threads）超出本變更範圍。task 6.3 視為完成。
