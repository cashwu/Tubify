# Propose Plus Review — Round 5
## Reviewer Findings
### Critical

(none)

### Warning

- reviewer: B
  severity: Warning
  confidence: 100
  location: `tasks.md` 1.1 / `specs/youtube-post-live-replay/spec.md` `Downloadable post-live replay detection` Example
  summary: `tasks.md` 未明確要求測試 `137+140` 這類 pairable separate video/audio formats 的正向案例。
  recommendation: 將 1.1 或 1.6 補成明確測試：`live_status = post_live` 且 raw formats 含 video-only `137` 與 audio-only `140`，existing flow 可形成 `137+140` 時，任務進入可下載流程。

- reviewer: B
  severity: Warning
  confidence: 100
  location: `tasks.md` 1.3 / `specs/youtube-post-live-replay/spec.md` `Manual retry rechecks post-live replay availability` Example
  summary: retry 測試只要求清除錯誤、重置 progress、重新排隊，未覆蓋「retry 後 metadata 已含可用 formats 時應正常下載」的 spec example。
  recommendation: 擴充 1.3：建立 `.postLive` 任務，retry 後 mock metadata 回傳可用 format（例如 `137+140`），並 assert 任務走 normal downloadable video flow，而不是重用舊的 post-live 結果。

### Suggestion

- reviewer: B
  severity: Suggestion
  confidence: 75
  location: `design.md` `Decision: ended-live yt-dlp errors are transient post-live errors`
  summary: `等價的 YouTube ended-live 訊息` 未列出 in-scope 字串或判斷規則，apply 階段可能把分類範圍做得過窄或過寬。
  recommendation: 明確寫出本 change 必須支援的最小 matcher，例如 exact substring `This live event has ended.`，並說明其他 variants 只需集中在同一 helper 中方便後續擴充。

## Rating

quality_score: 8.8
critical_gap: false

不通過。此輪沒有 Critical，因此 critical_gap 為 false；但兩個 confidence 100 的 Warning 都是明確測試覆蓋缺口，可能讓 apply 階段漏掉 `137+140` 可下載正向案例，以及 retry 後 metadata 已可下載時應走正常下載流程的行為。Suggestion 較小，但也指出 matcher 範圍仍需收斂。整體接近可通過，但未達 >9。

## Fix Actions

- 修改 `tasks.md`：讓 1.1 明確驗證 raw `137` video-only 加 `140` audio-only 可形成 `137+140` download option 並進入可下載流程。
- 修改 `tasks.md`：讓 1.3 明確驗證 `.postLive` 任務 retry 後 mock metadata 已含可用 formats 時會走 normal downloadable video flow，不重用舊結果。
- 修改 `design.md`：將本 change 必須支援的 ended-live matcher 收斂為 substring `This live event has ended.`，其他變體只要求集中在同一 helper 以便後續擴充。

## Decision

next_round
