# Cash Propose Review — Round 5

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 逐一驗證並檢查 Round 4 修復的 fix propagation。

### Cumulative blocking set verdicts

- **W1: resolved** — 決策 6 與 Implementation Contract 第 2 點已明訂兩個屬性以單次 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])` 一併讀取、收斂為單一非致命分支；tasks 2.2 同步，新增 task 1.17 以 ACL 驅動該分支，原 task 3.3 的 code review 豁免已移除。Reviewer V 實測確認注入可行：對候選檔設定 ACL `deny readattr` 後，該檔仍出現在 `contentsOfDirectory(atPath:)` 結果中，而新建 `URL(fileURLWithPath:)` 的 `resourceValues` 對兩個 key 整批以 `NSCocoaErrorDomain` 257 失敗，同目錄其他檔案讀取正常。另實測確認決策 6 對「最終輸出檔無法讀取 mtime」的論證成立：對最終輸出檔設 ACL 後 `fileExists` 回傳 false 且 `resourceValues` 同以 257 失敗，兩個觸發條件無法分離，由 task 1.11 覆蓋同一段 guard 成立。六條分支與日誌皆有歸屬，無「既無測試也無 code review」的分支。verifying reviewer：Reviewer V。
- **W2: resolved** — Contract 第 5 點、task 1.1、task 1.14 三處對「MUST 由 fixture 在 invocation 期間建立」「symlink 用 `touch -h -t`」「目錄的 `touch -t` 在建立內層檔案之後」的表述一致。Reviewer V 以 shell 實測（`bash` 與 `sh` 皆通過）確認 `touch -h -t` 對指向既有檔案的 symlink 與 dangling symlink 都只改 link 自身、未憑空建立 target；並以 Swift 確認 `contentModificationDate` 對 symlink 取的是 link 自身（lstat 語意），因此 `-h` 確實是讓 task 1.14 具區辨性的必要條件。verifying reviewer：Reviewer V。
- **W3: resolved** — Contract 第 1 點與第 2 點皆指定 `FileManager.default.contentsOfDirectory(atPath:)`，第 2 點另明訂對每個項目新建 URL 即時讀取、`MUST NOT` 取自預取快取並說明 TOCTOU 窗口理由；tasks 2.2 同步。Reviewer V 以 grep 確認決策 6 全段已無「快取值」與 dangling symlink 的錯誤理由，殘留的 `dangling` 僅出現在決策 2 的型別實測與 Contract 第 5 點的 `touch` 實測依據，兩者皆為正確陳述。verifying reviewer：Reviewer V。
- **W4: resolved** — tasks 2.3 已改為「執行任務 1.2 至 1.17 的測試」。編號 1.1–1.17、2.1–2.3、3.1–3.3 全部連續無跳號，全檔無指向原 3.3／3.4 的殘留交叉引用。13 個 spec scenario 全部被 tasks 覆蓋，Contract 第 6 點的 10 項 fixture 覆蓋與 tasks 1.2–1.9、1.14 一一對應。verifying reviewer：Reviewer V。

四個 member 皆以 verified resolution 離開 cumulative blocking set，該集合現為空。

### 一併驗證通過的 Suggestion 修復

Reviewer V 覆核 Round 4 的四個 Suggestion 修復皆正確：S1（proposal 條件清單已含「是一般檔案」）、S2（Contract 第 7 點與 tasks 1.15／1.16；另實測 `0o111` 的四項行為全部成立，證實該注入確實需要區辨性斷言）、S3（Contract 第 7 點與 tasks 1.12／1.16／1.17 皆要求 `defer`／`addTeardownBlock`；design 只把 `uchg` 與 `0o111` 列為會擋下遞迴刪除，未把 ACL 列入，與實測一致）、S4（決策 6 統一為三項，全文已無「四個致命失敗」）。hardlink 的文件補述亦已落在決策 2 與 Risks。

### Suggestion

**F1**（Reviewer V，`confidence` 65，`disposition` fix-introduced，`introduced_by`: Round 4「**W1 — 修復**」）
- `location`: design.md Implementation Contract 第 7 點的覆蓋清單
- `summary`: W1 的修復新增了 task 1.17 與對應的 ACL 注入段落，但第 7 點的 seam 測試覆蓋清單仍只列 6 項，未列入「單一候選檔屬性讀取失敗」。task 1.17 反向引用 Contract 第 7 點，因此 tasks → Contract 不再是一一對應。

**F2**（Reviewer V，`confidence` 60，`disposition` fix-introduced，`introduced_by`: Round 4「**W1 — 修復**」）
- `location`: tasks.md 1.17；specs/download-reliability/spec.md requirement 本文
- `summary`: W1 的修復在 spec requirement 新增了「該次讀取失敗時，該項目 MUST NOT 被刪除」，但 task 1.17 的斷言沒有要求驗證那個 ACL 候選檔本身在清理後仍存在，該句 MUST NOT 因此沒有任何 task 直接驗證。

**F3**（Reviewer V，`confidence` 60，`disposition` fix-introduced，`introduced_by`: Round 4「**S2 — 修復**」）
- `location`: tasks.md 1.11
- `summary`: S2 的修復把「區辨性候選檔」寫成適用於「每個致命失敗測試」，但只同步到 tasks 1.15 與 1.16。task 1.11 恰好是 W1 修復後承擔「最終輸出檔不可用」整段處置的唯一測試，若其輸出目錄不含任何滿足其餘條件的候選檔，「不刪除任何檔案」會真空成立。

**F4**（Reviewer V，`confidence` 60，`disposition` new）
- `location`: tasks.md 1.5、1.6；design.md Implementation Contract 第 5 點
- `summary`: W2 為 task 1.14 建立的原則（干擾用項目 MUST 由 fixture 在 invocation 期間建立）同樣適用於 1.5 與 1.6，但這兩個 task 未寫明，Contract 第 5 點的 fixture case 描述也未提其他主幹的干擾檔。最自然的寫法是由測試在呼叫 `download` 之前建立——那樣兩個檔都會進入快照被條件 2 排除，決策 2 的前綴與形態比對（本變更「寧可漏刪也不可誤刪」的核心防護）完全不會被執行，測試仍全綠。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- 非 blocking triaged finding count: 4
- `critical_gap`: false
- `round_type`: micro

rationale：cumulative blocking set 的四個 member W1–W4 均取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開集合，集合現為空。本輪新增的四個 finding `confidence` 介於 60 至 65，經 confidence filter 後全部為 `Suggestion`，依規則不進入 cumulative blocking set、不造成 `next_round`。post-filter cumulative blocking set 不含任何 blocking Critical 或 blocking Warning，pass 條件成立，因此 `decision: passed`。

## Fix Actions

pass 條件在任何修復之前即已成立（cumulative blocking set 為空）。以下四項均為非 blocking 的 `Suggestion`，依規則可僅記為 triage note；但 F3 與 F4 指出的是「測試在條件序列的前段就被攔下、完全不會執行目標防護」的假綠燈，若留到 apply 階段會直接產出無效測試，因此一併修復。四項修復都只補述既有機制的使用方式，未新增或改變任何刪除條件。

**F1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md` Implementation Contract 第 7 點的覆蓋清單，補上「單一候選檔屬性讀取失敗時仍處理其餘候選檔並回傳原本的最終輸出路徑」，與既有的「刪除失敗」項並列。清單現為 7 項，與 seam tasks 1.10、1.11、1.12、1.13、1.15、1.16、1.17 一一對應。

**F2 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md` task 1.17，斷言補上「該候選檔在清理後仍存在」，使 spec requirement 的「該次讀取失敗時，該項目 MUST NOT 被刪除」有 task 直接驗證。

**F3 — 修復**。修改 tasks.md task 1.11，補上與 1.15、1.16 相同的區辨性候選檔要求與存在性斷言，並註明該候選檔須由 `attemptExecutor` 在執行期間建立（但不建立所回傳的 final path）；同時把 scenario 引用精確化為「判斷前提不成立時放棄整輪清理」的最終輸出檔不可用分支。

**F4 — 修復**。修改 design.md Implementation Contract 第 5 點，明訂「多 attempt 成功」case MUST 能依設定建立任意檔名的干擾檔（涵蓋其他主幹與含點主幹兩種形態），並把「MUST 由 fixture 在 invocation 期間建立」的要求從目錄與 symlink 泛化為所有干擾用項目，說明條件 2 會提前攔下預先建立的項目、使後續條件完全不被執行。修改 tasks.md task 1.5 與 1.6 同步該要求。

**驗證**：修復涉及 design 與 tasks 兩個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；並重跑 mechanical self-check，確認 task 編號 1.1–1.17／2.1–2.3／3.1–3.3 連續、13 個 spec scenario 全覆蓋、Contract 第 7 點 7 項與 7 個 seam task 一一對應、annotation 平衡。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

passed
