## Summary

下載流程在 cookies fallback 或 403 重試而重新啟動 yt-dlp process 後，前一次失敗 attempt 寫下的部分檔案（例如 `火箭降落的全过程，拍到了！.f401.mp4.part`）會永久留在下載目錄。本變更在下載整體成功後清除這些已確定無用的殘留中間檔。

## Motivation

`YTDLPService.executeDownloadFlow` 在 video-data 403 或登入類錯誤時會啟動**另一個** yt-dlp process 重試。yt-dlp 只清理自己該次 process 用到的中間檔，前一個 process 留下的部分檔案不在它的清理範圍內。

當重試改變了實際選中的格式時，殘留檔就成為孤兒：

- 第一次 attempt（不帶 cookies）選中 f401（AV1 mp4，175.52 MiB），以連續 HTTP range 下載至 22.3% 後收到 `unable to download video data: HTTP Error 403: Forbidden`，留下 40,988,684 bytes 的 `火箭降落的全过程，拍到了！.f401.mp4.part`
- 第二次 attempt（帶 Safari cookies）改走 46 個 fragment 的分段串流（83.09 MiB），成功 merge 為 `火箭降落的全过程，拍到了！.mp4`

最終影片完全正確，但殘留的 `.part` 既不會被續傳（格式不同）也不會被刪除。使用者每遇到一次 403 fallback 就在下載目錄多出一個看似未完成的檔案，且體積可觀，造成誤解與磁碟浪費。

此行為由 `retry-transient-download-403` 與其後的 cookies fallback 修正一併引入：跨 process 重試是刻意設計，缺的是跨 process 的殘留檔收尾。

## Proposed Solution

在單次下載流程成功取得最終輸出路徑後，於同一輸出目錄清除屬於該次下載、由先前失敗 attempt 留下的孤兒中間檔。

清理條件刻意設計得很窄，因為下載目錄是共用的：`DownloadManager` 支援 1 至 5 個並行下載寫入同一資料夾，預設 `~/Downloads` 也是瀏覽器等第三方工具的下載目的地。候選檔案必須同時滿足：

- 位於最終輸出檔所在的目錄，且該目錄就是本次下載的輸出目錄
- 不存在於本次下載流程啟動第一個 attempt 前取得的目錄檔名快照中
- 檔名以最終輸出檔的檔名主幹加一個點為前綴，且剩餘部分整體符合 yt-dlp 中間檔的命名形態
- 在型別檢查當下是一般檔案；名稱符合形態的目錄、symbolic link 或其他非一般檔案不刪除。目錄另有更強的保證：刪除以「對任何目錄一律失敗」的系統呼叫執行，即使檢查後才被替換成目錄也刪不掉；非目錄項目在檢查後才被替換的情形則不保證該名稱存續
- content modification date 早於最終輸出檔

刪除本身以「對任何目錄一律失敗」的系統呼叫執行，使「不刪除目錄」不依賴型別檢查與刪除之間沒有時間差。

清理只在整體下載成功時執行；最終失敗時保留 partial 檔，讓相同格式的後續重跑仍可續傳。清理失敗（權限、檔案已消失等）只記錄日誌，不改變下載結果。

## Non-Goals

- 不改變 403 重試次數、backoff 秒數或 cookies fallback 的觸發條件
- 不在下載最終失敗時刪除 partial 檔
- 不掃描或清理與本次下載無關的既有 partial 檔，也不提供全域「清理下載目錄」功能
- 不改變 yt-dlp 指令模板，特別是不加入 `--no-part`：那會讓中斷的下載直接污染最終檔名
- 不清理沒有 `.part`、`.ytdl` 或 `.part-Frag<N>` 後綴的完整中間檔。403 若發生在音訊階段，前一個 attempt 可能已寫完視訊而留下 `<stem>.f401.mp4`。這類檔案與正常媒體檔在命名上無法區分，誤刪風險遠高於 partial 檔，因此不納入
- 不新增 Safari cookies 轉換或 `PermissionService` 的注入 seam，因此本變更的測試不涵蓋 cookies fallback 分支
- 不修正 `openspec/specs/download-reliability/spec.md` 中與現行 cookies fallback 行為已漂移的既有敘述

## Alternatives Considered

- **在重試前先刪除失敗 attempt 的 partial 檔**：時機更早，但當重試選中相同格式時會摧毀可續傳的進度，把本可續傳的下載變成整份重下。
- **只以檔名主幹為前綴判斷候選檔**：實作最簡單，但標題含有點時會誤中其他影片。最終檔為 `Lecture 1.mp4` 時，另一任務的 `Lecture 1.5.f401.mp4.part` 同樣以 `Lecture 1.` 開頭，會被誤刪。
- **在 yt-dlp 指令加入 `--no-part`**：yt-dlp 會直接寫入最終檔名，中斷後留下的是無 `.part` 後綴的半份檔案，比現況更難辨識，且會與續傳機制衝突。
- **由使用者手動清理**：殘留檔與正確影片同名前綴，使用者難以判斷哪個可刪，違背本 app 全自動的下載體驗。
- **每次 app 啟動時掃描下載目錄刪除所有 partial 檔**：無法區分孤兒檔與其他 app、其他工具正在寫入的檔案，風險過高。

## Capabilities

### New Capabilities

（none）

### Modified Capabilities

- download-reliability：新增跨 process 重試後的孤兒中間檔清理行為

## Impact

- Affected specs: download-reliability
- Affected code:
  - New:
    - (none)
  - Modified:
    - Tubify/Services/YTDLPService.swift
    - TubifyTests/YTDLPServiceTests.swift
  - Removed:
    - (none)
