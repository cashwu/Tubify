## Context

`DownloadManager.downloadSingleTask` 對每個 queue task 只呼叫一次 `YTDLPService.download`，並在該呼叫拋錯後才把 task 標記為 failed、保存錯誤與發送失敗通知。`YTDLPService.download` 目前先移除 Safari cookies 執行 `executeDownload`，只有錯誤包含明確登入訊號時才以 cookies 再執行一次。`executeDownload` 每次都建立新的 yt-dlp `Process`，但 process 因直接 `HTTP Error 403: Forbidden` 結束時沒有應用層重試。

這個 change 不建立新服務或新 queue 狀態模型；重試接縫仍由 `YTDLPService` 擁有。`YTDLPService` 同時掌握 process 邊界、yt-dlp 原始錯誤、cookies 模式與 operation cancellation identity，能在不讓 queue layer 看見中間失敗的前提下重新執行完整下載。

## Goals / Non-Goals

Goals：

- 對精確分類出的下載 HTTP 403 執行最多 3 次額外完整 process 重試。
- 使用固定 2、5、10 秒 backoff，讓暫時性媒體 URL／CDN 授權狀態有恢復時間。
- 每次重試重新執行 `executeDownload`，重新解析頁面、格式與媒體 URL，同時保留 yt-dlp `.part` 續傳能力。
- 中間 403 不離開 `YTDLPService.download`，因此 task 維持 downloading，且不觸發 failed 持久化或失敗通知。
- 取消在 active process 或 backoff 期間都能終止整體操作；backoff 在完成當前不超過 100 ms 的 sleep slice 後觀察取消，且不再啟動下一個 process。
- 同一 `taskId` 的新 operation 不得清除或誤讀舊 operation 的取消狀態；舊 operation 必須在下一個 process 前辨識為 stale 並停止。
- 以直接驅動 production download-flow helper 的測試驗證 success、exhaustion、non-target error、cookies fallback 與 cancellation branches。
- 以可控 yt-dlp executable fixture 驗證 production `executeDownload`、`Process.terminate()` 與 process cleanup。

Non-Goals：

- 不處理 impersonation、PO Token、yt-dlp 安裝或版本管理。
- 不重試 HTTP 429、5xx 或其他 yt-dlp 錯誤。
- 不新增 `DownloadTask` 欄位、持久化 schema、設定 UI 或 queue 狀態。
- 不改變 cookies fallback 的登入訊號分類與模板轉換。

## Decisions

### 1. 重試整個 `executeDownload`，不修改 yt-dlp CLI retry flags

每個 retry attempt 必須再次呼叫 `executeDownload`，由它建立新的 yt-dlp process。這與使用者手動重新下載的有效機制一致，能重新取得格式及媒體 URL。不得以新增 `--retries`、重用上一個 direct media URL 或只恢復同一 HTTP request 取代。

### 2. 使用窄分類與固定 retry policy

新增一個可由測試存取的內部分類 helper，只有下列條件全部成立才回傳 true：

- error 是 `YTDLPError.executionFailed`；
- message 包含逐字片段 `unable to download video data: HTTP Error 403: Forbidden`；
- message 不包含 `Giving up after`。

Policy 為 initial attempt 加上 3 次 retries；三次 retry 前分別等待 2、5、10 秒。attempt exhaustion 後原樣拋出最後一個 `YTDLPError`。其他 error type 或 message 立即原樣拋出。

此 policy 對 `YTDLPService` 處理的下載網址一致生效，不新增 YouTube host 分支。它以直接 video-data 錯誤 contract 而非站點名稱決定是否恢復；webpage、subtitle、fragment downloader 與 `Giving up after` context 不在分類範圍，即使同一訊息也含有 target 403 片段。17 秒只是 Tubify 的總 backoff，不限制每個 yt-dlp process 的執行時間或內部 HTTP request 數。

### 3. cookies mode 各自包在同一 retry 接縫內

不帶 cookies 的 first template 透過 `executeDownloadFlow` 內的 target-403 retry path 執行。只有該整體操作最終拋出既有 `shouldRetryWithCookies` 認得的登入錯誤時，才建立 cookie template 並透過同一 flow 執行。單純 target 403 不得切換 cookies mode；同一組 target-403 retries 中的 command template 必須保持不變。

### 4. 以 DownloadOperationID 隔離取消與 retry

每次 `download` 呼叫建立唯一的 `DownloadOperationID`，並在 `activeDownloadOperations[taskId]` 記錄目前 operation。`executeDownloadFlow`、backoff waiter 與 `executeDownload` 都攜帶該 identity；取消檢查只在 operation 仍是該 task 的 active operation 且未被標記取消時通過。

`cancel(taskId:)` 解析該 task 的 active operation，標記該 operation 已取消並終止其 active process。新 operation 開始時，若同一 `taskId` 已有舊 operation，先標記舊 operation stale、終止舊 process，再取代 active identity。舊 operation 在每個 slice 後、每次 operation 前與 `process.run()` 前都必須因 identity 不再 active 而拋出 `YTDLPError.cancelled`，不得啟動下一個 process；新 operation 的取消不得被舊 operation 清除或誤讀。

Waiter 必須使用 async sleep，不可使用 blocking wait。Actor 在 slice sleep 期間可 re-enter `cancel(taskId:)`，而 `DownloadOperationID` 提供 operation-level isolation，不需要 Swift `Task` registry、continuation 或額外 synchronization primitive。測試接縫可以注入受控的 slice sleeper，以免測試實際等待 17 秒，並驗證取消在完成當前不超過 100 ms 的 slice 後被觀察。

### 5. Production download-flow helper 是唯一 orchestration path

在 `Tubify/Services/YTDLPService.swift` 內建立最小的 internal `executeDownloadFlow` helper；production `download` 與 `TubifyTests/YTDLPServiceTests.swift` 都必須呼叫同一 helper。此接縫包含 first processed template、403 retry、`shouldRetryWithCookies`、cookie-template provider 與第二條 403 retry 的真實分支，而不只包裝內層 retry loop。

Helper 允許測試注入 scripted attempt executor、cookie-template provider、slice sleeper 與 cancellation probe，藉此使用 sentinel templates 直接驗證實際 attempt count、delay sequence、登入錯誤後的 template 切換、單純 403 不切換 cookies、取消、回傳值與最後錯誤。測試不得複製 production retry 或 cookies fallback loop。另以可控 yt-dlp executable fixture 透過 production `download` path 驗證 active `Process` 的終止、operation cancellation 與 cleanup；fixture 只供測試建立與清理，不改變 production command template 或 CLI flags。

不新增獨立 module、protocol 或第三方依賴。分類、policy 與 orchestration 都留在既有 service 檔案，避免只有 forwarding 行為的新 abstraction。

### 6. 日誌與 task 可觀察狀態

每次即將 retry 時以 `TubifyLogger.ytdlp` 記錄 task ID、目前 retry number、最大 retries 與 delay。既有 process stderr 與最終成功／失敗日誌保留。`DownloadManager` 不變，因此中間 target 403 不會把 task 轉為 failed 或發送失敗通知；只有 `executeDownloadFlow` 最後拋錯才沿用既有 final failure path。

## Implementation Contract

- `Tubify/Services/YTDLPService.swift` SHALL 定義單一 403 retry policy，其 delays 精確為 2、5、10 秒，最多執行 1 次 initial attempt 與 3 次 retry attempts。
- 403 分類 SHALL 僅接受 `YTDLPError.executionFailed` message 中的 `unable to download video data: HTTP Error 403: Forbidden`，且 message MUST NOT contain `Giving up after`；其他 403 context、其他 `YTDLPError` 與其他 HTTP status MUST NOT retry。
- Production 下載 SHALL 透過可測試的 internal `executeDownloadFlow` helper 反覆呼叫既有 `executeDownload`；每個 attempt SHALL 建立新的 yt-dlp process，且同一組 attempts SHALL 使用相同的 processed command template。
- 不帶 cookies 與帶 cookies 兩條 `executeDownload` 路徑 SHALL 各自使用同一 helper；HTTP 403 本身 MUST NOT 觸發 cookies fallback，既有 `shouldRetryWithCookies` contract MUST 保持不變。
- 每個 `download` operation SHALL 建立唯一 `DownloadOperationID`；`activeDownloadOperations` SHALL 將 task ID 綁定到目前 operation，`cancel(taskId:)` SHALL 只標記並終止該 active operation。新 operation 取代同一 task 的舊 operation 時，舊 operation SHALL 被標記 stale 並在下一個 process 前停止。
- Backoff SHALL 以最長 100 ms async sleep slices 觀察 task cancellation；`executeDownloadFlow` SHALL 在 slice 後與 operation 前檢查 operation identity，`executeDownload` SHALL 在 `process.run()` 前拒絕已取消或 stale operation。取消或 stale operation SHALL 在完成當前不超過 100 ms 的 sleep slice 後拋出 `YTDLPError.cancelled` 並停止所有後續 attempts。
- Intermediate 403 SHALL NOT 回傳到 `DownloadManager`。Success SHALL 回傳既有 output path；exhaustion SHALL 原樣拋出最後一個 403 error；non-403 SHALL 在第一次失敗後立即原樣拋出。
- Retry SHALL NOT 刪除 yt-dlp 產生的 `.part` 檔，讓下一個新 process 沿用 yt-dlp 的既有續傳行為。
- `TubifyTests/YTDLPServiceTests.swift` SHALL 直接測試 production classification 與 `executeDownloadFlow`，至少覆蓋：第一次 target 403 後成功、三次 retries 後成功、四次 attempts 全部 target 403、其他 403 context 與 non-403 不重試、單純 403 不切換 cookies、login error 切換 cookie template、cancelled 不重試、backoff 中取消在完成當前不超過 100 ms 的 sleep slice 後停止且不啟動下一個 process，以及 2、5、10 秒 delay sequence。
- `TubifyTests/YTDLPServiceTests.swift` SHALL 額外覆蓋：同時含 target 403 與 `Giving up after` 的錯誤不重試、同一 task 的新 operation 不受舊 cancellation state 影響、舊 operation 不得在新 operation 開始後啟動 process，以及透過可控 yt-dlp executable fixture 驅動 production `download` path 的 active process termination、`cancel(taskId:)` 傳遞與 process cleanup。
- 不得修改 `Tubify/ViewModels/DownloadManager.swift`、`Tubify/Models/DownloadTask.swift`、`Tubify/Models/AppSettings.swift` 或任何下載命令預設值。

## Risks / Trade-offs

- 永久 target 403 的 final failure 增加 17 秒 Tubify backoff，但整體時間仍包含每個 yt-dlp process 的執行時間。以精確錯誤分類與固定 3 次上限換取對暫時性錯誤的自動恢復。
- 多個並行下載同時遇到 403 時會各自重試，增加短期請求量；固定 backoff 可錯開部分請求，但沒有加入 jitter，以維持簡單且可預測的行為。
- 錯誤分類依賴 yt-dlp 文字片段；若未來 wording 改變，行為會安全退化為不重試，不會誤重試其他錯誤。
- 新 process 可能讓 progress callback 從新的 attempt 再次更新；本 change 不新增跨 attempt progress state，交由 yt-dlp 對同一 `.part` 檔的續傳輸出維持現有語意。
- 取消與 actor reentrancy 存在 launch race；在 sleep 邊界與 `process.run()` 前再次檢查，可把新增 retry window 的競態封閉在既有 process 啟動接縫內。
- 若同一 `taskId` 的新 operation 在舊 operation 尚未完全退出時開始，`DownloadOperationID` 與 active-operation replacement 會讓舊 operation 安全停止；測試必須覆蓋此交錯順序，避免只驗證單一 operation 的取消。
