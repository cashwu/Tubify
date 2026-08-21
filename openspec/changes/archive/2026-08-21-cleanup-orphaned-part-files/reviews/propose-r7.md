# Cash Propose Review — Round 7

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 逐一驗證並檢查 Round 6 修復的 fix propagation。

### Cumulative blocking set verdicts

- **M1: resolved** — Reviewer V 以 C 程式在 APFS 上實測：`unlink(含檔案的目錄)` 回傳 -1、`errno == 1 (EPERM)`、目錄與內層檔案完好；`unlink(指向目錄的 symlink)` 回傳 0、連結消失而 target 內容完好。task 1.18 的四項斷言全部可通過，且該測試不經過候選條件序列、`unlink` 確實被呼叫，對決策 9 具鑑別力。Contract 第 9 點與 spec scenario「刪除操作本身拒絕目錄」語意一致並由 1.18 驅動；Contract 第 2 點已補「被過濾掉的項目既不列入 `deleted` 也不列入 `failed`」，恆紅斷言的成因消除，1.18 亦不再與 1.14 重複。verifying reviewer：Reviewer V。
- **W1: resolved** — task 2.2 的簽名已含 `observer:`，與同一 task 後半段的 observer 要求一致。verifying reviewer：Reviewer V。
- **W2: resolved** — spec 現為 5 項條件，全域無「條件 6」殘留；spec、design、tasks 中所有「條件 N」引用逐一核對皆指向正確條目。Reviewer V 另以 9 種最終檔名形狀（含 `a.b.mp4`、`video.mp4.part`、`clip.f401.mp4.part`、無副檔名、CJK 標題）重跑形態比對，剩餘部分全部不 match，證實 `path != finalPath` 恆為真，移出 spec 規範性條件而由決策 2 記為 defence-in-depth 的處置正確。verifying reviewer：Reviewer V。
- **W3: resolved** — 新增的 task 3.3 逐字列出四個致命 return 與兩個非致命 continue，與決策 6 的四項致命及 Contract 第 3 點的四個 `AbandonReason` 完全對齊；原 3.3 已重編為 3.4；Contract 第 8 點末段已改為指向該 code review task。verifying reviewer：Reviewer V。
- **W4: resolved** — Contract 第 8 點的 7 項與 seam task 1.10、1.11、1.12、1.13、1.15、1.16、1.17 恰好一一對應（1.18 已移出改屬第 9 點）。Reviewer V 另核對 Contract 第 7 點的 10 個覆蓋項對應 tasks 1.2–1.9 與 1.14，第 9 點對應 1.18；spec 14 個 scenario 與 5 個 `##### Example:` 全數有 task 驅動。verifying reviewer：Reviewer V。

五個 member 皆以 verified resolution 離開 cumulative blocking set，該集合現為空。

### Suggestion

**F1**（Reviewer V，原報 Warning `confidence` 75，經 confidence filter 降級）
- `location`: design.md Implementation Contract 第 8、9 點
- `summary`: 新增的 Contract 第 9 點被插入在第 8 點與其 body 之間，把原屬第 8 點的五段規範性內文全部吞併——注入手段、致命失敗的 observer 斷言要求、非致命失敗的 `failed`／`deleted` 斷言、`defer` 還原要求、`chflags uchg` 注入五段都縮排掛在第 9 點底下。後果有二：tasks 1.10／1.11／1.13／1.15／1.16／1.17 引用的「第 8 點」形式上只剩一句覆蓋清單；而唯一引用第 9 點的 task 1.18 會讀到五段與「不經過候選條件序列」直接衝突的 seam 要求。實質要求未遺失（相關 tasks 已各自逐字複述），屬歸屬錯置。
- `disposition`: fix-introduced
- `introduced_by`: Round 6 的 M1／W4 修復新增 Contract 第 9 點時，插入位置在第 8 點的 body 之前。

**F2**（Reviewer V，`confidence` 65，`layer` text，`disposition` unresolved-prior）
- `location`: design.md Implementation Contract 第 8 點的 `chmod` 說明
- `summary`: Round 6 的 S1 逐字列出該處為以 `removeItem` 為前提的過期敘述之一，但 Fix Actions 只處理了另外三處。該段仍寫「唯讀檔案仍會被 `FileManager.removeItem` 成功刪除」，而決策 9 已 `MUST NOT` 使用它；對應的 task 1.12 已改為 API-neutral 措辭，兩者不同步。論證本身仍成立（`unlink` 同樣取決於父目錄寫入權限），僅為過期的 API 名稱。

**F3**（Reviewer V，`confidence` 50，`disposition` fix-introduced，`introduced_by`: Round 6 的 S2 修復）
- `location`: tasks.md 2.2；design.md Implementation Contract 第 3 點
- `summary`: S2 新增的排序要求寫在 Contract 第 3 點，但排序發生在呼叫 observer 之前、屬 task 2.2 的職責；task 2.2 只引用第 2 點，而第 2 點沒有提到排序。若實作者依 2.2 逐條實作而未回讀第 3 點，tasks 1.12／1.17「兩個陣列已由實作排序」的前提就不成立，正是 S2 要防的 APFS 列舉順序 flaky。

**F4**（Reviewer V，`confidence` 50，`disposition` new）
- `location`: tasks.md 1.11
- `summary`: Round 6 的 S3 為 task 1.10 補上「`outputDirectory` MUST 實際存在」，但同樣依賴檢查順序的 1.11（斷言 `.finalPathUnavailable`）沒有這句。快照檢查排在最前面，若照抄既有 seam 測試的 `/Downloads`，outcome 會是 `.snapshotUnavailable` 而非目標值。失敗方向是紅燈而非假綠燈。

### 經 confidence filter 丟棄的 findings

Reviewer V 另回報兩個 `confidence` 45 的 finding，依 confidence filter 丟棄，downgrade trace 記於 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- 非 blocking triaged finding count: 4
- `critical_gap`: false
- `round_type`: micro

rationale：cumulative blocking set 的五個 member M1、W1–W4 均取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開集合，集合現為空。本輪新增的六個 finding 中，最高 `confidence` 為 75，經 confidence filter 後全部為 `Suggestion`（兩個 `confidence` 45 者遭丟棄），依規則不進入 cumulative blocking set、不造成 `next_round`。pass 條件成立，因此 `decision: passed`。

## Fix Actions

pass 條件在任何修復之前即已成立（cumulative blocking set 為空）。以下四項 `Suggestion` 與兩項已丟棄 finding 的文件面建議一併修復：F1 是 markdown 結構的歸屬錯置，會讓 task 1.18 讀到與其自身要求直接衝突的段落；F6 的列舉不一致會使 `failed` 的歸屬未定義而讓斷言預期值算錯。兩者都會在 apply 階段造成實質誤導，因此不留待下一輪。

**F1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md`，把 Implementation Contract 第 9 點（標題行與其唯一的說明段）整段移到第 8 點所有內文之後。第 8 點恢復領有五段規範性內文（注入手段、致命失敗的 observer 斷言與區辨性候選檔要求、非致命失敗的斷言、`defer`／`addTeardownBlock` 還原要求、`chflags uchg` 注入），第 9 點只保留其自身兩段。

**F2 — 修復**。修改 design.md Implementation Contract 第 8 點的 `chmod` 說明，把「唯讀檔案仍會被 `FileManager.removeItem` 成功刪除」改為「唯讀檔案仍會被 `unlink` 成功刪除」，與決策 9 及 task 1.12 一致。論證結論不變。

**F3 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md` task 2.2，引用由「Contract 第 2 點」改為「第 2、3 點」，並補一句「呼叫 `observer` 前 MUST 將 `deleted` 與 `failed` 以檔名遞增排序（Contract 第 3 點）」，使排序要求出現在實作側 task 而非只在斷言側。

**F4 — 修復**。修改 tasks.md task 1.11，比照 1.10 補上「`outputDirectory` MUST 在取得快照前即存在，否則會先命中 `.snapshotUnavailable` 而非目標的 `.finalPathUnavailable`」。

**Downgrade trace — Reviewer V F5（`confidence` 45，`layer` text，`disposition` new）已依 confidence filter 丟棄**。該 finding 指出 W2 修復後 spec 規範性條件為 5 項，但 tasks 2.2 與 design Risks 仍說「六項條件」；Reviewer V 自述兩處嚴格說並不算錯（Contract 第 2 點的候選序列確實是 6 項，含一項 defence-in-depth 比對），只是數字並置容易讓讀者誤以為漏改。雖已丟棄，主 agent 仍採納其文件面建議：tasks 2.2 改為「候選條件序列」、design Risks 的 hardlink 條目改為「名稱與屬性滿足 Contract 第 2 點候選條件序列的 hardlink」，兩處都不再帶數字。此處置不改變任何條件內容。

**Downgrade trace — Reviewer V F6（`confidence` 45，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 6 的 M1 修復）已依 confidence filter 丟棄**。該 finding 指出 Contract 第 2 點寫「被名稱層條件、型別檢查或 mtime 條件過濾掉的項目」，第 3 點卻只寫「被名稱層條件或型別檢查過濾掉的項目」，漏了 mtime，使 mtime 不合的項目歸屬未定義。雖已丟棄，主 agent 判定其後果具體（實作者可能把 mtime 不合的項目放進 `failed`，使 tasks 1.12／1.17「其餘候選檔名出現在 `deleted`」的預期值算錯），已修復：第 3 點的列舉補上 mtime 條件，與第 2 點一致。

**驗證**：修復涉及 design 與 tasks 兩個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；並重跑 mechanical self-check，確認 14 個 scenario 全數被 tasks 覆蓋、決策 1–10 與 Contract 1–9 連續、tasks 編號 1.1–1.18／2.1–2.3／3.1–3.4 連續、annotation 平衡、全域無「六項」與「條件 6」殘留、剩餘的 `FileManager.removeItem` 三處皆為 `MUST NOT` 或對比敘述。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

passed
