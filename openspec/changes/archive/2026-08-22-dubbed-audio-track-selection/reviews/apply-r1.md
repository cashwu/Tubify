# Cash Apply Review — Round 1

## Reviewer Findings

### Critical

無。

### Warning

1. **5.9 的手動驗收缺少語言替換的稽核紀錄**
   - `severity`: Warning
   - `confidence`: 90
   - `layer`: design
   - `location`: `openspec/changes/dubbed-audio-track-selection/tasks.md` task 5.9（驗收點一、驗收點二）對照 `openspec/changes/dubbed-audio-track-selection/implementation-notes.md`
   - `summary`: task 5.9 驗收點二要求「選定日文音軌」、驗收點一要求確認清單「至少含英文與日文」，但唯一一次實際執行（TaskID `A2F01543-2A5A-4618-B3AC-317BFC98159A`）選定的是 `zh-Hant`；驗收點三的 oracle 替換有記 deviation，此語言替換卻無，形成不對稱且不可稽核的紀錄。
   - `recommendation`: 補一筆 `deviation` 條目說明以 `zh-Hant` 執行、為何與 contract 等價，並記下可稽核的音軌語言集合 oracle，使驗收點一與 delta spec `##### Example: 多配音影片出現音軌區塊` 有對應證據；或改以 `ja` 重跑一次並記錄。
   - 來源：Reviewer A — Adherence

### Suggestion

2. **`injectAudioLanguage` 的 doc comment 仍描述已移除的 fallback**
   - `severity`: Suggestion（原始 `confidence`: 100，`layer`: text）
   - `location`: `Tubify/Services/YTDLPService.swift:1160-1161`
   - `summary`: doc comment 寫著 `-f bv+ba` → `bv+ba[language=ja]/bv+ba`，與 Implementation Contract C4「MUST NOT 產生任何不含 `[language=<code>]` 的 alternative」及實測輸出矛盾；隔壁 `injectLanguageIntoFormat` 的註解已更新，兩者互相矛盾。
   - `recommendation`: 更新為 `-f bv+ba` → `-f bv+ba[language=ja]`，並補述 C5 的行為。
   - 來源：Reviewer A — Adherence

3. **等號形式的 `--format=` 不被六個樣式辨識，使用者選擇器遭靜默丟棄**
   - `severity`: Suggestion（`confidence`: 55 → 落在 [50, 80) 而降級）
   - `layer`: design
   - `location`: `Tubify/Services/YTDLPService.swift:1172-1207`
   - `summary`: 範本寫成 `--format=bv*[height<=720]+ba[ext=m4a]` 時六個 regex 皆不匹配，C5 的補上分支被觸發，argv 同時帶有使用者的 `--format=...` 與尾端新增的 `-f`；yt-dlp 以最後一個為準，使用者的限制被無訊息丟棄。
   - `recommendation`: 屬 Implementation Contract C5 的既定行為（「既有六個樣式皆未匹配時」），修改需先改 design；記為 triage note 並寫入 signals。
   - `introduced_by`: `Tubify/Services/YTDLPService.swift:1205-1207`
   - 來源：Reviewer B — Quality

4. **空白 segment 產生裸 `[language=xx]` alternative**
   - `severity`: Suggestion（`confidence`: 60 → 落在 [50, 80) 而降級）
   - `layer`: design
   - `location`: `Tubify/Services/YTDLPService.swift:1215-1232`
   - `summary`: 範本尾端多一個 `/` 或 `,` 時（例如 `bv*+ba/b/`）會產生 `.../[language=ja]`，yt-dlp 視為語法錯誤而使整個下載失敗。
   - `recommendation`: 失敗形態為明確失敗而非靜默降級，與本變更的取捨方向一致；記為 triage note。若要處理，於 design 補規則後再實作，不在本次 diff 內加防禦。
   - `introduced_by`: `Tubify/Services/YTDLPService.swift:1218-1230`
   - 來源：Reviewer B — Quality

5. **fixture invocation 計數為非原子的 read-modify-write**
   - `severity`: Suggestion（`confidence`: 50 → 落在 [50, 80) 而降級）
   - `layer`: design
   - `location`: `TubifyTests/YTDLPServiceTests.swift:2010-2019`
   - `summary`: 兩個重疊的 invocation 會同時寫入 `invocation-1.args`，使 `invocationCount` 少計、`arguments(at:)` 回傳錯誤內容而非 nil。Reviewer B 已逐一確認既有重疊行程測試皆以 marker 檔序列化，目前無實際競態。
   - `recommendation`: 僅影響測試基礎設施，無生產影響；記為 triage note。
   - `introduced_by`: `TubifyTests/YTDLPServiceTests.swift:2011-2019`
   - 來源：Reviewer B — Quality

## Rating

- post-filter cumulative blocking set Critical 數：0
- post-filter cumulative blocking set Warning 數：1
- 非阻塞 triaged finding 數：4
- `critical_gap`: false
- `round_type`: full
- 理由：本輪為未 seeded 的第一輪，所有存活的 Critical 與 Warning 皆為阻塞。Reviewer A 的 5.9 稽核缺口以 `confidence` 90 通過 confidence filter 並維持 Warning，因此 cumulative blocking set 含 1 筆 Warning，不符合 pass 條件。Reviewer B 未提出任何 Critical 或 Warning，其四筆 Suggestion 中一筆因 `confidence` 45 低於 50 而捨棄，其餘三筆維持 Suggestion 且不阻塞。Reviewer A 於本輪另完成 run-first-round claim verification，design 的 11 項 code-facing 宣稱全部成立，未產生額外 finding。

## Fix Actions

- **修復 Warning 1（阻塞）**：於 `openspec/changes/dubbed-audio-track-selection/implementation-notes.md` 新增 `deviation` 條目「2026-08-21 23:20 — 5.9 驗收點二以 zh-Hant 取代 ja 執行」。內容記錄該次執行的實際 `-f` 值與 `--extractor-args`、`ja` 與 `zh-Hant` 在 C3／C4／C5 上為同一條路徑同一種輸入的等價性論證，並以可稽核的解析層 oracle 承接驗收點一：對 `Af6i6ChAVTw` 以本變更的引數集合實際查詢 yt-dlp 2026.07.04 取得 22 種純音訊語言，套用 `LanguageFilter.isSupportedLanguage`（`Tubify/Models/SubtitleInfo.swift:6`）過濾後為 `["en", "ja", "zh-Hans", "zh-Hant"]`，數量 4 滿足 `filteredAudioTracks.count > 1` 且同時含 `en` 與 `ja`，對應 delta spec 的 `##### Example: 多配音影片出現音軌區塊`。條目並明示未直接觀察 UI 清單的逐項渲染結果。修改檔案：`openspec/changes/dubbed-audio-track-selection/implementation-notes.md`。
- **修復 Suggestion 2**：更新 `Tubify/Services/YTDLPService.swift:1160-1162` 的 doc comment 為 `-f bv+ba` → `-f bv+ba[language=ja]`，並補一行說明 C5 的補上行為。該註解因本變更而失準，屬本次範圍。修改檔案：`Tubify/Services/YTDLPService.swift`。
- **fix propagation**：以 `grep` 檢查 `fallback` 與 `language=ja]/bv` 在程式碼與全部 artifacts 的出現位置。`YTDLPService.swift:254`、`:255`、`:298` 的 `fallback` 指 cookies fallback，屬不同概念，正確不動；`design.md:48`、`tasks.md:28`、`specs/audio-track-selection/spec.md:69` 的命中皆為描述新行為或刻意記載被移除的舊行為，無殘留需同步。
- **triage note（非阻塞，Suggestion 3）**：等號形式 `--format=` 未被 C5 的六個樣式涵蓋。屬 Implementation Contract 既定行為，修改需先改 design，本輪不實作，寫入 signals。
- **triage note（非阻塞，Suggestion 4）**：空白 segment 產生裸 `[language=xx]`。失敗形態為明確失敗，與本變更取捨方向一致，本輪不實作，寫入 signals。
- **triage note（非阻塞，Suggestion 5）**：fixture invocation 計數非原子。僅測試基礎設施且目前無實際競態，本輪不實作，寫入 signals。
- **downgrade trace**：Reviewer B 的「只改寫第一個 `-f`／`--format`，yt-dlp 以最後一個為準」finding（`location`: `Tubify/Services/YTDLPService.swift:1172-1200`，`introduced_by`: `:1200`）`confidence` 為 45，低於 50，依 confidence filter 捨棄，不進入 cumulative blocking set，亦不寫入 signals。
- **post-fix mechanical self-check**：註解／annotation 配對通過；重跑 `TubifyTests/YTDLPServiceTests` 與 `TubifyTests/YouTubeMetadataServiceTests` 共 141 tests，0 failures。
- **change 目錄外的修改**：`Tubify/Services/YTDLPService.swift`（已於下方 touched record 步驟記錄）。

## Decision

next_round
