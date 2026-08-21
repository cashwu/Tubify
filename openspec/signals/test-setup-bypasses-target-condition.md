---
id: test-setup-bypasses-target-condition
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r4.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r5.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r1.md
---

# 測試 setup 使目標條件在更早的分支就被排除

當一組條件依序求值時，測試若把受測項目佈置成「在更早的條件就被攔下」，該測試永遠不會執行它宣稱要驗證的那個條件。斷言仍然成立、測試全綠，但它證明的是另一件事。撰寫「保留類」或「不執行類」測試時，SHALL 確認受測項目確實走到目標條件才被攔下，而不是在前置條件就出局；scenario 的 GIVEN 若已寫明前置條件（例如「不在快照中」），tasks 與 fixture 規格 MUST 提供達成該 GIVEN 的手段。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition fix-introduced）：新增的目錄／symlink 保留測試若由測試在呼叫 `download` 之前建立那些項目，它們會落入目錄快照而被「不在快照中」的條件提前排除，完全不會走到要驗證的型別檢查條件。fixture 規格未提供在 invocation 期間建立這些項目的手段。已擴充 fixture case 並明訂項目必須由 fixture 在 invocation 期間建立，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 5（Reviewer V，confidence 60，Suggestion，disposition new）：同一原則未套用到其他兩個「保留類」測試的干擾檔，使前綴比對與形態比對這兩項核心防護同樣不會被執行。已在 fixture 規格與對應 tasks 中泛化該要求。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 1（Reviewer A 與 Reviewer B 獨立提出，confidence 95，Warning）：實作階段的「保留」類測試以 `write(to:)` 建立預先存在的候選檔，其 mtime 為執行當下的真實時間，而 fixture 的最終輸出檔以 `touch -t` 設為多年前，於是實際攔下該檔的是 mtime 條件而非它宣稱驗收的快照條件。Reviewer B 以 mutation 實測確認：把快照 guard 換成恆真式後全部 85 個測試仍全綠，該條件在整個測試套件中沒有任何具鑑別力的覆蓋。已把預先存在檔案的 mtime 明確設早於最終輸出檔，並以 mutation 反向確認測試會轉紅，verdict 為 resolved。此為 propose 階段同一 change 反覆出現後，在 apply 階段以另一種形式再現。
