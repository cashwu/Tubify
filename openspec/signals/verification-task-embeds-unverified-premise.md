---
id: verification-task-embeds-unverified-premise
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cookieless-subtitle-detection/reviews/propose-r3.md
---

# 檢查任務內嵌未經查證的範圍斷言，使該檢查失去鑑別力

檢查或 code review 類的 task 若在敘述中寫入「唯一會改變 X 的情形是 Y」「只有 Z 會受影響」這類範圍斷言，而該斷言未經查證，執行者會依它直接放行：既然「唯一」的情形已由別的 task 涵蓋，這條檢查就沒有事情要做。與 [[unverified-design-claim]] 的差別在於錯誤宣稱的落點——它寄生在驗證動作本身，因此不只是敘述錯誤，而是讓唯一承接某項迴歸的檢查失效。

撰寫檢查任務時 SHALL 避免未經窮舉的「唯一／只有」斷言；需要界定範圍時 SHALL 逐條列出可窮舉的情形並各自標明由誰驗證，或把檢查點改寫為可實際執行的斷言（給定輸入、預期輸出），而非要求執行者宣告一個結論。

## Occurrences

- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 3（Reviewer V，confidence 85，Warning，disposition fix-introduced）：round 2 為了修正另一個 finding 而新建的 code review task，括號內寫著「唯一會改變 `handlePostLiveFormatLookupError` 輸入的情形是兩次皆失敗時改以第二次 stderr 為準，已由 3.5 驗證」。方向恰好相反——變更前該路徑唯一的 metadata invocation 一律帶 cookies，變更後依 Contract 的非登入類失敗分支，輸入改以「不帶 cookies 的第一次」stderr 為準，那才是真正改變的主要情形；而「兩次皆失敗」時的第二次正是帶 cookies 那次，反而最接近變更前。該輸入直接決定任務落在 `.postLive` 還是 `.failed`，是這條唯一承接既有 spec 迴歸的檢查要保護的東西。照字面執行，reviewer 會依「唯一」推論已被涵蓋而放行。改為逐字列出兩種情形、並把檢查點換成可執行的 fixture 斷言（cookieless 訊息仍能被分類器判為 ended-live）後，round 4 的兩位 checkpoint reviewer 一致判定 resolved。
