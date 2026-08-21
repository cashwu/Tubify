# Cash Apply Review — Round 2

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 驗證並檢查 Round 1 修復的 fix propagation。

### Cumulative blocking set verdict

- **M1: resolved** — Reviewer V 以 mutation 實測確認修復具鑑別力：把快照 guard 改成恆真式後，`testCleanupKeepsPartFilePresentBeforeDownloadStarted` 由綠轉紅（`XCTAssertTrue failed`）。修復後的 `video.mp4.part` mtime 明確設為 `Date(timeIntervalSince1970: 1_000_000)`，早於 fixture 最終輸出檔的 `202001020000`，且其 remainder `mp4.part` 通過形態比對、`isRegularFile` 為 true、`name != finalName` 成立——快照確實成為唯一攔截條件，決策 3 的動機情境（Firefox `Report.mp4.part`）現在有具鑑別力的驗收。mutation 已還原（md5 與備份一致，`grep -c 'true ||\|false &&'` 為 0）。verifying reviewer：Reviewer V。

cumulative blocking set 現為空。

### 一併驗證通過的 Round 1 修復

- **S4（CJK 主幹）確認真正走到清理程式碼**：日誌輸出 `清理孤兒中間檔 taskId=… 已刪除=火箭降落的全过程，拍到了！.f401.mp4.part`，證明該檔通過全部五個條件並實際被 `unlink` 刪除，而非在更早條件被攔下。fixture script 的 `IFS='|' read` 與 `: > "$rel"` 皆以雙引號包住變數，對含 CJK 與全形標點的位元組序列無影響；`stemPrefix.count` 為 grapheme cluster 計數，`hasPrefix` 先於 `dropFirst` 求值，CJK 與全形標點無 canonical decomposition，NFC/NFD 不構成風險。
- **S1（guard 順序）無行為副作用**：四個條件皆為純函式、以 `,` 連接的 AND 且失敗一律 `continue`，重排不改變任何項目的通過與否；`hasPrefix` 仍排在 `dropFirst` 之前，短路求值使其安全性成立。
- **S3（候選 URL 建構）**：與 Contract 字面一致，未使用預取快取。
- **errno 修復正確**：`let unlinkErrno = errno` 為 else 分支第一個敘述，`unlink` 與擷取之間無其他系統呼叫。
- **無新的假綠燈**：逐一複查七個「保留」類測試的攔截條件歸屬，每個條件都有恰好對應的攔截測試，無錯置；四個致命失敗測試皆以 observer 的 `AbandonReason` 相等性斷言，具鑑別力。

### Suggestion

**V1**（Reviewer V，`confidence` 70，`disposition` new）
- `location`: `Tubify/Services/YTDLPService.swift` 的 `observer?(.completed(deleted:failed:))`；`TubifyTests/YTDLPServiceTests.swift` 的 `testCleanupContinuesAfterUnlinkFailure`
- `summary`: Round 1 的 S2 修復確實讓 `.sorted()` 具備鑑別力，但那是**機率性**而非確定性的。Reviewer V 拿掉兩處 `.sorted()` 後以 12 次獨立 test host process 執行，結果為 4 PASS / 8 FAIL。根因不是 Contract 第 3 點所述的 `contentsOfDirectory` 回傳順序，而是實作把列舉結果收斂成 `Set<String>` 後才迭代，Swift 的 `Set` 迭代順序由 per-process 隨機 hash seed 決定，每次 process 啟動都重新洗牌。兩個元素只有 2 種排列，任一次 CI 執行有約 50% 機率恰好命中排序後的順序而漏掉迴歸。
- `recommendation`: 在該測試再加一個候選檔使 `deleted` 達 3 個元素，把漏檢率由 1/2 降到 1/6。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- 非 blocking triaged finding count: 1
- `critical_gap`: false
- `round_type`: micro

rationale：cumulative blocking set 的唯一 member M1 取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開集合，集合現為空。本輪新增的 V1 `confidence` 70，經 confidence filter 後為 `Suggestion`，依規則不進入 cumulative blocking set、不造成 `next_round`。pass 條件成立，因此 `decision: passed`。

## Fix Actions

pass 條件在任何修復之前即已成立（cumulative blocking set 為空）。V1 為非 blocking 的 `Suggestion`，依規則可僅記為 triage note；但它指出的是「排序要求的迴歸偵測率只有約 50%」，若 `.sorted()` 日後被誤刪可能連續數次全綠才暴露，修復成本僅為多建立一個候選檔，因此一併處理。

**V1 — 修復**。修改 `TubifyTests/YTDLPServiceTests.swift` 的 `testCleanupContinuesAfterUnlinkFailure`：新增第三個可刪候選檔 `video.f603.mp4.part`，三個候選檔以非字典序建立，`deleted` 的預期值同步為三個元素的排序陣列，漏檢率由 1/2 降至 1/6。同時把三個檔案的存在性斷言收斂為迴圈，並加註解說明根因是 `Set` 的 per-process 隨機迭代順序而非 `contentsOfDirectory` 的回傳順序。

**驗證**：修復只涉及 `TubifyTests/YTDLPServiceTests.swift`。已重新執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，結果為 **310 tests, 0 failures**。

**工作樹狀態**：Reviewer V 收尾時確認無殘留 mutation——實作檔 md5 與 mutation 前備份一致、`grep -c 'true ||\|false &&'` 對實作與測試檔皆為 0、兩處 `.sorted()` 完整、`git status --short` 僅顯示本 change 預期的檔案。

**Change 目錄外檔案修改**：本輪 Fix Actions 修改了 `TubifyTests/YTDLPServiceTests.swift`，不在 `openspec/changes/` 下，已以 `touched record` 記錄。

## Decision

passed
