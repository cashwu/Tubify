# 手動整合驗證紀錄

驗證日期：2026-07-13

## 已通過

- 原生 Settings：Command-, 連續觸發兩次後仍只有 `Tubify Settings` 一個視窗，主視窗齒輪與標準 shortcut 使用同一 scene。
- 貼上 scope：Settings text area 可接收 Command-V 且主下載列表維持空白；Settings checkbox 為 key-window focus 時 Command-V 不新增任務；主下載視窗貼上一個 URL 後只新增一筆。
- monitor lifecycle：關閉並重啟主視窗後，第二個不同 URL 使任務總數由 1 變 2，沒有漏接或重複新增。驗證過程發現 SwiftUI restoration 會覆寫 `NSWindow.identifier`，修正後重測通過。
- Settings validation：空白 command 顯示「下載指令不可為空」；缺少 `$youtubeUrl` 顯示「下載指令必須包含 $youtubeUrl」；測試後還原原值。
- 含空格資料夾：folder picker 的 `Where:` 顯示 `Tubify Folder With Spaces`，選取後 Settings 顯示 `/private/tmp/Tubify Folder With Spaces`；測試後將使用者 preference 還原為 `/Users/cash/Downloads/tubify`。
- 錯誤呈現：failed row 顯示摘要；啟用「詳細資訊」後 sheet 顯示完整錯誤，並提供「複製」與「關閉」。
- completed row：以隔離 persistence 載入 completed task 後 row 保留，action labels 為「在 Finder 中顯示」與「移除」；啟用 Finder action 後 Finder 開啟 `tmp` 目錄。精確選取路徑另由 `NotificationOutputRouter` 單元測試覆蓋。
- Accessibility：AX tree 確認 toolbar actions「設定」「清除全部」，failed-row actions「重試」「移除」，completed-row actions「在 Finder 中顯示」「移除」皆為 enabled controls；已移除 `.focusable(false)` 的 source scan 通過。
- Recovery／selection lifecycle：跨 session replay、UI 缺席 request 保留、playlist placeholder/child routing、排除狀態零 callback 與部分 batch 移除由 `DownloadManagerTests` 的 observable manager seams 覆蓋。

## 系統限制

- 實際完成通知點擊未能在此 debug 驗證環境完成。已依序嘗試 XCTest host、直接執行 app binary，以及 LaunchServices 啟動的 `Sign to Run Locally` app bundle；macOS 在三種路徑皆拒絕通知授權並記錄 `UNErrorDomain 1`，因此沒有產生可點擊 banner。所有臨時 DEBUG/test harness 均已移除。
- 通知 delegate 初始化時機、有效／缺少／失效 `outputPath` routing、Finder reveal side effect 與 completion handler 恰好一次，均由 `NotificationServiceTests` 自動驗證；本紀錄不宣稱完成真實系統通知點擊。
