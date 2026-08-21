# Cash Apply Review — Round 2

## Reviewer Findings

### Suggestion

- `severity`: Suggestion ／ `confidence`: 60 ／ `layer`: design ／ `disposition`: `new` ／ reviewer source: Reviewer V — Verification
  - `location`: `design.md:102`（`## Risks / Trade-offs` 最後一條）與 `design.md:81-91`（`## Implementation Contract` → 驗證責任歸屬）
  - `summary`: tasks 4.8 已承接「正式程式碼維持使用 `shared`」的把關責任，但 design 側是單向的：Risks 最後一條仍只寫「由 code review 把關」而未指名 4.8，驗證責任歸屬段落也未列入此項。design 其餘責任指派均明確指名任務編號，此條為唯一例外。
  - `recommendation`: 把該 Risks 條目末句改為指名承接任務，或在驗證責任歸屬段落補一行說明由 tasks 4.8 承接。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：0
- 非 blocking 的 triaged finding 數：1
- `critical_gap`: false
- `round_type`: micro

rationale：Reviewer V 對累積 blocking set 唯一成員 [M1] 給出 `resolved` 裁決，並以獨立查證為據——design Risks 第 2 條的敘述已與 `~/Library/Logs/Tubify/tubify-2026-08-21.log` 的實際事件序列逐項吻合，tasks 4.7 的三項判準經逐條重驗全數成立且具備可失敗性（同目錄其餘 `.srt` 殘留檔會被 mtime 判準排除，偽通過路徑已關閉）。M1 依「verified resolution」離開累積 blocking set。fix propagation 檢查全數通過：tasks 由 22 增為 23 條未造成任何 artifact 的過期數量宣稱或交互引用失效，4.8 附加於尾端未造成重編號。fix 未引入新缺陷：`resolvedPathCount` 恆真斷言在最終 diff 中零殘留，改傳非空 cookies 的測試經查證正確，獨立重跑 325 tests 全數通過。本輪唯一 finding 為 `disposition: new` 的 Suggestion，依規則非 blocking。post-filter 累積 blocking set 為空，故本輪通過。

## Fix Actions

- 修改 `openspec/changes/cookieless-subtitle-detection/design.md`：Risks 最後一條末句由「由 code review 把關」改為「由 tasks 4.8 的 code review 把關」，並在 `## Implementation Contract` 的驗證責任歸屬段落補一行，明示該 Risks 項由 tasks 4.8 承接並載明其查證內容。此為對 Reviewer V 非 blocking Suggestion 的主動修復（該 finding 依規則僅需 triage note，但修復成本為單行且可消除 design 內部的指派不對稱，故選擇修復）。
- 修改後的 fix propagation 檢查：全域 grep 確認 `tasks 4.8` 在 `design.md` 出現 2 處（驗證責任歸屬 line 90、Risks line 103），與 `tasks.md` 4.8 的實際文字一致；`proposal.md` 與 delta spec 無需同步（皆未提及個別 task 編號）。
- 修改僅涉及 artifact 文字，不觸及任何實作或測試檔案，無需重跑測試套件；Reviewer V 於本輪已獨立重跑 `xcodebuild test` 得 325 tests、0 failures。
- 累積 blocking set 移除記錄：成員 [M1]（Reviewer A round 1，Warning／confidence 85）以 verified resolution 離開累積 blocking set。對應 fix 為 round 1 Fix Actions 中的 design Risks 第 2 條改寫與 tasks 4.7 驗收點二改寫；驗證者為 Reviewer V — Verification（round 2）。
- 無 `未修復：裁判面保護` 記錄。本次 fix actions 未觸及任何受保護的 grader path。

## Decision

passed
