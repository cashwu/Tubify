---
id: unassigned-verification-responsibility
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r6.md
---

# design 指派了驗證責任，tasks 沒有承接

當 `design.md` 寫下「某某由 code review 驗證」「某某由測試涵蓋」這類句子時，它就指派了一項驗證責任。若 `tasks.md` 沒有對應的 task 承接，該責任會憑空消失——artifacts 讀起來像是已經涵蓋，實際上沒有任何人會執行它。這比完全沒提還危險，因為 design 的敘述會讓後續 review 誤以為該面向已有歸屬。

design 每寫下一句指派驗證責任的敘述，SHALL 同時在 tasks 建立承接它的 task，或改為明確指向既有 task。review 時 SHALL 反向檢查：design 提到的每一項驗證責任，都能在 tasks 找到承接者。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition unresolved-prior）：design 為新增的 observer 機制寫下「日誌內容本身仍由 code review 驗證」，但 tasks 的 Verification 只有一條涵蓋成功刪除的 info 日誌，四個致命放棄路徑與兩條非致命失敗路徑的 warning 日誌既沒有測試也沒有 code review task。這使外部 review 指出的「失敗 warning 沒有驗收」只被修復了一半。已新增對應的 code review task 並把 design 該句改為明確指向它，verdict 為 resolved。
