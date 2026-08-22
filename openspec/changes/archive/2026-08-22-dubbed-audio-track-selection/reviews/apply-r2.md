# Cash Apply Review — Round 2

## Reviewer Findings

### Critical

無。

### Warning

無。

### Suggestion

1. **round 1 的三筆 triage note 尚未寫入 signals**
   - `severity`: Suggestion
   - `confidence`: 60
   - `layer`: text
   - `location`: `openspec/signals/`（對照 `openspec/changes/dubbed-audio-track-selection/reviews/apply-r1.md` 的 `## Fix Actions`）
   - `summary`: apply-r1 的 Fix Actions 對三筆非阻塞 Suggestion 註明「寫入 signals」，但 `openspec/signals/` 目前無任何一筆 Occurrences 引用 `apply-r1.md`。
   - `recommendation`: 若 signal 寫入是刻意延後到 loop 結束的 finalization 步驟，維持現狀即可；否則於收斂前補上。此項不阻塞。
   - `disposition`: `new`
   - 來源：Reviewer V — Verification

## Rating

- post-filter cumulative blocking set Critical 數：0
- post-filter cumulative blocking set Warning 數：0
- 非阻塞 triaged finding 數：1
- `critical_gap`: false
- `round_type`: micro
- 理由：cumulative blocking set 唯一成員 M1（round 1 的 5.9 稽核缺口 Warning）經 Reviewer V 判定為 `resolved`，屬 verified resolution，依規定移出 cumulative blocking set。Reviewer V 並非僅接受修復宣稱，而是獨立重跑 yt-dlp 取得同一組 metadata、複驗過濾後語言集合為 `["en", "ja", "zh-Hans", "zh-Hant"]`、比對 app log 中該 TaskID 的兩次 invocation、並逐行追查 doc comment 對應的實際行為與傳播範圍，全部相符。本輪唯一存活的 finding 為 `disposition: new` 的 Suggestion，依規定為非阻塞。post-filter cumulative blocking set 為空，符合 pass 條件。

## Fix Actions

- **verified-resolution 移除紀錄**：成員 M1（Warning，`confidence` 90，`location`: `tasks.md` task 5.9 對照 `implementation-notes.md`）經 round 1 的 fix（新增 `deviation` 條目「2026-08-21 23:20 — 5.9 驗收點二以 zh-Hant 取代 ja 執行」）修復，由 Reviewer V — Verification 於本輪判定 `resolved` 並移出 cumulative blocking set。
- **triage note（非阻塞，本輪 Suggestion 1）**：signals 未寫入一事屬刻意時序。依 Signals write step 的規定，該步驟僅在 review loop 結束（最終 round file 的 `decision` 為 `passed` 或 `aborted`）且機械決策已記錄之後才執行，因此在 round 1 結束時 `openspec/signals/` 尚無 apply-round 的落點是正確狀態，非缺漏。本 round file 的 `decision` 記錄完成後即執行該步驟。
- **apply-r1 措辭更正**：round 1 的 Fix Actions 對三筆非阻塞 Suggestion（等號形式 `--format=`、空白 segment 產生裸 `[language=xx]`、fixture invocation 計數非原子）寫「寫入 signals」，該措辭與 Signals write step 的規定不符——該步驟的 target set 明定「Findings classified `Suggestion`，以及任何 `confidence < 80` 的 finding，MUST NOT produce a signal」，三筆經 confidence filter 後皆為 Suggestion（`confidence` 55／60／50），因此不產生 signal。round files 在 loop 進行中為不可變的 gate input，故不回改 apply-r1，於本輪記錄此更正。三筆的處置仍為 round 1 已記錄的 triage note，內容不變。
- **本輪無程式碼或 artifact 修改**：round 2 未產生任何 fix，未修改 change 目錄外的檔案。

## Decision

passed
