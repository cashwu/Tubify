# audio-track-selection Specification

## Purpose

audio-track-selection capability.

## Requirements

### Requirement: 配音音軌偵測指定 player client

系統查詢媒體選項時 SHALL 以 `--extractor-args` 明確指定 player client 集合為 `youtube:player_client=default,web_embedded`，使 YouTube 影片的配音音軌會出現在回傳的 format 清單中。系統 MUST NOT 僅依賴 yt-dlp 自行挑選的預設 client，因為預設 client 的 format 清單只含原聲音軌。

#### Scenario: 媒體選項查詢帶上指定的 player client

- **WHEN** 系統查詢某個影片的媒體選項
- **THEN** 該次 yt-dlp invocation 的引數 SHALL 依序包含 `--extractor-args` 與緊接其後的 `youtube:player_client=default,web_embedded`
- **AND** 該次 invocation 中等於 `--extractor-args` 的引數元素 SHALL 恰為 1 個

##### Example: 多配音影片出現音軌區塊

- **GIVEN** 某影片同時提供英文原聲與日文配音的純音訊 format
- **WHEN** 系統查詢該影片的媒體選項
- **THEN** 查詢結果的音軌清單 SHALL 同時包含 `en` 與 `ja`
- **AND** 該影片 SHALL 進入等待媒體選擇的狀態，且媒體選擇視窗 SHALL 顯示音軌區塊

#### Scenario: 偵測與下載使用同一份 client 設定來源

- **WHEN** 比較媒體選項查詢與下載指令所使用的 player client 設定值
- **THEN** 兩者 SHALL 取自同一個常數，其值為 `youtube:player_client=default,web_embedded`
- **AND** 產品程式碼（`Tubify/` 之下）MUST NOT 存在該值的第二處字面值定義

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

### Requirement: 選定音軌語言時下載沿用同一組 player client

使用者明確選定音軌語言時，系統 SHALL 在下載指令中加入與媒體選項查詢相同的 `--extractor-args` 設定，使偵測階段看得到的配音 format 在下載階段同樣可得。使用者未選定語言時，系統 MUST NOT 改動下載指令的 extractor args。

#### Scenario: 選定語言時注入 extractor args

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本不含 `--extractor-args`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際 yt-dlp invocation 的引數 SHALL 依序包含 `--extractor-args` 與緊接其後的 `youtube:player_client=default,web_embedded`

#### Scenario: 未選定語言時不注入

- **GIVEN** 某任務沒有音軌選擇，或其音軌選擇的語言代碼為空
- **AND** 該任務的下載指令範本不含 `--extractor-args`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際 yt-dlp invocation 的引數 MUST NOT 包含任何等於 `--extractor-args` 或以 `--extractor-args=` 為前綴的元素

#### Scenario: 範本已含 extractor args 時不覆蓋

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本已含 `--extractor-args` 引數
- **WHEN** 系統執行該任務的下載
- **THEN** 系統 MUST NOT 加入第二個 `--extractor-args` 引數
- **AND** 範本原有的 extractor args 值 SHALL 原樣傳給 yt-dlp

#### Scenario: 帶 cookies 的重試同樣帶上 extractor args

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本含 Safari cookies 參數
- **WHEN** 系統先以不帶 cookies 的指令嘗試，再以帶 cookies 的指令重試
- **THEN** 兩次 invocation 的引數 SHALL 都包含 `--extractor-args` 與 `youtube:player_client=default,web_embedded`
- **AND** 移除 cookies 參數的處理 MUST NOT 移除該 extractor args

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

### Requirement: 明確選定的音軌語言不得靜默改用其他語言

使用者明確選定音軌語言後，系統改寫 format 字串時 SHALL 讓每一個 alternative 都帶上該語言限制，MUST NOT 保留任何不含語言限制的 alternative。此處的 alternative 指：先以不位於 `[` 與 `]` 之間的 `,` 切出獨立下載群組，各群組再以不位於 `[` 與 `]` 之間的 `/` 切出的每一段。該語言的 format 無法取得時，下載 SHALL 以 yt-dlp 的失敗訊息結束，MUST NOT 以其他語言的音軌完成下載。

#### Scenario: 每個 alternative 都帶上語言限制

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本的 format 值為 `bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際傳給 yt-dlp 的 format 值 SHALL 為 `bv*[ext=mp4]+ba[ext=m4a][language=ja]/bv*+ba[language=ja]/b[language=ja]`

#### Scenario: 不得保留未受限的 fallback

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際傳給 yt-dlp 的 format 值依本 requirement 定義切出的每一個 alternative SHALL 都包含 `[language=ja]`
- **AND** 該 format 值 MUST NOT 在尾端附加未受限的原始 format 字串

#### Scenario: 逗號分隔的獨立下載群組各自受限

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本的 format 值為 `bv+ba,b`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際傳給 yt-dlp 的 format 值 SHALL 為 `bv+ba[language=ja],b[language=ja]`

#### Scenario: 中括號內的分隔字元不參與切分

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本的 format 值為 `ba[format_note*=A/B]+bv`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際傳給 yt-dlp 的 format 值 SHALL 為 `ba[format_note*=A/B]+bv[language=ja]`

#### Scenario: 語言限制落在 alternative 的最後一個組成部分

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本的 format 值為 `bv+ba`
- **WHEN** 系統執行該任務的下載
- **THEN** 實際傳給 yt-dlp 的 format 值 SHALL 為 `bv+ba[language=ja]`
- **AND** 該 alternative 中位於最後一個 `+` 之前的部分 MUST NOT 被加上語言限制

#### Scenario: 範本沒有 format 參數時補上受限的預設

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** 該任務的下載指令範本不含 `-f` 或 `--format` 引數
- **WHEN** 系統執行該任務的下載
- **THEN** 實際 yt-dlp invocation 的引數 SHALL 包含 `-f` 與緊接其後的 `bv*+ba[language=ja]/b[language=ja]`

##### Example: 取不到選定語言時以失敗結束

- **GIVEN** 某任務的音軌選擇為語言代碼 `ja`
- **AND** yt-dlp 以 `ERROR: [youtube] video: Requested format is not available.` 與非 0 exit code 結束
- **WHEN** 系統處理該次下載結果
- **THEN** 該任務 SHALL 進入失敗狀態並呈現該訊息
- **AND** 系統 MUST NOT 因該訊息觸發帶 cookies 的重試或任何其他重試
- **AND** 該次下載的 yt-dlp invocation 次數 SHALL 恰為 1

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
