# 字幕選擇與媒體選項偵測（`subtitle-selection`）

## Purpose

媒體選擇視窗的字幕預設全選與「全部取消」、YouTube 自動字幕（繁體中文、英文）選項的偵測／呈現／下載與失敗退路，以及媒體選項查詢優先不帶 cookies 的兩階段策略。

## Requirements

### Requirement: Clear all selected subtitles

When subtitle choices are displayed, the system SHALL provide a control labeled "全部取消" that clears every selected subtitle without dismissing the media selection view. Activating this control SHALL NOT change the selected audio track.

#### Scenario: Clear the default subtitle selection

- **WHEN** the media selection view initially has multiple subtitle languages selected and the user activates "全部取消"
- **THEN** the system SHALL leave every subtitle language unselected and keep the media selection view open

##### Example: Keep only one of three subtitles

- **GIVEN** `zh-TW`, `en`, and `ja` subtitles are selected by default
- **WHEN** the user activates "全部取消" and then selects `en`
- **THEN** only the `en` subtitle SHALL be selected for download

#### Scenario: Preserve the selected audio track

- **WHEN** the user has selected an audio track and activates "全部取消" in the subtitle section
- **THEN** the system SHALL preserve the selected audio track unchanged

---

### Requirement: Preserve default subtitle selection

The system SHALL continue to select all supported uploaded subtitle languages when the media selection view first appears. YouTube automatic captions MUST NOT be selected by default; the user SHALL opt in to each one explicitly.

#### Scenario: Open media selection with supported subtitles

- **WHEN** the media selection view appears with supported uploaded subtitle languages available
- **THEN** the system SHALL initially select every supported uploaded subtitle language

#### Scenario: Automatic captions are not selected by default

- **WHEN** the media selection view appears with both uploaded subtitles and YouTube automatic captions available
- **THEN** every automatic caption SHALL be unselected
- **AND** "全部取消" SHALL clear uploaded and automatic selections alike

### Requirement: 媒體選項偵測優先不帶 cookies

系統取得某個影片的媒體選項時，SHALL 先以不帶 cookies 的 yt-dlp invocation 查詢，使公開影片的使用者上傳字幕不會因為帶上帳號 cookies 而從查詢結果中消失。只有在不帶 cookies 的查詢以非 0 exit code 失敗、且失敗訊息符合既有的「需登入」訊號、且呼叫端確實提供了 cookies 參數時，系統才 SHALL 以帶 cookies 的 invocation 重試一次。單次媒體選項查詢的 yt-dlp invocation 次數 MUST NOT 超過 2 次。兩次 invocation 的引數都 SHALL 包含指定 player client 的 `--extractor-args` 與其值。

#### Scenario: 有可用 cookies 時第一次查詢仍不帶 cookies

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **WHEN** 系統查詢某個影片的媒體選項
- **THEN** 第一次 yt-dlp invocation 的引數 MUST NOT 包含任何該 cookies 參數的元素
- **AND** 第一次 yt-dlp invocation SHALL 包含 `-J`、`--skip-download`、`--no-playlist`、`--write-auto-subs` 四個旗標（`--write-auto-subs` 讓 yt-dlp 列出上傳字幕的翻譯 key；`-J` 搭配 `--skip-download` 不會實際下載字幕）、指定 player client 的 `--extractor-args` 與其值，以及目標 url，且不含其他引數

##### Example: 公開影片的字幕軌不因 cookies 消失

- **GIVEN** 某公開影片含一軌使用者上傳的 `zh` 字幕
- **AND** 呼叫端提供了非空的 cookies 參數
- **WHEN** 系統查詢該影片的媒體選項
- **THEN** 查詢結果 SHALL 包含 `zh` 字幕軌
- **AND** 該影片 SHALL 進入等待媒體選擇的狀態而非直接排入下載佇列

#### Scenario: 第一次查詢成功則不重試

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **WHEN** 不帶 cookies 的第一次 invocation 以 exit code 0 結束
- **THEN** 系統 SHALL 回傳該次結果
- **AND** 系統 MUST NOT 執行第二次 invocation
- **AND** 該次結果是否包含任何字幕軌或音軌 MUST NOT 改變此判定

#### Scenario: 需登入錯誤且有 cookies 時帶 cookies 重試

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **AND** 不帶 cookies 的第一次 invocation 以非 0 exit code 失敗
- **WHEN** 失敗訊息符合既有的「需登入」訊號
- **THEN** 系統 SHALL 執行第二次 invocation，其引數 SHALL 恰為第一次 invocation 的引數加上該 cookies 參數的全部元素，既有的 `-J`、`--skip-download`、`--no-playlist`、`--write-auto-subs`、指定 player client 的 `--extractor-args` 與其值，以及目標 url MUST 全數保留
- **AND** 第二次 invocation 的結果 SHALL 作為本次媒體選項查詢的結果

#### Scenario: 重試後仍失敗以第二次的訊息回報

- **GIVEN** 系統已依「需登入」訊號執行了帶 cookies 的第二次 invocation
- **WHEN** 第二次 invocation 亦以非 0 exit code 失敗
- **THEN** 系統 SHALL 以第二次失敗的訊息回報媒體選項查詢失敗
- **AND** 系統 MUST NOT 執行第三次 invocation

#### Scenario: 非需登入錯誤不重試

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **AND** 不帶 cookies 的第一次 invocation 以非 0 exit code 失敗
- **WHEN** 失敗訊息不符合既有的「需登入」訊號
- **THEN** 系統 MUST NOT 執行第二次 invocation
- **AND** 系統 SHALL 以第一次失敗的訊息回報媒體選項查詢失敗

#### Scenario: 沒有可用 cookies 時不重試

- **GIVEN** 呼叫端提供的 cookies 參數為空
- **AND** 不帶 cookies 的第一次 invocation 失敗且訊息符合「需登入」訊號
- **WHEN** 系統處理該次失敗
- **THEN** 系統 MUST NOT 執行第二次 invocation
- **AND** 系統 SHALL 以第一次失敗的訊息回報媒體選項查詢失敗

#### Scenario: 與 exit code 無關的失敗不觸發重試

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **WHEN** 媒體選項查詢因找不到 yt-dlp 執行檔或無法啟動 process 而失敗
- **THEN** 系統 MUST NOT 執行帶 cookies 的重試
- **AND** 系統 SHALL 沿用既有的錯誤回報方式

### Requirement: 媒體選項查詢重用下載路徑的登入訊號定義

系統判斷媒體選項查詢的失敗訊息是否代表「需登入」時，SHALL 呼叫與下載路徑相同的登入訊號入口，MUST NOT 另行維護第二份訊號清單。此處共用的是「需登入」訊號定義本身，不是整體的 cookies 重試決策：下載路徑另有的 video-data 403 訊號 MUST NOT 被媒體選項查詢採用，因為媒體選項查詢帶 `--skip-download`、不下載 video data。

#### Scenario: 同一則訊息交給同一入口

- **GIVEN** 一則 yt-dlp 失敗訊息
- **WHEN** 媒體選項查詢判斷它是否代表需登入
- **THEN** 系統 SHALL 使用與下載路徑相同的登入訊號入口
- **AND** 媒體選項查詢 MUST NOT 對該訊息另行套用下載路徑的 video-data 403 訊號，也 MUST NOT 使用該入口以外的訊號清單

#### Scenario: video-data 403 不使媒體選項查詢重試

- **GIVEN** 不帶 cookies 的媒體選項查詢以 video-data 403 訊息失敗
- **WHEN** 系統判斷是否重試
- **THEN** 系統 MUST NOT 因該訊息本身觸發帶 cookies 的重試

---

### Requirement: YouTube 自動字幕選項的偵測

系統解析媒體選項時，除使用者上傳字幕（`subtitles`）外，SHALL 從 `automatic_captions` 提供自動字幕選項，且只限繁體中文（`zh-Hant`）與英文（`en`）兩個目標語言。某目標語言已被上傳字幕涵蓋時，系統 MUST NOT 再提供該語言的自動字幕。涵蓋判定：繁體中文為上傳字幕語言碼（不分大小寫）等於 `zh-Hant`、`zh-TW`、`zh-HK` 或 `zh-MO`；英文為 `en` 或以 `en-` 開頭。

目標語言可用時，系統 SHALL 依下列品質由高到低挑選 `automatic_captions` 的 key，並標記字幕來源：

1. 同時存在 `<目標>-orig` 與 `<目標>`：使用 `<目標>`，來源為「自動產生」（影片原始語言的語音辨識字幕，不經翻譯）
2. 存在 `<目標>-<上傳字幕語言>`：使用該 key，來源為「自動翻譯」；影片原始語言（`language`）的上傳字幕作為翻譯來源者優先
3. 存在 `<目標>`：使用該 key，來源為「自動翻譯」

以上皆不存在時，系統 MUST NOT 提供該目標語言的自動字幕。

#### Scenario: 僅提供繁體中文與英文的自動字幕

- **GIVEN** `automatic_captions` 含多種語言的 key
- **WHEN** 系統解析媒體選項
- **THEN** 自動字幕選項 SHALL 只包含繁體中文與英文

#### Scenario: 上傳字幕已涵蓋該語言則不提供自動字幕

- **GIVEN** 影片有上傳的 `zh-TW` 字幕或 `en-US` 字幕
- **WHEN** 系統解析媒體選項
- **THEN** 系統 MUST NOT 提供對應語言（繁體中文或英文）的自動字幕

#### Scenario: 英文影片提供語音辨識字幕

- **GIVEN** 影片沒有上傳英文字幕，`automatic_captions` 同時含 `en` 與 `en-orig`
- **WHEN** 系統解析媒體選項
- **THEN** 英文自動字幕 SHALL 使用 key `en`、來源為「自動產生」，且優先於上傳字幕的翻譯

#### Scenario: 以原始語言的上傳字幕為翻譯來源

- **GIVEN** 影片原始語言為 `ja`，上傳字幕含 `ja` 與 `en`，`automatic_captions` 含 `zh-Hant-ja` 與 `zh-Hant-en`
- **WHEN** 系統解析媒體選項
- **THEN** 繁體中文自動字幕 SHALL 使用 key `zh-Hant-ja`，來源為「自動翻譯」

### Requirement: 自動字幕的呈現與選取

媒體選擇視窗 SHALL 將自動字幕列在上傳字幕之後，並以 `（YouTube 自動翻譯）` 或 `（YouTube 自動產生）` 標示來源。同語言的上傳字幕與自動字幕 MUST 可區分：自動字幕的選取識別（id）SHALL 為 `auto:<目標語言>`，不含翻譯來源語言，使播放清單合併選項時各影片的同語言自動字幕併為同一項。

使用者送出選擇時，上傳字幕 SHALL 以語言碼記入 `selectedLanguages`，自動字幕 SHALL 以其實際 yt-dlp key 記入 `automaticLanguages`。播放清單合併選擇後，每個任務 SHALL 只保留自己實際擁有的字幕；自動字幕以該任務自己的 key 為準，並依語言分別判斷。沒有選取任何字幕時，字幕選擇 SHALL 為空（nil）。

#### Scenario: 同語言的上傳與自動字幕可區分

- **GIVEN** 影片有上傳的英文字幕與英文自動字幕
- **WHEN** 媒體選擇視窗列出字幕
- **THEN** 兩者 SHALL 為不同的選項，勾選其一 MUST NOT 影響另一者

#### Scenario: 播放清單各任務使用自己的自動字幕 key

- **GIVEN** 播放清單中影片 A 的繁體中文自動字幕 key 為 `zh-Hant-en`，影片 B 為 `zh-Hant`
- **WHEN** 使用者在合併選擇中勾選「繁體中文（自動）」
- **THEN** 影片 A 的字幕選擇 SHALL 記入 `zh-Hant-en`，影片 B SHALL 記入 `zh-Hant`

#### Scenario: 舊版持久化資料仍可解碼

- **GIVEN** 持久化的字幕選擇不含 `automaticLanguages` 欄位
- **WHEN** 系統解碼該資料
- **THEN** 系統 SHALL 將其視為只含上傳字幕、`automaticLanguages` 為空的選擇

### Requirement: 自動字幕與影片同一次下載

選取了字幕時，系統 SHALL 在下載影片的同一次 yt-dlp invocation 中一併下載字幕，使字幕共用 cookies 與 `--sponsorblock-remove`、`--remove-chapters` 等裁切設定。引數規則：選取了上傳字幕才加入 `--write-sub`；選取了自動字幕才加入 `--write-auto-subs`；兩者共用一個 `--sub-lang`（值為上傳字幕語言碼與自動字幕 key 以逗號串接）與 `--sub-format srt`。

#### Scenario: 只選自動字幕

- **GIVEN** 字幕選擇只含自動字幕
- **WHEN** 系統執行下載
- **THEN** 該次 invocation SHALL 含 `--write-auto-subs`、`--sub-lang` 與 `--sub-format srt`
- **AND** MUST NOT 含 `--write-sub`

#### Scenario: 上傳與自動字幕並存

- **GIVEN** 字幕選擇同時含上傳字幕 `en` 與自動字幕 `zh-Hant-en`
- **WHEN** 系統執行下載
- **THEN** 該次 invocation SHALL 含 `--write-sub` 與 `--write-auto-subs`，且 `--sub-lang` 值為 `en,zh-Hant-en`

### Requirement: 自動字幕失敗的退路

YouTube 常以 HTTP 429 拒絕匿名的自動字幕請求，而 yt-dlp 抓字幕失敗會中止整支影片。系統 SHALL 僅在 yt-dlp 錯誤訊息指名已選取的自動字幕 key（`Unable to download video subtitles for '<key>'`）時啟動退路，MUST NOT 對上傳字幕失敗、影片本身的錯誤或使用者取消啟動，也 MUST NOT 吞掉影片本身的持續失敗。退路依序為：

1. **帶 cookies 重試**：第一輪尚未使用 cookies 且有可用 cookies 範本時，保留全部字幕選擇，改以帶 cookies 的範本重跑一次。若重跑時失敗的是影片本身（非自動字幕），系統 SHALL 保留字幕選擇以原流程重跑（沿用已寫出的字幕檔，使字幕與影片一起被裁切）。
2. **逐一略過**：上述仍因自動字幕失敗，或第一輪已使用 cookies（重跑同一條 cookies 指令無益）時，系統 SHALL 只移除錯誤指名的自動字幕 key、保留其餘字幕後重跑；每一輪至少移除一個 key，直到成功或拋出非自動字幕錯誤。

整次下載導出 cookies 的次數 MUST NOT 超過 1 次。所有重跑 SHALL 共用下載開始前的目錄快照，使失敗輪次留下的中間檔能在最終成功時由孤兒中間檔清理（見 `download-reliability`）處理。每次略過 SHALL 留下含被略過 key 與原錯誤的日誌。

#### Scenario: 匿名請求被 429 擋下，帶 cookies 重試後成功

- **GIVEN** 第一輪不帶 cookies，錯誤指名已選取的自動字幕 key
- **WHEN** 系統帶 cookies 重跑且成功
- **THEN** 下載 SHALL 完成並保留全部字幕選擇

#### Scenario: 帶 cookies 仍失敗則略過自動字幕

- **GIVEN** 帶 cookies 重跑仍因自動字幕失敗
- **WHEN** 系統進入逐一略過
- **THEN** 影片 SHALL 在不含該自動字幕的情況下完成，上傳字幕 SHALL 保留

#### Scenario: 部分自動字幕失敗只移除失敗者

- **GIVEN** 同時選取繁體中文與英文自動字幕，錯誤只指名英文
- **WHEN** 系統重跑
- **THEN** 重跑的選擇 SHALL 保留繁體中文、移除英文

#### Scenario: 影片本身的失敗不被當成字幕失敗

- **GIVEN** 帶 cookies 重跑時失敗的是影片本身
- **WHEN** 影片在保留字幕的原流程重跑後仍失敗
- **THEN** 系統 SHALL 拋出該影片錯誤，MUST NOT 以移除字幕掩蓋

#### Scenario: 上傳字幕失敗不啟動退路

- **GIVEN** 錯誤指名的是上傳字幕
- **WHEN** 系統處理該次失敗
- **THEN** 系統 MUST NOT 啟動自動字幕退路，維持原本的失敗行為

## 來源 change

- 2026-07-13-add-clear-all-subtitles、2026-08-21-cookieless-subtitle-detection、2026-08-22-dubbed-audio-track-selection（詳見 [completed-tasks.md](../completed-tasks.md)）
- YouTube 自動字幕（commit `63d9f63`，未經 OpenSpec 流程，需求由該 commit 的實作與測試反推整理）

## 對應程式碼

- `Tubify/Models/SubtitleInfo.swift`
- `Tubify/Services/YTDLPService.swift`
- `Tubify/Services/YouTubeMetadataService.swift`
- `Tubify/ViewModels/DownloadManager.swift`
- `Tubify/Views/MediaSelectionView.swift`
- `TubifyTests/MediaSelectionLogicTests.swift`
- `TubifyTests/YTDLPServiceTests.swift`
- `TubifyTests/YouTubeMetadataServiceTests.swift`
