# subtitle-selection Specification

## Purpose

TBD - created by archiving change 'add-clear-all-subtitles'. Update Purpose after archive.

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


<!-- @trace
source: add-clear-all-subtitles
updated: 2026-07-13
code:
  - .agents/skills/spectra-commit/SKILL.md
  - .agents/skills/spectra-propose-plus/SKILL.md
  - .agents/skills/spectra-apply-plus/SKILL.md
  - Tubify/Views/MediaSelectionView.swift
  - .agents/skills/spectra-verify/SKILL.md
  - TubifyTests/MediaSelectionLogicTests.swift
  - .agents/skills/spectra-analyze/SKILL.md
-->

---

### Requirement: Preserve default subtitle selection

The system SHALL continue to select all supported subtitle languages when the media selection view first appears.

#### Scenario: Open media selection with supported subtitles

- **WHEN** the media selection view appears with supported subtitle languages available
- **THEN** the system SHALL initially select every supported subtitle language

<!-- @trace
source: add-clear-all-subtitles
updated: 2026-07-13
code:
  - .agents/skills/spectra-commit/SKILL.md
  - .agents/skills/spectra-propose-plus/SKILL.md
  - .agents/skills/spectra-apply-plus/SKILL.md
  - Tubify/Views/MediaSelectionView.swift
  - .agents/skills/spectra-verify/SKILL.md
  - TubifyTests/MediaSelectionLogicTests.swift
  - .agents/skills/spectra-analyze/SKILL.md
-->

### Requirement: 媒體選項偵測優先不帶 cookies

系統取得某個影片的媒體選項時，SHALL 先以不帶 cookies 的 yt-dlp invocation 查詢，使公開影片的使用者上傳字幕不會因為帶上帳號 cookies 而從查詢結果中消失。只有在不帶 cookies 的查詢以非 0 exit code 失敗、且失敗訊息符合既有的「需登入」訊號、且呼叫端確實提供了 cookies 參數時，系統才 SHALL 以帶 cookies 的 invocation 重試一次。單次媒體選項查詢的 yt-dlp invocation 次數 MUST NOT 超過 2 次。兩次 invocation 的引數都 SHALL 包含指定 player client 的 `--extractor-args` 與其值。

#### Scenario: 有可用 cookies 時第一次查詢仍不帶 cookies

- **GIVEN** 呼叫端提供了非空的 cookies 參數
- **WHEN** 系統查詢某個影片的媒體選項
- **THEN** 第一次 yt-dlp invocation 的引數 MUST NOT 包含任何該 cookies 參數的元素
- **AND** 第一次 yt-dlp invocation SHALL 保留既有的 `-J`、`--skip-download`、`--no-playlist` 三個旗標、指定 player client 的 `--extractor-args` 與其值，以及目標 url，且不含其他引數

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
- **THEN** 系統 SHALL 執行第二次 invocation，其引數 SHALL 恰為第一次 invocation 的引數加上該 cookies 參數的全部元素，既有的 `-J`、`--skip-download`、`--no-playlist`、指定 player client 的 `--extractor-args` 與其值，以及目標 url MUST 全數保留
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

<!-- @trace
source: dubbed-audio-track-selection
updated: 2026-08-22
code:
  - Tubify/Services/YTDLPService.swift
  - Tubify/Services/YouTubeMetadataService.swift
  - TubifyTests/YTDLPServiceTests.swift
  - TubifyTests/YouTubeMetadataServiceTests.swift
tests:
-->

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

<!-- @trace
source: cookieless-subtitle-detection
updated: 2026-08-21
code:
  - Tubify/Services/YTDLPService.swift
  - Tubify/Services/YouTubeMetadataService.swift
  - TubifyTests/YTDLPServiceTests.swift
  - TubifyTests/YouTubeMetadataServiceTests.swift
tests:
-->
