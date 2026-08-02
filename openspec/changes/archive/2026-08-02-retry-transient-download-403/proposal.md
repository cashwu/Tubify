## Summary

為 yt-dlp 媒體下載期間直接回傳的 `unable to download video data: HTTP Error 403: Forbidden` 增加有界限的完整 process 重試。每次重試重新執行 yt-dlp 以重新解析格式與媒體 URL，降低暫時性 YouTube／CDN 授權狀態造成的人工重試需求。

## Motivation

Tubify 目前遇到下載階段的 HTTP 403 時會立即把任務標記為失敗；使用者數秒後手動重新下載同一任務卻經常成功。yt-dlp 內建的 `--retries` 主要處理預期的網路讀取錯誤，建立媒體連線時直接收到的 HTTP 403 仍可能立即結束 process，因此只修改命令列重試次數無法重現手動重新下載所帶來的完整重新解析效果。

這是 Bug Fix：讓可恢復的短暫 403 在既有下載流程內自動恢復，同時避免永久錯誤、登入限制或使用者取消被無差別重試。

## Proposed Solution

- 在 `YTDLPService` 的單次實際下載接縫外加入 403 專用重試迴圈。
- 只有 `YTDLPError.executionFailed` 的訊息包含 `unable to download video data: HTTP Error 403: Forbidden` 時可進入此重試。
- 即使訊息同時包含 target 403 片段，只要已包含 `Giving up after` context 便不得進入此重試。
- 初始嘗試失敗後最多額外重試 3 次，依序等待 2、5、10 秒；每次都重新啟動完整 yt-dlp process。
- 保留現有「先不帶 cookies，只有明確登入訊號才帶 Safari cookies 重試」的策略，403 重試不改變 cookies 模式。
- 使用者取消、其他錯誤或重試耗盡時沿用既有取消／失敗處理；backoff 期間取消必須在完成當前不超過 100 ms 的 sleep slice 後結束等待，且不啟動新 process。只有最終失敗才由 `DownloadManager` 呈現 failed 狀態與失敗通知。
- 每次 `download` operation 建立唯一 `DownloadOperationID`；取消只作用於當前 operation，舊 operation 在新 operation 開始後不得再啟動 process。
- 提供一個 production 與測試共用的 internal download-flow 接縫，讓 scripted executor 可直接驗證 first template、403 retries、login classification 與 cookie-template fallback 的真實 orchestration branch。
- 以可控的 yt-dlp executable fixture 驗證 production `executeDownload`、`Process.terminate()`、operation cancellation 與 process cleanup，不以 scripted executor 取代該 boundary。
- 記錄每次 403 重試的 attempt 與 delay，讓日誌可區分暫時失敗、重試成功及最終失敗。

## Non-Goals

- 不安裝或管理 yt-dlp 的 `curl_cffi`、impersonation target、PO Token provider 或其他外部依賴。
- 不修改使用者的 yt-dlp 自訂命令，也不加入或降低 `--retries`。
- 不對 webpage、subtitle、fragment downloader 或已顯示 `Giving up after` 的其他 403 context 新增重試，也不重試 HTTP 429、5xx、登入限制、私人影片、地區限制、格式選擇或 ffmpeg 錯誤。
- 不新增重試次數或等待時間的 UI 設定。
- 不改變下載佇列的並行數、任務持久化格式或手動重試行為。

## Alternatives Considered

- 在預設命令加入 `--retries 3`：拒絕，因為 yt-dlp 已有自己的預設重試策略，且建立媒體連線時的直接 HTTP 403 不一定由該機制重試；同時會降低其他預期網路錯誤的預設重試上限。
- 在 `DownloadManager` 將 failed 任務重新排回 pending：拒絕，因為會把 yt-dlp 錯誤分類洩漏到佇列層，並增加中間失敗狀態、持久化與通知重複的風險。
- 對所有下載錯誤重試：拒絕，因為永久錯誤不會因完整 process 重啟而恢復，只會延遲有效回饋並增加站點負載。
- 只補齊 impersonation 依賴：不納入本 change；它能改善特定站點相容性，但無法保證所有短暫 CDN 403 消失，也不取代有界限的恢復策略。

## Capabilities

### New Capabilities

- `download-reliability`：定義媒體下載直接收到 HTTP 403 時的精準分類、有界完整 process 重試、取消與最終失敗行為。

### Modified Capabilities

- (none)

## Impact

- Affected specs:
  - openspec/specs/download-reliability/spec.md (new)
- Affected code:
  - New:
    - (none)
  - Modified:
    - Tubify/Services/YTDLPService.swift
    - TubifyTests/YTDLPServiceTests.swift
  - Removed:
    - (none)
