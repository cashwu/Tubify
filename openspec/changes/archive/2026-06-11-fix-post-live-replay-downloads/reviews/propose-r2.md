# Propose Plus Review — Round 2
## Reviewer Findings
### Critical

(none)

### Warning

- reviewer: A+B
  severity: Warning
  confidence: 100
  location: `specs/youtube-post-live-replay/spec.md` `Ended-live extractor errors are transient post-live states` + `tasks.md` section 1.2 / 2.2
  summary: spec 要求 ended-live 下載錯誤 SHALL NOT send a generic failed download notification，但 tasks 沒有要求測試覆蓋這個 SHALL / Example 欄位。
  recommendation: 擴充 `tasks.md` 1.2 或新增測試任務，明確驗證 `This live event has ended.` 轉為 `postLive` 時不會送出 generic failure notification；並讓 2.2 的完成驗證引用該測試。

- reviewer: A
  severity: Warning
  confidence: 100
  location: `specs/youtube-post-live-replay/spec.md` `Ended-live extractor errors are transient post-live states` + `tasks.md` section 1.2 / 2.2
  summary: spec 要求 ended-live 下載錯誤 SHALL preserve a user-readable message，但 tasks 沒有明確要求下載階段 ended-live 分類保留可讀訊息的實作或測試。
  recommendation: 更新 `tasks.md` 的 `1.2` 或新增子任務，驗證 `This live event has ended.` 轉為 `.postLive` 時會保留 replay processing / not yet available 的 user-readable message；並在 `2.2` 完成驗證中納入。

- reviewer: B
  severity: Warning
  confidence: 90
  location: `tasks.md` section 1.4-1.5
  summary: 1.4 與 1.5 都標記 `[P]` 且都指定 `TubifyTests/PostLiveReplayTests.swift`，apply 階段平行執行時可能產生同檔案衝突。
  recommendation: 移除其中一個或多個 `[P]`，或明確拆分到不同測試檔，讓平行任務不修改同一檔案。

- reviewer: B
  severity: Warning
  confidence: 85
  location: `proposal.md` `Non-Goals` + `design.md` `Goals / Non-Goals`
  summary: `proposal.md` 的「不實作長時間背景輪詢排程器以外的大型工作系統」語意不清，可能被解讀為 scheduler 本身仍在 scope，和 `design.md` 的「不新增長時間自動輪詢服務或背景 scheduler」不一致。
  recommendation: 將 `proposal.md` non-goal 改成明確排除「長時間自動輪詢服務、背景 scheduler、或大型工作系統」。

### Suggestion

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `specs/youtube-post-live-replay/spec.md` `Downloadable post-live replay detection`
  summary: `at least one usable media format` 對 separate video/audio pair 的判定不夠精確，apply 階段可能誤把單一 video-only 或 audio-only format 當成完整可下載選項。
  recommendation: 將 requirement 改為以既有 media option resolver 是否產生至少一個可下載選項為準，或明確定義 separate formats 必須形成可選的 audio/video pair。

## Rating

quality_score: 8.6
critical_gap: false

不通過。此輪沒有 Critical finding，因此 critical_gap 為 false；但仍有多個高信心 Warning，尤其是 tasks 未覆蓋 spec 中兩個 SHALL 行為：不送 generic failure notification、且保留 user-readable message。這會讓 apply 階段可能漏掉關鍵驗證。另外 1.4/1.5 平行任務同檔衝突與 non-goal 語意不一致也會增加執行風險。整體方向可行，但品質尚未達到 >9 的通過門檻。

## Fix Actions

- 修改 `tasks.md`：讓 1.2 與 2.2 明確驗證 ended-live transient state 不送 generic failed download notification，並保留 user-readable message。
- 修改 `tasks.md`：移除同時寫入 `TubifyTests/PostLiveReplayTests.swift` 的 `[P]` 標記，避免 apply 階段平行同檔衝突。
- 修改 `proposal.md`：將 non-goal 改為明確排除長時間自動輪詢服務、背景 scheduler、或大型工作系統。
- 修改 `specs/youtube-post-live-replay/spec.md` 與 `design.md`：將 usable media formats 收斂為可形成完整下載選項的 format，而不是單一孤立 video-only/audio-only entry。

## Decision

next_round
