---
id: rewrite-rule-misses-syntax-separator
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/dubbed-audio-track-selection/reviews/propose-r1.md
---

# 字串改寫規則漏掉目標語法的某個分隔語意，使自己的全稱保證失效

Contract 若以「切分、逐段加工、重組」的方式改寫某個外部工具的表達式（format selector、query、filter 字串），並同時寫下「每一段都 MUST 帶上某某限制」這類全稱保證，則規則涵蓋的分隔字元必須窮盡該語法真正的分隔語意。漏掉一個分隔字元，未被切出的那一段就不會被加工，全稱保證會在該語法出現時直接失效——而失效的形態往往正是這個變更要消滅的那一種（例如靜默沿用預設值），因此不會有任何錯誤訊號。

撰寫此類規則時 SHALL 逐一列出目標語法的全部分隔語意並實測確認（例如以工具本身跑一次含該字元的輸入，觀察它是否被當成分隔），無法涵蓋的語法 SHALL 寫入 Risks 並說明其失敗形態是明確失敗還是靜默降級。

## Occurrences

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer B，confidence 55；主 agent 實測後依 rubric 提升至 100，Warning）：Implementation Contract 只以不在 `[]` 內的 `/` 與 `+` 切分 yt-dlp 的 format 字串，漏掉 `,`（多重下載語法）。`bv+ba,b` 會被視為單一 alternative，最後一個 `+` part 是 `ba,b`，加工後成為 `bv+ba,b[language=ja]`——`bv+ba` 這一路完全沒有語言限制，正好回到該變更要消滅的「靜默交付原聲」，且直接違反 Contract 自己的「MUST NOT 產生任何不含 `[language=<code>]` 的 alternative」。實測 `-f "ba[language=ja],b"` 輸出 `Downloading 2 format(s): 251-0, 18` 確認 `,` 為合法分隔。已把 `,` 納入切分層級、補 scenario 與測試，並把不涵蓋的括號分組語法寫入 Risks，round 2 的 Reviewer V 判定 resolved。
