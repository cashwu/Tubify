# Propose Plus Review — Round 4
## Reviewer Findings
### Critical

(none)

### Warning

- reviewer: A
  severity: Warning
  confidence: 100
  location: `specs/youtube-post-live-replay/spec.md` `Requirement: Downloadable post-live replay detection`; `tasks.md` 1.1, 1.4, 2.1
  summary: `usable media formats` 的 MUST 排除條件沒有明確 task/test 覆蓋。
  recommendation: 在 `tasks.md` 增加明確測試任務，驗證 unpaired video-only、unpaired audio-only、thumbnails、storyboards、metadata-only entries、以及沒有 audio/video codec 的 entries 都 MUST NOT count as usable media formats，並讓實作任務指向同一個判斷 helper 或 predicate。

- reviewer: A
  severity: Warning
  confidence: 85
  location: `design.md` `Decision: post_live metadata must check downloadable formats before blocking`; `specs/youtube-post-live-replay/spec.md` `Requirement: Downloadable post-live replay detection`
  summary: design 要求 post_live 時透過 follow-up media options/formats 查詢確認可下載性，但 spec 只有 follow-up lookup 的錯誤情境，缺少 follow-up lookup 成功回傳 usable formats 的 positive acceptance scenario。
  recommendation: 在 spec 增加 scenario：`live_status = post_live` 且 follow-up format lookup returns usable media formats 時，系統 SHALL continue normal media option and download queue flow；並在 `tasks.md` 加上對應測試或擴充 `1.1` 明確涵蓋這條路徑。

### Suggestion

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `specs/youtube-post-live-replay/spec.md` + `Example: post_live replay manifest is available`
  summary: `metadata includes format 137+140` 容易被 apply 階段誤解成 yt-dlp JSON 內必須存在單一 `format_id = "137+140"`。
  recommendation: 將 example 改成明確描述 raw metadata 內有可配對的 separate formats，例如 `format_id = "137"` video-only 與 `format_id = "140"` audio-only，且 existing flow 可組成 `137+140` download option。

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `design.md` + `Decision: post_live metadata must check downloadable formats before blocking`
  summary: `usable media formats` 對 DASH/HLS 的判定仍有規格模糊，可能讓 implementation 把 manifest-only 或 codec 不完整的 DASH/HLS entry 當成可下載。
  recommendation: 補一條判定優先序：DASH/HLS entry 仍必須能被現有 option builder 產生完整 audio/video download option；若只是 manifest/storyboard/metadata entry 或缺少可用 codec/stream pairing，必須視為 not usable。

- reviewer: B
  severity: Suggestion
  confidence: 60
  location: `tasks.md` + `3.2 檢查 DownloadItemView`
  summary: UI task 只要求手動檢查或既有測試，但 spec/design 對 `.postLive` 必須保留 retry 入口與 user-readable message，apply 階段可能缺少可驗證的 UI regression guard。
  recommendation: 將 3.2 的完成驗證收斂成至少一個明確檢查項：確認 `.postLive` row 顯示 replay processing/not yet available 類訊息，且 retry control 可用；若現有 UI test 不適合，要求在 implementation notes 或 task completion 中記錄手動驗證步驟與結果。

## Rating

quality_score: 8.4
critical_gap: false

不通過。此輪沒有 Critical，critical_gap 必須為 false；但仍有兩個高信心 Warning，分別指出 MUST 排除條件缺少明確 task/test 覆蓋，以及 post_live follow-up lookup 成功時缺少 positive acceptance scenario。這些會影響 apply 階段可驗證性與規格完整度，因此品質分數不應高於 9。

## Fix Actions

- 修改 `specs/youtube-post-live-replay/spec.md`：新增 follow-up format lookup 成功回傳 usable media formats 的 positive scenario。
- 修改 `specs/youtube-post-live-replay/spec.md`：將 `137+140` example 改成 raw `137`/`140` 可配對格式，避免誤解成單一 JSON format。
- 修改 `design.md`：明確說明 DASH/HLS 仍必須能由現有 option builder 形成完整下載選項。
- 修改 `tasks.md`：新增 usable media predicate 負例測試任務，覆蓋 MUST NOT count 排除條件。
- 修改 `tasks.md`：讓 UI 驗證明確檢查 replay processing/not yet available 訊息與 retry control。

## Decision

next_round
