# download-reliability Specification

## Purpose

download-reliability capability.

## Requirements

### Requirement: 下載 video-data HTTP 403 的有界完整 process 重試

系統在 yt-dlp 媒體下載 attempt 以 `YTDLPError.executionFailed` 失敗，且錯誤訊息包含逐字片段 `unable to download video data: HTTP Error 403: Forbidden` 且不包含 `Giving up after` 時，SHALL 重新執行完整 yt-dlp process，讓每個 retry attempt 重新解析格式與媒體 URL。系統 SHALL 在 initial attempt 後最多執行 3 次 retry attempts，並 MUST 依序在 retry 前等待 2、5、10 秒。系統 MUST NOT 以加入或降低 yt-dlp `--retries` 取代完整 process 重試。

#### Scenario: 第一個 retry 恢復下載

- **GIVEN** initial attempt 回傳 `YTDLPError.executionFailed("ERROR: unable to download video data: HTTP Error 403: Forbidden")`
- **AND** 下一個完整 yt-dlp process 成功產生 output path
- **WHEN** 系統執行該下載
- **THEN** 系統 SHALL 等待 2 秒並啟動一個新的 yt-dlp process
- **AND** 系統 SHALL 回傳成功的 output path，不向下載佇列回報中間失敗

##### Example:

initial attempt 在 0 秒收到 403，系統等待 2 秒後執行 retry 1；retry 1 回傳 `/Users/cash/Downloads/tubify/video.mp4`，整體下載結果即為成功，process attempt count 為 2。

#### Scenario: 最後一個 retry 恢復下載

- **GIVEN** initial attempt、retry 1 與 retry 2 都回傳符合分類的 HTTP 403
- **AND** retry 3 成功產生 output path
- **WHEN** 系統執行該下載
- **THEN** 系統 SHALL 依序套用 2、5、10 秒 delay
- **AND** 系統 SHALL 執行總共 4 個完整 yt-dlp processes
- **AND** 系統 SHALL 以 retry 3 的 output path 完成下載

#### Scenario: 重試耗盡後回報最後錯誤

- **GIVEN** initial attempt 與 3 次 retry attempts 全部回傳符合分類的 HTTP 403
- **WHEN** 系統執行該下載
- **THEN** 系統 SHALL 依序套用 2、5、10 秒 delay 並停止於總共 4 次 attempts
- **AND** 系統 SHALL 原樣拋出第 4 次 attempt 的 `YTDLPError.executionFailed`
- **AND** 系統 MUST NOT 啟動第 5 個 yt-dlp process

#### Scenario: 非目標錯誤不重試

- **GIVEN** initial attempt 回傳不含 `unable to download video data: HTTP Error 403: Forbidden` 的錯誤，包括 webpage、subtitle、fragment downloader 或 `Giving up after` context 的其他 HTTP 403、HTTP 429、HTTP 5xx、登入限制、私人影片、格式錯誤、ffmpeg 錯誤、`YTDLPError.notFound` 或 `YTDLPError.parseError`，或 message 同時包含 `Giving up after` 與 `unable to download video data: HTTP Error 403: Forbidden`
- **WHEN** 系統執行該下載
- **THEN** 系統 SHALL 立即原樣拋出該錯誤
- **AND** 系統 MUST NOT 等待 retry delay 或啟動另一個 yt-dlp process

<!-- @trace
source: retry-transient-download-403
updated: 2026-08-02
code:
  - Tubify/Services/YTDLPService.swift
  - TubifyTests/YTDLPServiceTests.swift
tests:
-->

### Requirement: 403 重試維持下載生命週期與 cookies contract

系統 SHALL 讓 target HTTP 403 retries 留在單次 `YTDLPService.download` 呼叫內，使下載任務在 intermediate attempts 期間維持既有 downloading 生命週期。系統 MUST 保持同一組 attempts 的 processed command template 不變，單純 target HTTP 403 MUST NOT 觸發 Safari cookies fallback。使用者取消 SHALL 優先於任何剩餘 retry，且只有 retry 成功或最終失敗可以離開整體下載呼叫。

#### Scenario: HTTP 403 不切換 cookies mode

- **GIVEN** 原始 command template 包含 `--cookies-from-browser safari`
- **AND** 系統依既有策略建立不帶 cookies 的 first template
- **WHEN** first template 的下載 attempts 回傳 HTTP 403
- **THEN** 所有 403 retry attempts SHALL 繼續使用相同的不帶 cookies processed template
- **AND** 系統 MUST NOT 因 HTTP 403 本身建立或執行帶 cookies template

#### Scenario: 明確登入錯誤仍使用既有 cookies fallback

- **GIVEN** 不帶 cookies 的整體下載最終回傳既有 `shouldRetryWithCookies` 認得的登入錯誤
- **WHEN** 原始 command template 允許 Safari cookies
- **THEN** 系統 SHALL 沿用既有 Safari cookies 轉換與 fallback
- **AND** 帶 cookies 路徑若發生符合分類的 HTTP 403，SHALL 使用相同的 2、5、10 秒有界 retry policy

#### Scenario: backoff 期間取消

- **GIVEN** 某個 attempt 回傳符合分類的 HTTP 403 並進入 retry backoff
- **WHEN** 使用者在下一個 process 啟動前取消該 task
- **THEN** 系統 SHALL 在完成當前不超過 100 ms 的 sleep slice 後拋出 `YTDLPError.cancelled` 並釋放該下載佔用的 queue slot
- **AND** 系統 MUST NOT 啟動下一個 yt-dlp process 或消耗剩餘 retry attempts

#### Scenario: active process 期間取消

- **GIVEN** 某個 retry attempt 的 yt-dlp process 正在執行
- **WHEN** 使用者取消該 task
- **THEN** 系統 SHALL 終止 active process 並拋出 `YTDLPError.cancelled`
- **AND** 系統 MUST NOT 因 process 終止訊息再執行 403 retry 或 cookies fallback

#### Scenario: 中間 403 不產生最終失敗副作用

- **GIVEN** 至少一個 intermediate attempt 回傳符合分類的 HTTP 403
- **WHEN** 後續 retry attempt 成功
- **THEN** task SHALL 維持 downloading 直到轉為 completed
- **AND** 系統 MUST NOT 將 task 暫時保存為 failed 或發送下載失敗通知

#### Scenario: 重試日誌可辨識 attempt

- **GIVEN** 系統準備執行 HTTP 403 retry
- **WHEN** 系統記錄該 retry
- **THEN** 日誌 SHALL 包含 task ID、目前 retry number、最大 retries 與本次 delay

#### Scenario: 新 operation 隔離舊 retry cancellation

- **GIVEN** 某個 task 的舊 `DownloadOperationID` 正在 retry backoff
- **AND** 同一 task 開始一個新的 `DownloadOperationID`
- **WHEN** 使用者取消該 task
- **THEN** 系統 SHALL 只取消目前 active operation，並終止其 active process
- **AND** 舊 operation SHALL 在下一個 process 前被辨識為 stale 並拋出 `YTDLPError.cancelled`
- **AND** 舊 operation MUST NOT 清除、覆寫或誤讀新 operation 的 cancellation state

<!-- @trace
source: retry-transient-download-403
updated: 2026-08-02
code:
  - Tubify/Services/YTDLPService.swift
  - TubifyTests/YTDLPServiceTests.swift
tests:
-->
