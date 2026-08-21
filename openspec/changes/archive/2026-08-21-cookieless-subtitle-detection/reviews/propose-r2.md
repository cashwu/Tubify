# Cash Propose Review — Round 2

## Reviewer Findings

### Critical

（無）

### Warning

**F1**（Reviewer V）
- `severity`: Warning
- `confidence`: 80
- `layer`: design
- `location`: `tasks.md` 1.3；`design.md` `## Implementation Contract` 驗證責任歸屬
- `summary`: delta spec 第二條 requirement 的主詞是「媒體選項查詢」，但唯一宣稱承接它的 1.3 只執行 `TubifyTests/YTDLPServiceTests.swift` 既有的 `shouldRetryWithCookies` 測試，全程不觸及 `fetchMediaOptions`；requirement 的「MUST NOT 另行維護第二份訊號清單」沒有任何動作可觀察——在 `fetchMediaOptions` 內複製一份清單同樣會讓 3.4／3.6 全數通過。
- `recommendation`: 新增逐字檢查「無第二份訊號清單」的 code review 任務承接，並修正 design 中 Contract 第 3 點的歸屬與 tasks 自行標註的對應不一致。
- `disposition`: `unresolved-prior`

**F2**（Reviewer V）
- `severity`: Warning
- `confidence`: 90
- `layer`: design
- `location`: `design.md` Implementation Contract 第 7 點；`tasks.md` 3.8
- `summary`: Contract 第 7 點宣稱「stderr 無法以 UTF-8 解碼或為空時，分類輸入 MUST 為既有的 `未知錯誤` fallback 字串」，但既有程式碼是 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"`，空 `Data` 會解碼成空字串而非 `nil`，fallback 不會生效；照現況執行，3.8 會是一條對照既有實作必然失敗、卻被標為驗證既有行為的測試。
- `recommendation`: 把事實敘述修正為「無法解碼時為 `未知錯誤`、為空時為空字串」，兩者分類結果同為非登入錯誤，並同步修正 3.8 的斷言。
- `disposition`: `fix-introduced`
- `introduced_by`: Round 1 Fix Actions 第 1 項「修 S9：Contract 新增第 7 點」與第 4 項「修 S9：新增 3.8」

### Suggestion

- **F3**（`confidence` 65，由 Warning 降級，`disposition`: `fix-introduced`，`introduced_by`: Round 1 Fix Actions 第 4 項「修 S6：新增 4.3」）4.3 要求確認 `handlePostLiveFormatLookupError` 收到的錯誤分類不變，但該函式是 `DownloadManager` 的 private func，既有唯一接縫 `YouTubeMetadataServiceProtocol` mock 會取代整個 service、繞過兩階段邏輯，照字面執行會得到一條繞過目標條件的測試。
- **F4**（`confidence` 50，`disposition`: `fix-introduced`，`introduced_by`: Round 1 Fix Actions 第 4 項）4.3 若以測試形式落在 `DownloadManager` 層，唯一可能的檔案 `TubifyTests/DownloadManagerTests.swift` 不在 proposal Impact 的 Modified 清單中。

## Rating

- post-filter 累積 blocking set Critical 數：0
- post-filter 累積 blocking set Warning 數：2（F1，即 W2 的延續；F2）
- 非 blocking 的 triaged finding 數：2（F3、F4）
- `critical_gap`: false
- `round_type`: micro
- rationale：Reviewer V 對前一輪三個 blocking 成員的判定為 W1 resolved、W3 resolved、W2 unresolved。W1、W3 依「verified resolution」離開累積 blocking set：W1 的修正經對照 `Tubify/Services/YTDLPService.swift` 的實際 gate 組成確認相符，W3 的新驗收方式在實作忽略 provider 時必定失敗、具鑑別力，且 provider 範圍與程式碼實際 5 處解析點逐行核對一致。W2 未解決——反例那一半已修好，但「有 task 承接」只達成字面，因此以 F1 續留 blocking set。F2 為本輪新增的 blocking 成員，屬 Round 1 修正引入的事實錯誤，已由主 agent 對照 `Tubify/Services/YouTubeMetadataService.swift` 的既有訊息建構方式獨立確認成立（`?? "未知錯誤"` 僅在解碼回傳 `nil` 時套用，空 `Data` 解碼為空字串）。仍有 2 個 blocking Warning，本輪不通過。

## Fix Actions

修正的檔案與理由：

1. `openspec/changes/cookieless-subtitle-detection/design.md`
   - 修 F2：Contract 第 7 點改寫為「stderr 無法以 UTF-8 解碼時分類輸入 MUST 為 `"未知錯誤"`；stderr 為空時 MUST 為空字串」，並逐字說明既有 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"` 只在解碼失敗回傳 `nil` 時套用 fallback，同時明寫本變更 MUST NOT 改變此既有訊息建構方式。
   - 修 F1：驗證責任歸屬拆開重寫——Contract 第 3 點改由 tasks 3.4／3.6 的行為測試承接（登入訊號會重試、非登入訊號不會，共同證明分類依該入口運作）；Contract 第 8 點維持由 `indicatesLoginRequired(message:)` 單元測試承接；delta spec requirement 中「MUST NOT 另行維護第二份訊號清單」明寫無法由行為測試觀察，改由第 4 節 code review 任務承接。
   - 修 F3：`post_live` 迴歸的責任歸屬拆成兩部分，明寫 `handlePostLiveFormatLookupError` 是 private func、既有 mock 會繞過兩階段邏輯，因此不以該層測試為據，改為 code review。
   - 修 F2 對應的驗證責任：第 7 點的驗證改述為「exit code 非 0 且 stderr 為空時不重試且分類輸入為空字串」。

2. `openspec/changes/cookieless-subtitle-detection/tasks.md`
   - 修 F2：3.8 的斷言改為「拋出的 `MetadataError.fetchFailed` 訊息為空字串」，並註明 fallback 不生效的原因與本變更不改此行為。
   - 修 F3、F4：4.3 重寫為 provider 接縫搭配 `post_live` fixture JSON 的行為測試，並逐字把測試落點限定在 `TubifyTests/YouTubeMetadataServiceTests.swift`、明寫不新增 `TubifyTests/DownloadManagerTests.swift` 的案例，使 proposal Impact 維持四個檔案即為正確；原 4.3 中屬於 `DownloadManager` 層的部分改為新的 4.4 code review 任務。
   - 修 F1：新增 4.5 code review 任務，逐字檢查 `Tubify/Services/YouTubeMetadataService.swift` 內沒有第二份登入訊號字串清單、且需登入判定一律經由 `YTDLPService.indicatesLoginRequired(message:)`。
   - 原 4.4、4.5 順延為 4.6、4.7。

3. `openspec/changes/cookieless-subtitle-detection/specs/subtitle-selection/spec.md`
   - 依 F5 的建議把「同一則訊息交給同一入口」scenario 的第二條 AND 由恆真敘述改為實質約束：媒體選項查詢 MUST NOT 另行套用 video-data 403 訊號，也 MUST NOT 使用該入口以外的訊號清單。

降級與丟棄追溯（confidence filter）：

- F3 原標為 Warning、`confidence` 65，落在 `[50, 80)`，降級為 Suggestion，不計入 blocking set；惟其指出的接縫問題具體且成立，仍一併修正。
- F5（`specs/subtitle-selection/spec.md` 的恆真 AND 與 403 scenario 缺專屬斷言）`confidence` 45，低於 50，依 filter 丟棄，未計入任何統計；其建議成本極低且與 F1 同向，已一併採用（spec 的 AND 改寫、tasks 3.6 加入 video-data 403 樣本訊息）。
- Reviewer V 對 tasks 2.1 第二個斷言「provider 指向不存在路徑時拋出 `MetadataError`」鑑別力較弱的附註，Reviewer V 自身已聲明不另計 finding，本輪未列入統計，亦未改動該斷言（第一個斷言已具鑑別力）。

pre-round 機械自檢（本輪 fix actions 完成後重跑）：

- 註解平衡：delta spec 無 `<!--`／`-->`。
- 數量一致性：design Implementation Contract 維持 11 條，tasks 引用涵蓋第 1 至第 11 點全部條號，未因本輪新增任務而產生落差。
- 識別字交叉檢查：新引用的 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"` 在 `Tubify/Services/YouTubeMetadataService.swift` 中共 5 處，拼寫與 artifacts 敘述一致；`handlePostLiveFormatLookupError`、`YTDLPFormat.hasUsableMediaFormats` 拼寫核對無誤。
- 平行標記檢查：自檢發現本輪新增的 4.4、4.5 若標為 `[P]`，其目標檔案分別與 4.1、4.2 相同（`Tubify/ViewModels/DownloadManager.swift` 與 `Tubify/Services/YouTubeMetadataService.swift`），雖同為唯讀檢查仍違反「同檔不平行」原則，已移除該兩項的 `[P]`；目前僅 4.1、4.2 保留 `[P]` 且目標檔案互不相同。
- delta spec 標題身分檢查：仍只有 `## ADDED Requirements`，不適用。
- signal-derived 檢查：30 個 open signal 皆無 `check` 欄位，回退 best-effort；本輪相關的 `test-setup-bypasses-target-condition`（F3）、`unassigned-verification-responsibility`（F1）、`unverified-design-claim`（F2）、`proposal-impact-file-scope-drift`（F4）、`parallel-task-shared-file`（自檢）皆已處理。
- 修正後重跑 `"$cash_cli" validate "cookieless-subtitle-detection"`：通過。

本輪 fix actions 未修改 change 目錄以外的任何檔案，因此不需執行 `touched record`。本輪無 `未修復：裁判面保護` 記錄。

## Decision

next_round
