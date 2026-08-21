# Cash Apply Review — Round 1

## Reviewer Findings

本輪為 apply loop 新 run 的第一輪（full round，unseeded），所有 surviving `Critical` 與 `Warning` 皆為 blocking，不標註 `disposition`。

### Warning

**M1**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併；兩者 `layer` 不同，依規則取 `design`）
- `severity`: Warning
- `confidence`: 95
- `layer`: design（Reviewer A 標 `design`、Reviewer B 標 `text`，合併取 `design`）
- `location`: `TubifyTests/YTDLPServiceTests.swift` 的 `testCleanupKeepsPartFilePresentBeforeDownloadStarted`；對應實作 `Tubify/Services/YTDLPService.swift` 的快照 guard
- `summary`: 該測試宣稱驗收 spec 條件 2（目錄快照）與 design 決策 3，但實際攔下該檔的是條件 4（mtime）。測試以 `try "stale".write(to:)` 建立 `video.mp4.part`，其 mtime 為執行當下的真實時間（2026），而 fixture 的最終輸出檔以 `touch -t 202001020000` 設為 2020 年，因此 `modifiedAt < finalModifiedAt` 恆為 false，該檔在快照條件存在與否時都會被保留。Reviewer B 以 mutation 實測確認：把快照 guard 換成恆真式後 `YTDLPServiceTests` 全部 85 個測試仍全綠。更關鍵的是決策 3 的動機情境——Firefox 留下的 `Report.mp4.part`，mtime 早於最終檔、只有快照擋得住——在整個測試集中完全沒有被覆蓋，快照條件的「命中」路徑無任何具鑑別力的驗收。這正是 `openspec/signals/unreachable-guard-or-dead-test.md`（occurrences 5）與 `openspec/signals/test-setup-bypasses-target-condition.md` 描述的形態，也正是 design Implementation Contract 第 6 點自己警告過「這對每一個『保留』類測試都成立」的情況。
- `recommendation`: 把該預先存在檔案的 mtime 明確設早於最終輸出檔，使快照成為唯一的攔截條件；修改後以 mutation 確認移除快照 guard 會讓該測試轉紅。
- `introduced_by`: `TubifyTests/YTDLPServiceTests.swift` 新增的 `testCleanupKeepsPartFilePresentBeforeDownloadStarted`（tasks.md 1.7）

Reviewer B 另提供對照組，證明其餘四個條件都具鑑別力：拿掉 `hasPrefix` 使 `testCleanupKeepsPartFileOfDifferentStem` 失敗、拿掉形態比對使 `testCleanupKeepsFinalOutputAndSubtitleFile` 與 `testCleanupKeepsPartFileWhoseStemIsDottedPrefixExtension` 失敗、拿掉 `isRegularFile` 使 `testCleanupKeepsDirectoryAndSymlinkMatchingCandidateShape` 的 symlink 斷言失敗、拿掉 mtime 條件使 `testCleanupKeepsCandidateWhoseMtimeIsNotEarlierThanFinalOutput` 失敗。

### Suggestion

**S1**（Reviewer A，`confidence` 100）
- `location`: `Tubify/Services/YTDLPService.swift` 候選條件 guard 鏈；對照 design Implementation Contract 第 2 點
- `summary`: Contract 明列順序為「快照 → `<stem>.` 前綴 → 形態 → `path != finalPath`」，實作把第 4 順位的 defence-in-depth 比對提前到第 2 順位。四者皆為 AND 且失敗都是 `continue`，行為無差異，但與 Contract 字面不一致。另實作以檔名比對 `name != finalName` 取代 Contract 的路徑比對（同目錄下等價）。

**S2**（Reviewer A，`confidence` 85）
- `location`: `Tubify/Services/YTDLPService.swift` 的 `.sorted()`；測試 `testCleanupContinuesAfterUnlinkFailure`、`testCleanupContinuesAfterAttributeReadFailure`
- `summary`: Contract 第 3 點的排序要求理由是「不排序會讓任何含兩個以上元素的相等性斷言在 CI 上間歇失敗」，但所有觀察 observer 的測試其 `deleted` 與 `failed` 各只含 1 個元素。拿掉 `.sorted()` 沒有任何測試會轉紅，該規範性要求目前是未被驗收的死條文。

**S3**（Reviewer A，`confidence` 100）
- `location`: `Tubify/Services/YTDLPService.swift` 候選 URL 建構
- `summary`: Contract 第 2 點要求「對該項目**新建**一個 `URL(fileURLWithPath:)`」，實作改用 `parentDirectory.appendingPathComponent(name)`。兩者都不會帶入預取快取（MUST NOT 條款已滿足），但與 Contract 字面手段不同，且不帶 `isDirectory:` 的 `appendingPathComponent` 會額外做一次檔案系統查詢。

**S4**（Reviewer B，`confidence` 65）
- `location`: `TubifyTests/YTDLPServiceTests.swift` 的 `testCleanupRemovesPartFileLeftByEarlierAttempt`
- `summary`: delta spec 中 scenario「較早 attempt 留下的中間檔被刪除」的 `##### Example:` 以 `火箭降落的全过程，拍到了！.mp4` 為驗收樣本（本 change 的動機案例），但 9 個 production fixture 測試全部只用 ASCII 主幹，該 Example 未被任何測試驗證。Reviewer B 另獨立實測完整條件序列在 CJK、NFC/NFD 拉丁雙向、Hangul 組合字與 emoji 主幹下都正確，因此是覆蓋缺口而非缺陷。

### 經 confidence filter 丟棄的 findings

三個 `confidence` 45 的 finding 依 confidence filter 丟棄，downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- 非 blocking triaged finding count: 4
- `critical_gap`: false
- `round_type`: full

rationale：本輪為新 run 的第一輪，唯一的 Warning M1 進入 cumulative blocking set。M1 由兩位 reviewer 獨立提出，且 Reviewer B 以 mutation 實測提供決定性證據（移除快照 guard 後 85 個測試仍全綠），`introduced_by` 指向本次 diff 新增的具體測試，證據可驗證。存在 blocking Warning，因此 `decision: next_round`。

## Fix Actions

**M1 — 修復**。修改 `TubifyTests/YTDLPServiceTests.swift` 的 `testCleanupKeepsPartFilePresentBeforeDownloadStarted`：在建立預先存在的 `video.mp4.part` 之後，以 `setAttributes([.modificationDate:])` 把其 mtime 明確設為早於最終輸出檔的時間，並加註解說明為何不能沿用寫入當下的時間。修復後以 mutation 驗證：把實作的快照 guard 換成恆真式，該測試由綠轉紅（`XCTAssertTrue failed`），確認快照條件現在有了鑑別力；mutation 隨即還原，`grep 'true ||'` 為 0。

**S1 — 修復**（非 blocking，一併處理）。修改 `Tubify/Services/YTDLPService.swift`，把 `name != finalName` 從第 2 順位移到形態比對之後，使 guard 鏈順序與 Contract 第 2 點的明列順序逐字對應。

**S2 — 修復**（非 blocking，一併處理）。修改 `testCleanupContinuesAfterUnlinkFailure`，新增第三個候選檔 `video.f140.m4a.part` 並刻意以與字典序相反的順序建立，使 `deleted` 含兩個元素，`.sorted()` 的排序要求因此被相等性斷言真正驗收。

**S3 — 修復**（非 blocking，一併處理）。修改 `Tubify/Services/YTDLPService.swift`，候選路徑改以 `URL(fileURLWithPath: parentDirectory.path + "/" + name)` 建構，與 Contract 字面一致並省去 `appendingPathComponent` 的額外檔案系統查詢。

**S4 — 修復**（非 blocking，一併處理）。修改 `testCleanupRemovesPartFileLeftByEarlierAttempt`，主幹改為 spec Example 的 `火箭降落的全过程，拍到了！`，以零額外成本覆蓋該 `##### Example:`。

**Downgrade trace — Reviewer B `confidence` 45（errno 讀取時機）已依 confidence filter 丟棄**。該 finding 指出 `errno` 不是在 `unlink` 回傳 -1 後立即擷取，而是在建構日誌插值字串的過程中才讀取；目前不會出錯，但正確性依賴呼叫順序而非程式碼結構，日後在該行之前插入任何系統呼叫就會靜默記錄到錯誤的 errno。雖已丟棄，主 agent 判定其修法只有一行且消除了一個真實的未來隱患，已修復：在 else 分支第一行擷取 `let unlinkErrno = errno`，日誌改用該區域變數。

**Downgrade trace — Reviewer A `confidence` 45（task 1.13 的實作方式與環境依賴）已依 confidence filter 丟棄**。該 finding 指出 `testExistingSeamTestsProduceNoFilesystemSideEffects` 複製既有 seam 測試的形態而非對既有測試本身加斷言，且斷言 `.snapshotUnavailable` 隱含依賴「機器上 `/Downloads` 不存在」。雖已丟棄，主 agent 採納其環境依賴部分的建議，改用 `/Downloads-<UUID>` 消除該前提；未改為對既有測試逐一加斷言，因為現行測試已完整驗證「不存在的輸出目錄使清理無任何副作用」這個性質。

**Downgrade trace — Reviewer B `confidence` 45（目錄斷言的鑑別力歸屬）已依 confidence filter 丟棄**。該 finding 指出 `testCleanupKeepsDirectoryAndSymlinkMatchingCandidateShape` 中「目錄與其內層檔案仍存在」兩項斷言對型別檢查沒有鑑別力——mutation 實測顯示拿掉 `isRegularFile` 只有 symlink 斷言轉紅，因為 `unlink` 對目錄本來就以 EPERM 失敗。Reviewer B 自述這與決策 9／spec Example 的說法一致，不是錯誤。主 agent 採納其註解建議，在該測試加註說明目錄斷言的實際保護來源是 `unlink`、型別檢查的鑑別力由 symlink 斷言承擔。

**併發衝突處理紀錄**：Reviewer A 回報審查期間 `Tubify/Services/YTDLPService.swift` 曾被整份還原成 HEAD，並以先前擷取的 diff 重建。成因是主 agent 授權 Reviewer B 以 mutation 驗證測試鑑別力，兩個 reviewer 同時操作同一檔案。Reviewer B 完成後已自行還原全部 mutation。主 agent 在修復前先驗證工作樹完整性：`git diff --stat` 為 `703 insertions(+), 16 deletions(-)`、五個關鍵實作行完整、`grep 'true ||\|false &&'` 為 0，確認無殘留 mutation 後才開始修改。

**驗證**：修復涉及 `Tubify/Services/YTDLPService.swift` 與 `TubifyTests/YTDLPServiceTests.swift` 兩個檔案。已重新執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，結果為 **310 tests, 0 failures**；並以 mutation 確認 M1 的修復具鑑別力後還原。

**Change 目錄外檔案修改**：本輪 Fix Actions 修改了 `Tubify/Services/YTDLPService.swift` 與 `TubifyTests/YTDLPServiceTests.swift`，兩者都不在 `openspec/changes/` 下，將以 `touched record` 記錄。

## Decision

next_round

cumulative blocking set 中有 1 個 Warning（M1）已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第一輪，下一輪位置為第二輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 M1 給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
