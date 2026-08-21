## ADDED Requirements

### Requirement: 跨 process 重試後的孤兒中間檔清理

系統在單次下載流程整體成功並取得最終輸出路徑後，SHALL 清除由該次流程較早失敗 attempt 留下的孤兒中間檔。`YTDLPService.download` 的所有成功路徑都經過該收尾點。

設最終輸出路徑為 `<dir>/<stem>.<ext>`。候選檔案 SHALL 限定為 `<dir>` 的直接內容，且 MUST 同時滿足下列全部條件才可刪除：

1. `<dir>` 與該次下載的輸出目錄相同
2. 該檔名不存在於本次下載流程啟動第一個 attempt 前所取得的輸出目錄檔名快照中
3. 檔名以 `<stem>.` 開頭，且去掉該前綴後的剩餘部分整體符合 `^(f[0-9]+\.)?[A-Za-z0-9]{1,5}\.(part|ytdl|part-Frag[0-9]+)$`
4. 該檔的 content modification date 早於最終輸出檔的 content modification date
5. 該項目是一般檔案（regular file）

最終輸出檔本身不需要獨立的排除條件：其檔名去掉 `<stem>.` 前綴後恰為單一副檔名而不含點，條件 3 的每個分支都要求剩餘部分至少含一個點，因此最終輸出檔在任何形狀下都不可能通過條件 3。

在條件 5 評估時為目錄、symbolic link 或其他非一般檔案的項目 MUST NOT 被刪除，即使其名稱符合條件 3 的形態。條件 4 與條件 5 所需的屬性 SHALL 以單次讀取一併取得；該次讀取失敗時，該項目 MUST NOT 被刪除。

條件 5 是刪除前的檢查，與刪除之間存在時間差。上一段的要求以條件 5 的評估時點為準，因此在該時點之後才發生的型別替換不在其適用範圍內。系統對這段時間差只提供一項保證，其餘情形明文不保證：

- **目錄**：刪除操作本身 SHALL 對任何目錄一律失敗且不移除該目錄項目，使「目錄不被刪除」完全不依賴條件 5 的時效性。即使某個路徑在條件 5 通過之後才被替換成目錄——無論該目錄是否為空——刪除仍 MUST 失敗且該目錄 MUST 保持完整。
- **其餘所有情形**：條件 5 通過之後被替換成任何非目錄項目（symbolic link、FIFO、socket 等其他非一般檔案，或另一個一般檔案）時，刪除操作可能移除該路徑名稱，系統不保證其存續；若刪除操作失敗，系統 SHALL 依單一候選檔的非致命失敗規則處理。刪除操作 MUST NOT 跟隨 symbolic link，因此當被替換成 symbolic link 且刪除成功時，其指向的內容 MUST 保持完整；被替換成另一個一般檔案且刪除成功時則會連同該檔內容一併失去，這是本窗口最壞的後果。

此窗口無法以現有系統呼叫消除：macOS 未提供「把受檢項目綁定為 inode identity、再以該 identity 為條件刪除」的原語。

系統 SHALL 在每個放棄整輪清理的路徑、每個候選檔處理失敗的路徑與每次成功刪除留下可觀察的結果，使這些路徑可被驗收。

清理 MUST NOT 改變下載回傳值，MUST NOT 使成功的下載轉為失敗，也 MUST NOT 拋出錯誤。

#### Scenario: 較早 attempt 留下的中間檔被刪除

- **GIVEN** 較早的 attempt 失敗並在輸出目錄留下 `<stem>.f401.mp4.part`
- **AND** 該檔不在本次下載流程啟動前的目錄快照中
- **AND** 後續 attempt 選中不同格式並成功產出 `<stem>.mp4`
- **AND** `<stem>.f401.mp4.part` 的 content modification date 早於 `<stem>.mp4`
- **WHEN** 系統完成該次下載
- **THEN** 系統 SHALL 刪除 `<stem>.f401.mp4.part`
- **AND** 系統 SHALL 回傳 `<stem>.mp4` 的路徑

##### Example:

最終輸出為 `/tmp/dl/火箭降落的全过程，拍到了！.mp4`，同目錄殘留 `/tmp/dl/火箭降落的全过程，拍到了！.f401.mp4.part`。剩餘部分 `f401.mp4.part` 符合形態條件。下載結束後該檔不再存在，`.mp4` 仍存在，下載回傳 `/tmp/dl/火箭降落的全过程，拍到了！.mp4`。

#### Scenario: 同一主幹的續傳中繼檔與 fragment 暫存檔一併刪除

- **GIVEN** 輸出目錄中存在 `<stem>.f401.mp4.part`、`<stem>.f401.mp4.ytdl` 與 `<stem>.f251.webm.part-Frag12`
- **AND** 三者都不在目錄快照中，且 content modification date 都早於最終輸出檔
- **WHEN** 該次下載整體成功
- **THEN** 系統 SHALL 刪除這三個檔案

#### Scenario: 最終輸出檔與字幕檔保留

- **GIVEN** 輸出目錄中存在最終輸出檔 `<stem>.mp4` 與字幕檔 `<stem>.zh-TW.srt`
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除 `<stem>.mp4`
- **AND** 系統 MUST NOT 刪除 `<stem>.zh-TW.srt`

##### Example:

`<stem>.zh-TW.srt` 去掉 `<stem>.` 前綴後的剩餘部分為 `zh-TW.srt`，不符合形態條件，因此不是候選檔案。

#### Scenario: 其他影片的中間檔保留

- **GIVEN** 最終輸出檔為 `<stem>.mp4`
- **AND** 同目錄存在檔名主幹不同的 `<other-stem>.f401.mp4.part`
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除 `<other-stem>.f401.mp4.part`

#### Scenario: 名稱符合形態的目錄與 symbolic link 保留

- **GIVEN** 輸出目錄中存在名為 `<stem>.f401.mp4.part` 的目錄，其中含有其他檔案
- **AND** 同目錄存在名為 `<stem>.f402.mp4.part` 的 symbolic link
- **AND** 兩者都不在目錄快照中，且 content modification date 都早於最終輸出檔
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除該目錄
- **AND** 系統 MUST NOT 刪除該目錄中的任何檔案
- **AND** 系統 MUST NOT 刪除該 symbolic link

##### Example:

條件 5 在型別檢查階段就排除這兩個項目，使它們不進入刪除路徑。若目錄是在條件 5 之後才出現於該路徑，刪除操作本身仍會拒絕它；symbolic link 沒有這層兜底，其情形見上方 requirement 對時間差的說明。

#### Scenario: 刪除操作本身拒絕目錄

- **GIVEN** 系統要刪除的路徑指向一個目錄
- **WHEN** 系統執行刪除操作
- **THEN** 刪除 SHALL 失敗
- **AND** 該目錄與其中的檔案 MUST 保持完整

##### Example:

POSIX `unlink` 對目錄以 `EPERM` 失敗且目錄完好，且與該目錄是否為空無關——`FileManager.removeItem(atPath:)` 會遞迴刪除目錄連同其中的使用者資料，`rmdir` 與 libc `remove(3)` 雖不遞迴卻會刪掉空目錄，兩者都不滿足這條 scenario。此 scenario 驗收的是刪除操作本身的性質，與條件 5 是否先攔下該項目無關——正因如此，「即使路徑在條件 5 通過之後才被替換成目錄，刪除仍失敗」這個保證才成立。

#### Scenario: 刪除操作不跟隨 symbolic link

- **GIVEN** 系統要刪除的路徑是一個指向目錄的 symbolic link
- **WHEN** 系統執行刪除操作
- **THEN** 刪除 SHALL 只移除該連結本身
- **AND** 其 target 與其中的檔案 MUST 保持完整

##### Example:

條件 5 評估時就是 symbolic link 的項目本來就不會進入刪除路徑。此 scenario 驗收的是刪除原語的性質——若某個路徑在條件 5 通過之後才變成 symbolic link，刪除不會跟隨它，因此損失限於該連結名稱本身。

#### Scenario: 主幹為前綴且含點的其他影片中間檔保留

- **GIVEN** 最終輸出檔為 `Lecture 1.mp4`
- **AND** 另一個並行任務在同目錄寫入 `Lecture 1.5.f401.mp4.part`
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除 `Lecture 1.5.f401.mp4.part`

##### Example:

`Lecture 1.5.f401.mp4.part` 以 `Lecture 1.` 開頭，但剩餘部分 `5.f401.mp4.part` 不符合形態條件，因此不是候選檔案。

#### Scenario: 下載開始前就已存在的中間檔保留

- **GIVEN** 輸出目錄在本次下載流程啟動第一個 attempt 前已存在 `<stem>.mp4.part`
- **AND** 該檔名因此存在於目錄快照中
- **WHEN** 該次下載整體成功並產出 `<stem>.mp4`
- **THEN** 系統 MUST NOT 刪除 `<stem>.mp4.part`

#### Scenario: mtime 不早於最終輸出檔的中間檔保留

- **GIVEN** 輸出目錄中存在不在快照中的 `<stem>.f401.mp4.part`
- **AND** 其 content modification date 不早於最終輸出檔的 content modification date
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除 `<stem>.f401.mp4.part`

#### Scenario: 最終輸出檔不在該次下載的輸出目錄時不清理

- **GIVEN** 最終輸出路徑的父目錄與該次下載的輸出目錄不相同
- **WHEN** 該次下載整體成功
- **THEN** 系統 MUST NOT 刪除任何檔案

#### Scenario: 下載最終失敗時不刪除任何檔案

- **GIVEN** 該次下載的所有 attempts 都失敗，整體以錯誤結束
- **AND** 輸出目錄中存在 `<stem>.f401.mp4.part`
- **WHEN** 系統結束該次下載
- **THEN** 系統 MUST NOT 刪除 `<stem>.f401.mp4.part`
- **AND** 系統 SHALL 原樣拋出既有錯誤

#### Scenario: 判斷前提不成立時放棄整輪清理

- **GIVEN** 目錄快照未能取得、最終輸出檔不存在或無法讀取其 content modification date、或輸出目錄列舉失敗
- **WHEN** 系統執行清理
- **THEN** 系統 SHALL 記錄該失敗
- **AND** 系統 SHALL 產生一個可觀察的結果，指出清理已放棄與其原因
- **AND** 系統 MUST NOT 刪除任何檔案
- **AND** 系統 SHALL 回傳原本的最終輸出路徑

#### Scenario: 單一候選檔處理失敗時繼續處理其餘候選檔

- **GIVEN** 輸出目錄中存在多個符合全部條件的候選檔
- **AND** 其中一個候選檔的屬性讀取失敗或刪除失敗
- **WHEN** 系統執行清理
- **THEN** 系統 SHALL 記錄該失敗並繼續處理其餘候選檔案
- **AND** 系統 SHALL 產生一個可觀察的結果，區分處理失敗與成功刪除的候選檔
- **AND** 系統 SHALL 刪除其餘符合條件的候選檔
- **AND** 系統 SHALL 回傳原本的最終輸出路徑
- **AND** 系統 MUST NOT 因該失敗拋出錯誤

#### Scenario: 刪除中間檔留下可辨識日誌

- **GIVEN** 系統刪除了一個孤兒中間檔
- **WHEN** 系統記錄該次刪除
- **THEN** 日誌 SHALL 包含 task ID 與被刪除的檔名
