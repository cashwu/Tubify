# Tubify 功能規格

本目錄是 Tubify 目前生效的行為規格，由過去的 OpenSpec／Cash 流程累積的 8 份 capability spec 整理而來。每份規格由 Requirement 與 Scenario（WHEN／THEN）組成，是實作與測試的依據。

各規格是怎麼演進出來的、當時完成了哪些 task，見 [`../completed-tasks.md`](../completed-tasks.md)。

## 規格一覽

### 下載入口與流程

| 規格 | 內容 |
| ---- | ---- |
| [multi-site-download](multi-site-download.md) | 接受任何格式正確的 URL；YouTube 與非 YouTube 的下載指令分流；YouTube 專屬處理（播放清單、提示、縮圖）只套用於 YouTube；通用指令為固定常數 |
| [playlist-or-video-prompt](playlist-or-video-prompt.md) | URL 同時含 `v=` 與 `list=` 時，詢問下載單支影片或整個播放清單 |
| [playlist-selection](playlist-selection.md) | 播放清單展開後的選集視窗：預設全選、全選／取消、數量顯示、確認後接續媒體選擇 |

### 媒體選擇

| 規格 | 內容 |
| ---- | ---- |
| [subtitle-selection](subtitle-selection.md) | 上傳字幕預設全選與「全部取消」；YouTube 自動字幕（繁中、英文）的偵測、呈現、下載與失敗退路；媒體選項查詢優先不帶 cookies，僅在「需登入」時帶 cookies 重試一次 |
| [audio-track-selection](audio-track-selection.md) | 以指定 player client 偵測配音音軌；選定語言時下載沿用同一組 client；語言限制套用到每個 format alternative，不得靜默改用其他語言 |

### 可靠性與直播回放

| 規格 | 內容 |
| ---- | ---- |
| [download-reliability](download-reliability.md) | video-data HTTP 403 的有界完整 process 重試（2／5／10 秒）、取消與 cookies contract、重試後的孤兒中間檔清理 |
| [youtube-post-live-replay](youtube-post-live-replay.md) | `post_live` 回放的可下載判定、`This live event has ended.` 視為暫態、手動重試；首播倒數錯誤（`Premieres in`、`Premiere will begin`）視為尚未首播 |

### 介面

| 規格 | 內容 |
| ---- | ---- |
| [download-ui-workflows](download-ui-workflows.md) | 情境感知貼上、重啟後任務恢復、可操作的錯誤、完成導向、單一原生 Settings、可存取性與設定輸入回饋、媒體選擇視窗高度、下載項目改名（顯示名稱與檔名、同名編號、沿用檔複製） |

## 閱讀慣例

- `SHALL`／`MUST` 為必須滿足；`MUST NOT` 為明確禁止。
- 規格正文保留原撰寫語言（部分英文、部分繁體中文）。OpenSpec 時期的內容未改寫；之後新增的 requirement（例如 YouTube 自動字幕）會在該規格的「來源 change」註明。
- 每份規格末尾的「對應程式碼」列出實作與測試所在檔案，可作為進入點。
