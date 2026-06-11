# Propose Plus Review — Round 1
## Reviewer Findings
### Critical

(none)

### Warning

- reviewer: A
  severity: Warning
  confidence: 100
  location: `design.md` `Implementation Contract` / `Failure modes` ↔ `specs/youtube-post-live-replay/spec.md` `ADDED Requirements` ↔ `tasks.md` sections 1-3
  summary: `formats 查詢失敗且錯誤符合 ended-live 暫態時 SHALL 顯示 .postLive；非 ended-live 錯誤 SHALL 使用 .failed` 是 design 的 SHALL，但 spec 與 tasks 沒有完整覆蓋這個 metadata/formats-query failure path。
  recommendation: 在 spec 新增 scenario 覆蓋 `post_live` 下 formats 查詢回傳 ended-live error 時進入 `postLive`，以及非 ended-live error 維持 `failed`；並在 tasks 增加對應測試/實作項目，或明確把這段從 Implementation Contract 降級/移出 scope。

### Suggestion

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `specs/youtube-post-live-replay/spec.md` + `Requirement: Downloadable post-live replay detection`
  summary: `usable media formats` 未定義，apply 階段可能對哪些 formats 算可下載產生不同實作判斷。
  recommendation: 在 spec 或 design 明確定義 `usable media format`，例如排除 thumbnails/storyboards，要求可被現有 media option/download queue 使用的 video/audio format，並說明是否接受 combined format、separate video/audio pair、DASH/HLS manifest。

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `proposal.md` + `Proposed Solution`; `design.md` + `Goals / Non-Goals` / `Decision: retry re-runs the normal metadata and download flow`
  summary: proposal 寫「安排重試」但 design/spec 聚焦手動重試且明確不新增自動輪詢，重試語意可能讓 apply 階段誤加自動 retry。
  recommendation: 將 proposal 的「將任務轉為直播處理中或安排重試」改成明確語意，例如「將任務轉為直播處理中並保留手動重試入口」，若需要自動 retry 則必須在 design/spec/tasks 補齊範圍與測試。

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `tasks.md` + `1. 測試先行與錯誤分類`; `design.md` + `Implementation Contract / Acceptance criteria`
  summary: design 要求測試覆蓋 `post_live formats 不可用時維持 .postLive`，但測試先行段落沒有對應的獨立 test task。
  recommendation: 在 section 1 增加一個測試任務，明確驗證 `live_status = post_live` 且沒有 usable formats 時任務保持 `.postLive`、不啟動 download process，並讓 2.3 依賴該測試通過。

## Rating

quality_score: 8.3
critical_gap: false

不通過。此輪沒有 Critical finding，因此 critical_gap 為 false；但 design 中有 SHALL 等級的 formats-query failure path 未被 spec/tasks 完整覆蓋，屬於實作契約與驗收範圍不一致的明確缺口。另外 `usable media formats` 定義不清、proposal 的 retry 語意可能誤導實作、tasks 缺少 post-live 無可用 formats 的獨立測試，會增加 apply 階段偏差風險。整體方向可行，但尚未達 quality_score > 9 的通過門檻。

## Fix Actions

- 修改 `proposal.md`：將「安排重試」收斂為「保留手動重試入口」，避免暗示自動 retry。
- 修改 `design.md`：定義 `usable media formats`，並明確 formats-query ended-live 與非 ended-live failure path。
- 修改 `specs/youtube-post-live-replay/spec.md`：新增 formats-query transient/permanent failure scenarios，並定義 usable media formats。
- 修改 `tasks.md`：新增 post_live 無可用 formats 與 formats-query error path 的測試與實作任務。

## Decision

next_round
