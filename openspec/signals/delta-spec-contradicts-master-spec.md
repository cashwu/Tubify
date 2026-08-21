---
id: delta-spec-contradicts-master-spec
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r1.md
---

# Delta spec 的 scenario 前提與 master spec 既有 requirement 矛盾

新增 scenario 的 GIVEN 若把某個行為當成既定前提，而同一 capability 的 master spec 正好逐字禁止該行為，archive 後同一份 spec 內會並存互相矛盾的敘述。撰寫 delta spec 前 SHALL 檢查 GIVEN 依賴的每個前提在 master spec 中是否被否定；若程式碼已與 master spec 漂移，SHALL 明確選擇「把該 requirement 納入 MODIFIED 範圍」或「改寫 GIVEN 使其不依賴該前提」，不得沉默地建立在被否定的行為之上。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 100，Critical）：新 scenario 的 GIVEN 建立在「video-data 403 觸發 Safari cookies fallback」之上，但 master spec `### Requirement: 403 重試維持下載生命週期與 cookies contract` 逐字寫著「單純 target HTTP 403 MUST NOT 觸發 Safari cookies fallback」。該 requirement 已因 `a1dffc6` 的直接修正而與程式碼漂移。已把 GIVEN 改寫為不繫結 cookies 觸發條件的通用形式，master spec 未動，verdict 為 resolved。
