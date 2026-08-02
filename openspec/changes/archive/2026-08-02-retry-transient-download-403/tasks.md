## 1. 測試先行：403 分類與 retry orchestration

- [x] 1.1 在 `TubifyTests/YTDLPServiceTests.swift` 為 production 403 classification helper 新增測試，確認只有 `YTDLPError.executionFailed` message 包含 `unable to download video data: HTTP Error 403: Forbidden` 時可重試；webpage、subtitle、fragment downloader、`Giving up after`、HTTP 429、HTTP 5xx、登入錯誤及其他 `YTDLPError` 均不可重試。
- [x] 1.2 在 `TubifyTests/YTDLPServiceTests.swift` 直接驅動 production `executeDownloadFlow`，使用 scripted attempt executor 與不實際等待的 slice sleeper，驗證第一次 target 403 後成功、retry 3 成功、4 次 attempts 全部 target 403、其他 403 context 與 non-403 立即失敗，以及總 delay sequence 精確為 2、5、10 秒。
- [x] 1.3 在 `TubifyTests/YTDLPServiceTests.swift` 透過同一 production `executeDownloadFlow` 新增 cancellation 與 cookies contract 測試，以 sentinel templates 驗證單純 target 403 不切換 cookies mode、明確登入錯誤會進入 cookie-template branch、active attempt 取消不重試，以及 backoff 中取消最遲於下一個 100 ms slice boundary 結束且不啟動下一個 process。

## 2. 實作有界完整 process 重試

- [x] 2.1 在 `Tubify/Services/YTDLPService.swift` 實作單一 internal target-403 classification／retry policy 與可測試的 `executeDownloadFlow`；initial attempt 後最多額外 retry 3 次，固定使用 2、5、10 秒 async backoff，success 回傳既有結果、exhaustion 原樣拋出最後錯誤、其他 403 context 與 non-403 立即原樣拋出。
- [x] 2.2 在 `Tubify/Services/YTDLPService.swift` 讓不帶 cookies 與帶 cookies 的 `executeDownload` 呼叫都經過同一 `executeDownloadFlow`；同一組 attempts 保持 processed command template 不變，target HTTP 403 不得自行觸發 cookies fallback，也不得修改 yt-dlp CLI flags 或清除 `.part` 檔。
- [x] 2.3 在 `Tubify/Services/YTDLPService.swift` 完成取消與日誌接線：以最長 100 ms async sleep slices 組成 backoff，在每個 slice 後、每次 operation 前及 `process.run()` 前檢查 `cancelledTaskIds`，取消即在完成當前不超過 100 ms 的 sleep slice 後停止剩餘 attempts；每次 retry 記錄 task ID、retry number、最大 retries 與 delay。

## 3. 驗證

- [x] 3.1 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' -only-testing:TubifyTests/YTDLPServiceTests`，確認分類、完整 retry、cookies 與 cancellation branches 全部通過。
- [x] 3.2 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，確認既有下載佇列、手動 retry、post-live、subtitle 與 multi-site tests 沒有 regression；若環境無法完成，記錄限制、未驗證項目與可稽核替代證據，不得宣稱完整 suite 已通過。

## 4. Ingest 後的 cancellation isolation 與 production boundary 補強

- [x] 4.1 為 requirement `下載 video-data HTTP 403 的有界完整 process 重試` 與 requirement `403 重試維持下載生命週期與 cookies contract` 更新 `Tubify/Services/YTDLPService.swift`：以唯一 `DownloadOperationID` 綁定每次 `download`、`executeDownloadFlow`、backoff 與 `executeDownload`；同一 `taskId` 的新 operation SHALL 先使舊 operation stale 並終止舊 process，`cancel(taskId:)` SHALL 只取消目前 active operation，且 classification SHALL 排除同時包含 target 403 與 `Giving up after` 的 message。以 production code 保持既有 cookies、CLI flags、`.part` 與 queue contract。
- [x] 4.2 在 `TubifyTests/YTDLPServiceTests.swift` 新增可控 yt-dlp executable fixture 與 production `download` path 測試，驗證 `cancel(taskId:)` 可終止 active `Process`、process cleanup 完成、取消不進入 cookies fallback；並透過同一 `taskId` 的 overlapping operations 驗證舊 operation 不會在新 operation 開始後啟動 process，以及 target 403 + `Giving up after` 不重試。
- [x] 4.3 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' -only-testing:TubifyTests/YTDLPServiceTests` 與 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，確認新增 cancellation isolation、process boundary 與分類負向案例通過，且既有 suite 維持 0 failures。
