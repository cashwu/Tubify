# Cash Apply Review — Round 1

## Reviewer Findings

### Warning

- `severity`: Warning ／ `confidence`: 85 ／ `layer`: design ／ reviewer source: Reviewer A — Adherence
  - `location`: `design.md` → `## Risks / Trade-offs` 第 2 條；`tasks.md` 4.7
  - `summary`: design 宣稱把手動驗證驗收點改為「實際產生對應語言的字幕檔」可「使這個失敗模式在驗證時可被看見」，但實際驗證回合證明該驗收點無鑑別力——失敗模式確實發生（帶 cookies 的重試取不到 zh 字幕並發出 `missing subtitles languages` 警告），驗收點仍然通過。
  - `recommendation`: 修正 design Risks 該條的宣稱，並把 tasks 4.7 的驗收點二改寫為可排除殘留檔、且限定在本變更可控範圍的逐項判準。

### Suggestion

- `severity`: Suggestion ／ `confidence`: 70 ／ `layer`: design ／ reviewer source: Reviewer A — Adherence
  - `location`: `design.md` → `## Risks / Trade-offs` 最後一條 vs `tasks.md` 第 4 節
  - `summary`: design 把「正式程式碼維持使用 `shared`」的把關責任指派給 code review，tasks 第 4 節無任務承接（`unassigned-verification-responsibility` 形狀）。實作本身正確，缺的是任務層承接。
  - `recommendation`: 在 tasks 第 4 節補一條檢查任務承接該責任。
  - 註：原提報為 Warning／confidence 70，經 confidence filter 降級為 Suggestion。

- `severity`: Suggestion ／ `confidence`: 55 ／ `layer`: design ／ reviewer source: Reviewer A — Adherence
  - `location`: `TubifyTests/YouTubeMetadataServiceTests.swift` → `testFetchMediaOptionsThrowsWhenInjectedPathIsMissing`
  - `summary`: delta spec `#### Scenario: 與 exit code 無關的失敗不觸發重試` 的 GIVEN 是「呼叫端提供了非空的 cookies 參數」，但該測試傳入空陣列，無法與「因為沒有 cookies 所以不重試」區分。
  - `recommendation`: 改為傳入非空 cookies 參數。

- `severity`: Suggestion ／ `confidence`: 70 ／ `layer`: design ／ reviewer source: Reviewer B — Quality
  - `location`: `Tubify/Services/YouTubeMetadataService.swift` → `runMediaOptionsInvocation` 的 pipe 排空段
  - `summary`: stdout／stderr 以序列方式排空且無 timeout，stderr 寫滿 pipe buffer 時理論上可能卡住。屬既有程式碼、本次未修改該段行，但兩階段策略使每次查詢的曝險從 1 次 invocation 增為最多 2 次。
  - `recommendation`: 不屬本次 scope；日後可沿用 `YTDLPService` 既有的 `pipeDrainTimeout` 並行排空做法。

- `severity`: Suggestion ／ `confidence`: 55 ／ `layer`: design ／ reviewer source: Reviewer B — Quality
  - `location`: `Tubify/Services/YouTubeMetadataService.swift` → 等待 process 結束的 continuation
  - `summary`: `resumed` 旗標由 terminationHandler 執行緒與呼叫端執行緒同時讀寫且無同步，理論上可能對同一個 `CheckedContinuation` resume 兩次。屬既有程式碼、行未被修改。
  - `recommendation`: 不屬本次 scope。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：1
- 非 blocking 的 triaged finding 數：4
- `critical_gap`: false
- `round_type`: full

rationale：本輪為 unseeded run 的第一輪，全部存活的 Critical 與 Warning 均為 blocking。Reviewer A 提出 1 個 confidence 85 的 Warning，指出手動驗證驗收點與 design 宣稱之間的鑑別力落差，證據來自實際驗證回合的日誌，屬直接可查證的宣稱不成立，因此保留為 blocking Warning。Reviewer B 無 Critical 亦無 Warning，其 3 個 Suggestion 中有 2 個明確標示為既有程式碼、不屬本次 scope。累積 blocking set 尚存 1 個 blocking Warning，故本輪不通過。

## Fix Actions

- 修改 `openspec/changes/cookieless-subtitle-detection/design.md`：改寫 `## Risks / Trade-offs` 第 2 條，移除「使這個失敗模式在驗證時可被看見」的不成立宣稱，改為明確說明該驗收點無法觀察此失敗模式（yt-dlp 先寫字幕、後抓 video data，cookieless 第一次嘗試會在 403 前就把字幕寫到磁碟），並指出其可觀察訊號是日誌中的 `missing subtitles languages` 警告。對應 Reviewer A 的 blocking Warning。
- 修改 `openspec/changes/cookieless-subtitle-detection/tasks.md`：改寫 4.7 驗收點二為三項可逐條對照日誌的判準（(a) 第一次執行命令不含 cookies 且含 `--write-sub` 與語言碼、(b) 該次 invocation 進度輸出顯示字幕下載完成、(c) 字幕檔 mtime 落在該次 invocation 期間以排除殘留檔），並要求一併註明 fallback 警告是否出現但不以其為判準。對應同一個 blocking Warning。
- 依新判準重新驗證 4.7，三項全數通過：(a) 該 TaskID 第一次 `執行命令` 不含 `--cookies` 且含 `--write-sub --sub-lang zh`；(b) 進度輸出 `100% of 20.08KiB`；(c) `.zh.srt` mtime 15:26:41，落在該次 invocation（15:26:39–15:26:41.5）期間。註記：該任務出現 1 次 `missing subtitles languages` 警告，屬 Non-Goals 範圍外的下載端 fallback 失敗模式。
- 新增 `tasks.md` 4.8 並執行：對照 diff 確認 `Tubify/` 內未新增 `YouTubeMetadataService(` 直接建構。查證結果為 `Tubify/` 內唯一建構點是 `Tubify/Services/YouTubeMetadataService.swift` 的 `static let shared`，`init(ytdlpPathProvider:)` 的 13 處使用全數位於 `TubifyTests/YouTubeMetadataServiceTests.swift`。對應 Reviewer A 第 2 個 finding（已降級為 Suggestion，仍選擇修復）。
- 修改 `TubifyTests/YouTubeMetadataServiceTests.swift`：`testFetchMediaOptionsThrowsWhenInjectedPathIsMissing` 改為傳入非空 cookies 參數，使測試 setup 對齊 delta spec 該 scenario 的 GIVEN。對應 Reviewer A 第 3 個 finding（Suggestion，仍選擇修復）。
- 自我修正記錄：上述測試修改過程中一度加入 `resolvedPathCount == 1` 斷言，經檢視發現路徑解析在重試與否兩種情形下都只發生一次，該斷言無鑑別力（`tautological-acceptance-assertion` 形狀），已於同一輪內移除，未留存於最終 diff。
- Triage note（非 blocking，`new`）：Reviewer B 的 `runMediaOptionsInvocation` pipe 序列排空無 timeout 風險。屬既有程式碼行，本次未修改；兩階段策略僅使曝險倍增。不在本次修復，改以 signal 記錄。
- Triage note（非 blocking，`new`）：Reviewer B 的 process 結束 continuation `resumed` 旗標無同步保護。屬既有程式碼行，本次未修改。修復需引入 `design.md` 未定義的同步原語，依 Fix-loop design circuit breaker 不在本輪實作；改以 signal 記錄。
- Confidence filter 降級軌跡：Reviewer B 第 3 個 finding（測試 cookies 參數形狀與 `getCookiesArguments()` 不一致，`severity`: Suggestion／`confidence`: 45／`layer`: text）因 confidence < 50 被丟棄。實作把 `cookiesArguments` 當不透明陣列串接，該落差不影響任何斷言有效性。
- 修復後重跑 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`：325 tests、0 failures、**TEST SUCCEEDED**。
- 修復後重跑 pre-round mechanical self-check：註解配對正常、數量宣稱一致（tasks 由 22 增為 23 條）、識別字一致、delta spec 僅 ADDED 且無 master spec 標題衝突。

## Decision

next_round
