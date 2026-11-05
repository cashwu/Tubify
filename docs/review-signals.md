# Review 反覆出現的缺陷（Signals）

開發過程中，proposal／design／tasks／實作的各輪 review 會把「同類缺陷再次出現」記錄成 signal，共 35 則。它們描述的是**寫規格、寫任務、寫測試時容易犯的錯**，可當作日後撰寫與審查的檢查清單。

- 「出現次數」是被 review 抓到的次數；狀態全數為 `open`（只是累積記錄，並非待修的 bug）。
- 每則的「出現紀錄」保留原文，其中提到的 `spectra-propose-plus`、`cash-apply` 等是當時使用的 review 流程名稱。
- 內文提到的 change 名稱，可對照 [completed-tasks.md](completed-tasks.md)；規格見 [specs/](specs/README.md)。

## 目錄

**測試與驗證設計**（13）

- 驗收斷言恆真，實作寫錯也不會失敗（`tautological-acceptance-assertion`，×2）
- 測試 setup 使目標條件在更早的分支就被排除（`test-setup-bypasses-target-condition`，×2）
- 防護檢查或失敗注入在實際機制下永遠不生效（`unreachable-guard-or-dead-test`，×5）
- UI state 測試宣稱缺少可觀察接縫（`ui-state-test-without-observable-seam`，×2）
- 指派的驗收手段在受測程式碼中沒有可用接縫（`verification-path-without-injection-seam`，×1）
- Cancellation 測試未穿透 production process boundary（`production-cancellation-boundary-test-gap`，×1）
- Preference test 未走實際 completion branch（`completion-branch-test-gap`，×2）
- Notification activation 缺少可觀察 routing 與 delegate 驗證（`notification-activation-test-boundary`，×2）
- Recovery contract 的排除狀態缺少負向覆蓋（`recovery-excluded-state-coverage`，×2）
- Accessibility label requirement 缺少 accessibility-tree 驗證（`accessibility-label-verification-gap`，×1）
- Folder picker 起始位置 requirement 缺少整合驗證（`folder-picker-verification-gap`，×1）
- Backoff 取消 contract 缺少可觀察邊界（`backoff-cancellation-observation-gap`，×1）
- Task 完成宣稱缺少驗收證據（`completed-task-without-verification-evidence`，×2）

**規格、設計與任務文件的一致性**（12）

- design Implementation Contract 與 spec 對同一概念的定義不一致（`contract-spec-definition-mismatch`，×3）
- Delta spec 的 scenario 前提與 master spec 既有 requirement 矛盾（`delta-spec-contradicts-master-spec`，×1）
- design 對某機制效力的宣稱未經程式碼驗證（`unverified-design-claim`，×6）
- design 指派了驗證責任，tasks 沒有承接（`unassigned-verification-responsibility`，×2）
- 檢查任務內嵌未經查證的範圍斷言，使該檢查失去鑑別力（`verification-task-embeds-unverified-premise`，×1）
- 檢查任務把識別字錨定在不含它的檔案，該檢查無法執行（`verification-anchor-points-at-wrong-file`，×1）
- tasks.md 跨任務參考在重新編號後失效（`tasks-stale-cross-reference`，×2）
- tasks.md 驗證範圍在修正後仍保留過期宣稱（`tasks-stale-verification-scope`，×1）
- Proposal Impact 與實際修改檔案漂移（`proposal-impact-file-scope-drift`，×1）
- Parallel tasks 共用修改檔案（`parallel-task-shared-file`，×1）
- Bounded output 缺少可驗收的邊界規則（`bounded-output-rule-unspecified`，×1）
- 字串改寫規則漏掉目標語法的某個分隔語意，使自己的全稱保證失效（`rewrite-rule-misses-syntax-separator`，×1）

**Process、取消與錯誤分類**（4）

- Process termination 後 stderr drain 可能遺失 403（`stderr-drain-after-termination`，×7）
- Stale operation 在 Process 成功結束後仍可能回傳 success（`stale-operation-post-termination-success`，×1）
- Retry cancellation 只以 task ID 綁定 operation（`retry-cancellation-task-identity-race`，×1）
- Target 403 classification 未排除 Giving up after context（`target-403-giving-up-context-classification`，×1）

**UI 與任務恢復的生命週期**（6）

- App-level keyboard monitor 缺少目標視窗 gate（`paste-monitor-window-scope`，×1）
- View disappearance 被誤當成使用者取消（`view-disappearance-implicit-cancel`，×1）
- One-shot recovery 與 UI session 重建造成 request 遺失（`ui-session-request-replay-gap`，×2）
- Unresolved request registry 未跟隨來源生命週期（`unresolved-request-registry-lifecycle`，×1）
- Partial batch removal 未正規化 request 與選項（`partial-batch-request-lifecycle`，×1）
- 共用 persisted status 缺少來源 routing（`overloaded-persisted-status-recovery-routing`，×1）

---

## 測試與驗證設計

### 防護檢查或失敗注入在實際機制下永遠不生效

`unreachable-guard-or-dead-test`　出現 5 次　2026-08-21

新增的防護條件若在控制流上恆為 false，或測試的失敗注入手段在目標平台上根本不會失敗，就會產出「有 scenario、有 task，但永遠測不到也永遠不會生效」的死條文與永遠綠燈的死測試。撰寫防護與失敗注入時 SHALL 先驗證觸發路徑實際可達：對防護，確認上游沒有更早、條件更強的等價檢查；對失敗注入，確認該手段在目標平台的語意確實會使目標 API 失敗。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A confidence 90 與 Reviewer B 獨立提出，Critical）：清理開頭的 `isCancelled(...cancellationProbe: nil)` 恆為 false，因為 `executeWithTransient403Retries` 在成功 attempt 後已做過條件更強的同一檢查（`Tubify/Services/YTDLPService.swift:367`）；且 `activeDownloadOperations`、`cancelledOperationIDs`、`runningProcesses` 皆為 `private`（`:159-161`），seam 測試無法注入 staleness。已移除該檢查與對應 scenario、task，改由既有檢查承擔語意，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 2（Reviewer V，confidence 80，Warning，disposition fix-introduced）：task 要求「以唯讀權限使候選檔刪除失敗」，但 macOS 的 unlink 取決於父目錄寫入權限，`chmod 444` 的檔案仍會被 `FileManager.removeItem` 成功刪除，測試三項斷言仍全綠卻從未進入非致命失敗分支。已改為 `chflags uchg` immutable flag 並要求 `nouchg` 還原，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer B，confidence 80，Warning，disposition fix-introduced）：為修復「刪除條件未排除目錄」而新增的 `isRegularFileKey` 檢查被排在 mtime 檢查之前，而兩者來自同一次 `getattrlist`——讀不到 mtime 的項目其型別必然也讀不到，會先被「型別讀取失敗跳過」吃掉，使「候選檔 mtime 讀取失敗」從「有未發現的注入手段」變成原理上不可達，design 卻反過來以「沒有穩定注入手段」豁免其測試。已把兩個屬性合併為單次 `resourceValues(forKeys:)` 讀取、收斂為單一非致命分支，並以 ACL `deny readattr` 注入驅動，verdict 為 resolved。這是本 change 第三次出現同類缺陷。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer A 與 Reviewer B 獨立提出，confidence 100，Critical，disposition fix-introduced）：為修復「型別檢查與刪除之間的 TOCTOU」而新增的 task，其核心斷言在 contract 定義下恆不成立——目錄的 `resourceValues` 讀取成功並回傳 `isRegularFile = false`，走的是候選過濾分支，既非屬性讀取失敗也非刪除失敗，因此 `unlink` 根本不會被呼叫，而該項目既不在 `deleted` 也不在 `failed`。已改為不經過候選條件序列、直接驗證刪除原語性質的獨立測試，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer B，confidence 80，Warning，disposition new）：spec 的六項 MUST 條件之一「路徑不等於最終輸出路徑本身」在形態 regex 存在下恆為真——最終輸出檔名去掉 stem 前綴後恰為單一副檔名而不含點，而 regex 每個分支都要求至少一個點（實測九種檔名形狀全部不通過）。該條件永遠攔不下任何項目，也不可能有 task 驅動。已移出 spec 的規範性條件，實作保留為 defence-in-depth 並在 design 明文標記其不可達，verdict 為 resolved。

### Task 完成宣稱缺少驗收證據

`completed-task-without-verification-evidence`　出現 2 次　2026-07-13 ～ 2026-08-21

Tasks 若把完整測試或手動整合步驟列為 verification target，在勾選完成前 SHALL 執行並保留可稽核結果；無法由當前環境執行時，必須明確記錄限制、未驗證項目與替代證據，不得以未對應實際 wiring 的單元測試直接取代。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus rounds 5–6（Reviewer A，confidence 100，Warning）：完整 suite 與多數 UI 檢查已補做，但 playlist view rebuild、真正重啟 recovery 與鍵盤焦點巡覽仍缺少手動證據或限制紀錄。
- 2026-08-21 — `dubbed-audio-track-selection` — cash-apply round 1（Reviewer A，confidence 90，Warning）：task 5.9 的手動驗收指定「選定日文音軌」且驗收點一要求確認清單至少含英文與日文，實際執行卻選了 `zh-Hant`，且未記錄該替換。同一個 task 的驗收點三改用其他 oracle 時有記 deviation，語言替換卻沒有，形成不對稱且不可稽核的紀錄。修復方式為補一筆 `deviation` 條目，載明替換內容、`ja` 與 `zh-Hant` 在 C3／C4／C5 上為同一條路徑同一種輸入的等價性論證、以解析層導出的可稽核 oracle（實跑 yt-dlp 取得純音訊軌 22 種語言，經 `LanguageFilter.isSupportedLanguage` 過濾為 `["en", "ja", "zh-Hans", "zh-Hant"]`，同時滿足 `count > 1` 與 spec Example 的「同時包含 `en` 與 `ja`」），並明示未直接觀察 UI 清單渲染結果。round 2 的 Reviewer V 獨立複驗全部數值與 log 證據後判定 resolved。附帶發現：app 的檔案日誌在結構上不記錄音軌偵測結果（`parseAudioTracks` 的計數只走 `os.Logger`），因此該驗收點本就無法以 app log 承接，解析層 oracle 是唯一可行的替代。

### Preference test 未走實際 completion branch

`completion-branch-test-gap`　出現 2 次　2026-07-13 ～ 2026-08-02

當 requirement 規定 preference 影響完成後行為，tasks SHALL 驅動實際 completion branch 並驗證可觀察結果；只檢查 default 或儲存值不足以證明 runtime 行為。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer A，confidence 100，Warning）：原 task 只覆蓋 auto-remove preference，未驗證完成項目保留或移除。
- 2026-08-02 — `retry-transient-download-403` — cash-propose round 1（Reviewer A，confidence 100，Warning）：原 test seam 只驅動內層 retry helper，無法證明 production `download` 的 first template、`shouldRetryWithCookies` 與 cookie-template fallback 實際分支。

### Notification activation 缺少可觀察 routing 與 delegate 驗證

`notification-activation-test-boundary`　出現 2 次　2026-07-13

系統通知 activation 同時包含 userInfo routing、外部 side effect 與 completion handler。Artifacts SHALL 定義可注入的 routing seam，並以自動測試或明確整合檢查驗證 delegate wiring 與 completion semantics。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus rounds 1、3（Reviewer A，confidence 90–100，Warning）：初版既無 Finder reveal seam，後續仍缺少 delegate-to-router 與實際 notification activation 驗證。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer B，confidence 90，Warning）：notification delegate 在非同步 launch task 才初始化，冷啟動 activation 可能早於 delegate wiring。

### Recovery contract 的排除狀態缺少負向覆蓋

`recovery-excluded-state-coverage`　出現 2 次　2026-07-13

Recovery 設計若明定部分狀態不得轉換或啟動副作用，spec 與 tasks SHALL 為這些排除狀態提供負向 scenario 與測試，不得只測會恢復的正向狀態。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer A+B，confidence 100，Warning）：七種非中斷狀態只有 design contract，沒有 spec scenario 或 task coverage。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer A，confidence 100，Warning）：七種排除狀態的測試未明確斷言三類 selection callback 都沒有副作用。

### 驗收斷言恆真，實作寫錯也不會失敗

`tautological-acceptance-assertion`　出現 2 次　2026-08-21

Contract 或 tasks 指定的驗收方式若比較的是兩個依定義相等的東西，或斷言的對象在受測型別上根本沒有可觀察的成員，該驗收就沒有鑑別力：實作正確會通過，實作忽略該條款也會通過，甚至在依賴缺失的機器上兩邊同為 `nil` 而一起通過。這與「觸發路徑不可達」（見 [[unreachable-guard-or-dead-test]]）不同——測試確實有執行，問題出在斷言本身無法區分正確與錯誤的實作。

指定驗收方式時 SHALL 先回答「若實作違反這一條，哪一個斷言會失敗」；答不出來就代表該驗收不成立。為新注入點寫驗收時，SHALL 斷言注入確實取代了預設來源（例如指向 fixture 後該 fixture 必須留下可觀察的痕跡），而非拿注入後的結果與預設結果互比。

**出現紀錄**

- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 1（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning）：為了讓兩階段 cookies 策略可測，design 決定為 `YouTubeMetadataService` 新增 `init(ytdlpPathProvider:)`，Contract 指定的驗收卻是「以預設方式建立的實例，其 yt-dlp 路徑解析行為與 `shared` 相同」。該 actor 沒有任何暴露路徑解析結果的成員，且預設實例與 `shared` 本來就呼叫同一個 `YTDLPService.shared.findYTDLPPath()`，兩者相等是定義上的恆等式；在未安裝 yt-dlp 的機器上兩者同為 `nil`，測試照樣全綠。改為行為式驗收後（provider 指向 fixture 執行檔時，fixture 必須留下 invocation 記錄——實作若忽略 provider 而沿用預設解析，該斷言必定失敗），round 2 的 Reviewer V 判定 resolved。同一輪 reviewer 也指出附帶的第二個斷言「provider 指向不存在路徑時拋出 `MetadataError`」鑑別力較弱：忽略 provider 的實作在裝有 yt-dlp 的機器上多半也會以其他原因拋出同型錯誤而矇混通過。
- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 88，Warning）：為驗證 format 切分是否 bracket-aware 而寫的 task，驗收方式是「結果的 alternative 數量與原字串一致」。對 `ba[format_note*=A/B]+bv` 而言，bracket-aware 實作與 naive 實作在各自的計數慣例下都會與原字串相等，無論實作對錯、無論用哪一種計數，斷言都通過。已改為完整字串相等斷言（預期 `ba[format_note*=A/B]+bv[language=ja]`），該字串對 naive `/` 切分具鑑別力，round 2 的 Reviewer V 判定 resolved。

### 測試 setup 使目標條件在更早的分支就被排除

`test-setup-bypasses-target-condition`　出現 2 次　2026-08-21

當一組條件依序求值時，測試若把受測項目佈置成「在更早的條件就被攔下」，該測試永遠不會執行它宣稱要驗證的那個條件。斷言仍然成立、測試全綠，但它證明的是另一件事。撰寫「保留類」或「不執行類」測試時，SHALL 確認受測項目確實走到目標條件才被攔下，而不是在前置條件就出局；scenario 的 GIVEN 若已寫明前置條件（例如「不在快照中」），tasks 與 fixture 規格 MUST 提供達成該 GIVEN 的手段。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition fix-introduced）：新增的目錄／symlink 保留測試若由測試在呼叫 `download` 之前建立那些項目，它們會落入目錄快照而被「不在快照中」的條件提前排除，完全不會走到要驗證的型別檢查條件。fixture 規格未提供在 invocation 期間建立這些項目的手段。已擴充 fixture case 並明訂項目必須由 fixture 在 invocation 期間建立，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 5（Reviewer V，confidence 60，Suggestion，disposition new）：同一原則未套用到其他兩個「保留類」測試的干擾檔，使前綴比對與形態比對這兩項核心防護同樣不會被執行。已在 fixture 規格與對應 tasks 中泛化該要求。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 1（Reviewer A 與 Reviewer B 獨立提出，confidence 95，Warning）：實作階段的「保留」類測試以 `write(to:)` 建立預先存在的候選檔，其 mtime 為執行當下的真實時間，而 fixture 的最終輸出檔以 `touch -t` 設為多年前，於是實際攔下該檔的是 mtime 條件而非它宣稱驗收的快照條件。Reviewer B 以 mutation 實測確認：把快照 guard 換成恆真式後全部 85 個測試仍全綠，該條件在整個測試套件中沒有任何具鑑別力的覆蓋。已把預先存在檔案的 mtime 明確設早於最終輸出檔，並以 mutation 反向確認測試會轉紅，verdict 為 resolved。此為 propose 階段同一 change 反覆出現後，在 apply 階段以另一種形式再現。

### UI state 測試宣稱缺少可觀察接縫

`ui-state-test-without-observable-seam`　出現 2 次　2026-07-13

`tasks.md` 宣稱一般單元測試可驗證 private UI state 或生命週期 wiring，但實作範圍沒有提供測試可呼叫的接縫，也沒有可觀察 view 行為的 UI 測試機制。這會讓 apply 階段重寫同一段集合邏輯來製造表面測試，卻無法證明實際 UI 使用該邏輯。

撰寫 UI 狀態任務時，SHALL 讓自動測試對應實際共用的最小接縫，或明確把無法由現有 test target 觀察的 wiring 指定為手動驗證；不得宣稱測試覆蓋不存在的觀察路徑。

**出現紀錄**

- 2026-07-13 — `add-clear-all-subtitles` — spectra-propose-plus rounds 1–2（Reviewer B、Reviewer A+B，confidence 90–95，Warning）：字幕清空與 `.onAppear` 預設全選均位於 private `@State`，原 tasks 未提供一般 XCTest 可觀察的實作接縫。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus rounds 1–2（Reviewer A+B，confidence 100，Warning）：monitor lifecycle 與 Settings validation 原先宣稱由 XCTest 覆蓋，但 artifacts 未定義 view 實際共用的 observable seam。

### Accessibility label requirement 缺少 accessibility-tree 驗證

`accessibility-label-verification-gap`　出現 1 次　2026-07-13

Keyboard focus 與 accessibility label 是不同契約。要求 descriptive labels 時，驗收 SHALL 包含 Accessibility Inspector、VoiceOver 或等價的 accessibility-tree 檢查，不能只靠 focus traversal 或 source scan。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：驗證只涵蓋 `.focusable(false)` scan 與鍵盤巡覽，未檢查 localized labels。

### Backoff 取消 contract 缺少可觀察邊界

`backoff-cancellation-observation-gap`　出現 1 次　2026-08-02

當作業在 async backoff 期間仍佔用 concurrency slot，artifacts 若要求取消及時結束，SHALL 定義 cancellation signal 如何喚醒或有界觀察 wait，並驗證取消後不再啟動新作業。單純在一次性 sleep 前後檢查 flag，不足以支持「立即取消」的 contract。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — cash-propose round 1（Reviewer A，confidence 100，Warning）：既有 `cancel(taskId:)` 只寫入 `cancelledTaskIds`，無法喚醒整段 2、5、10 秒 sleep，與 artifacts 的 backoff 及時取消承諾衝突。

### Folder picker 起始位置 requirement 缺少整合驗證

`folder-picker-verification-gap`　出現 1 次　2026-07-13

Folder picker 的初始目錄是系統 UI 行為；若現有 test target 無法觀察 panel state，tasks SHALL 明列具體路徑資料與手動整合步驟，確認 picker 實際定位正確。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer A，confidence 100，Warning）：含空格下載路徑 scenario 沒有確認 panel 起始目錄的驗證路徑。

### Cancellation 測試未穿透 production process boundary

`production-cancellation-boundary-test-gap`　出現 1 次　2026-08-02

Cancellation 測試若只注入 scripted attempt executor，未實際觀察 `executeDownload`、`Process.terminate()`、取消狀態傳遞與 process cleanup，便無法證明 active process 取消及取消後不進入 fallback 的 production wiring。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer B，confidence 88，Warning）：cancellation 測試未執行真實 `executeDownload` 與 `cancel(taskId:)` process boundary。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已加入可控 executable、真實 `Process` termination、PID exit 與 cookies fallback 負向 assertion；本輪 verdict 為 Resolved。

#### Cleanup assertion occurrence

- 2026-08-02 — `retry-transient-download-403` — apply-r2 Reviewer A、Reviewer B：初版 boundary test 未直接觀察 process cleanup；已加入 PID exit assertion，verdict 為 Resolved。

### 指派的驗收手段在受測程式碼中沒有可用接縫

`verification-path-without-injection-seam`　出現 1 次　2026-08-21

task 指定「以某某方式觀察某某行為」時，若該路徑上的協作者是硬編碼的單例、或其成敗取決於執行機器的權限狀態，該驗收就無法在 apply 階段可靠執行；而既有測試為了繞開它所使用的另一個接縫，往往正好看不到要驗的東西，兩條路互斥。這與 [[test-setup-bypasses-target-condition]] 不同——那裡測試確實跑到了目標，只是被更早的條件攔下；這裡是連進入目標條件的手段都不存在。

指派驗收手段時 SHALL 先確認該手段在受測程式碼中有可用接縫（可注入的協作者、有預設值而可直接呼叫的內部入口、或不依賴機器狀態的純函式）。沒有接縫時 SHALL 拆成數段可執行的斷言並明寫每段各自覆蓋什麼，其餘部分改由 code review 承接，MUST NOT 讓一條做不到的 task 成為某個 scenario 的唯一承接者。

**出現紀錄**

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 80，Critical）：delta spec「帶 cookies 的重試同樣帶上 extractor args」scenario 的唯一承接 task 要求以 `download` 加 fixture 觀察第 2 次 invocation，但 `download` 的 cookies fallback 由硬編碼的 `SafariCookiesService.shared.transformCommand` 提供（`Tubify/Services/YTDLPService.swift:281`），缺完整磁碟存取時回傳 `nil`、第 2 次 invocation 根本不會發生；既有 cookies 測試為此全部改走 `executeDownloadFlow(attemptExecutor:)` 接縫，而該接縫以閉包取代真實 process，看不到 fixture argv。已拆為三段承接（第一次 attempt 的 argv、直接驅動 `executeDownloadFlow` 的 fixture、`removeSafariCookies` 的字串斷言）加一條 code review，round 2 的 Reviewer V 判定 resolved。

---

## 規格、設計與任務文件的一致性

### design 對某機制效力的宣稱未經程式碼驗證

`unverified-design-claim`　出現 6 次　2026-08-21

`design.md` 宣稱「某測試能證明某分支被覆蓋」或「某條件能擋下某風險」時，若未對照實際程式碼驗證，宣稱可能完全不成立，而下游會據此認為該風險已被處理。每個此類宣稱 SHALL 引用具體的程式碼位置，並確認該位置的行為真的支撐宣稱；無法支撐時 SHALL 縮小宣稱範圍並把殘餘風險寫進 Risks。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 85，Warning）：design 宣稱 production fixture 可證明「cookies fallback 分支確實走到清理程式碼」，但 `download` 硬編碼 `SafariCookiesService.shared`（`Tubify/Services/YTDLPService.swift:245`、`:249`、`:256`），`transformCommand` 依賴 `PermissionService.hasFullDiskAccess()` 與真實 Safari binarycookies，無注入 seam，有無權限的機器會走進不同分支。已把宣稱範圍限縮為「多 attempt 成功路徑」，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 2（Reviewer V，confidence 85，Warning，disposition fix-introduced）：design 決策宣稱目錄相等性檢查可擋下「`executeDownload` 的 60 秒最近媒體檔 fallback 找到別處的檔案」，但該 fallback 只列舉 `outputDirectory` 本身（`:849`），回傳路徑的 parent 恆等於 `outputDirectory`，相等性檢查永遠通過，該決策對此風險貢獻為零。已刪去錯誤宣稱並新增 Risks 條目，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition fix-introduced）：design 以「列舉後才刪除的候選檔仍會讀到 URL 的快取值」論證某分支不可測，但該行為只在 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取 URL 下成立；Contract 未指定清理階段的列舉 API，改用 `contentsOfDirectory(atPath:)` 加新建 URL 時該讀取會以 `NSCocoaErrorDomain` 260 真實失敗。已明確指定列舉 API 並禁止取用預取快取，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 3 與 round 4（Reviewer B confidence 90、Reviewer V confidence 85，皆 Warning）：修正 spec 的 symbolic link 矛盾時，先寫了「要消除此 TOCTOU 窗口需以 file descriptor 綁定受檢項目」——實測 `funlinkat` 在 macOS 不存在、`unlinkat` 的 nofollow flag 只作用於中間路徑元件，該機制根本不存在，等於把平台限制寫成了範圍取捨。改為平台事實並搬入 design 後，該份平台調查本身又寫錯：宣稱 `unlinkat` 只有三個 flag，實際有五個，遺漏的 `AT_NODELETEBUSY` 恰好字面反證了同段的全稱句。根因是直接沿用上一位 reviewer 給的列舉而未自行查證 man page。已改為表格列出全部五個 flag 並逐一說明為何都不構成 identity 綁定，由後續 reviewer 以窮盡性實測（其餘五個 `AT_*` 傳入 `unlinkat` 皆 `EINVAL`）確認完整，verdict 為 resolved。教訓：修正一個未驗證宣稱時，替代敘述同樣需要獨立查證，不可沿用他人未經自己驗證的清單。
- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 1（Reviewer A，confidence 100，Warning）與 round 2（Reviewer V，confidence 90，Warning，disposition fix-introduced）：同一個 issue class 在一次 run 內出現兩次。round 1 是 design 與 proposal 宣稱下載路徑的 cookies fallback 分類函式是 `indicatesLoginRequired(_:)`，實際 gate 是其嚴格超集 `shouldRetryWithCookies(_:)`（`Tubify/Services/YTDLPService.swift:336`、`:698-699`），漏掉 `isDownloadVideoData403` 這一半。round 2 更值得記：修正 round 1 時新寫的 Contract 條款宣稱「stderr 為空時分類輸入為既有的 `未知錯誤` fallback 字串」，但既有程式碼是 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"`——空 `Data` 以 UTF-8 解碼回傳空字串而非 `nil`，fallback 根本不生效，照此寫成的測試會是一條對照既有實作必然失敗、卻標為「驗證既有行為」的測試。兩者 verdict 皆為 resolved。教訓與既有條目一致並再次應驗：新寫的事實敘述（尤其是描述「既有行為」的那種）同樣要逐字對照程式碼，`??` 這類 fallback 的觸發條件必須確認，不能從語意直覺推斷。

- 2026-08-21 — `cookieless-subtitle-detection` — cash-apply round 1（Reviewer A，confidence 85，Warning）：design Risks 宣稱把手動驗證的驗收點改為「實際產生對應語言的字幕檔」可「使這個失敗模式在驗證時可被看見」，但實際驗證回合證明該驗收點對該失敗模式毫無鑑別力：yt-dlp 先寫字幕、後抓 video data，cookieless 的第一次 invocation 在 `unable to download video data: HTTP Error 403: Forbidden` 之前就已把 `.zh.srt` 寫到磁碟（`~/Library/Logs/Tubify/tubify-2026-08-21.log`：15:26:41.472 字幕 `100% of 20.08KiB` → 15:26:41.518 403 → 15:26:41.573 帶 cookies 重試 → 15:26:44.164 `missing subtitles languages ... zh`），因此帶 cookies 的重試即使完全取不到該語言字幕，輸出目錄仍有字幕檔而使驗收通過——失敗模式確實發生了，驗收點卻放行。已改為據實敘明該驗收點無法觀察此失敗模式、其可觀察訊號是日誌中的 `missing subtitles languages` 警告，並把 tasks 4.7 驗收點二改寫為三項可歸因的判準（第一次執行命令不含 cookies 且含 `--write-sub` 與語言碼、該次 invocation 進度輸出顯示字幕下載完成、字幕檔 mtime 落在該次 invocation 期間以排除殘留檔），verdict 為 resolved。教訓：這是本 signal 首次出現在**手動驗證**的驗收點上而非測試上——宣稱某個驗收點「能讓某風險被看見」時，SHALL 先確認該驗收點觀察的產物不會由範圍外的其他機制同樣產生，否則它只能證明產物存在、無法歸因於哪一次嘗試。

### design Implementation Contract 與 spec 對同一概念的定義不一致

`contract-spec-definition-mismatch`　出現 3 次　2026-08-21

同一個失敗處置、範圍界定或資料來源若在 `design.md` 的 Implementation Contract 與 delta spec 的 requirement／scenario 各寫一次，兩份敘述容易分歧。實作者依 Contract 寫程式、驗收者依 spec 判定，分歧會直接變成驗收爭議。每個此類概念 SHALL 在兩份 artifact 中可逐條對應，且以同一組條件表述。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 100，Critical）：Contract 規定「讀取 `finalPath` 的 mtime 失敗時直接 return」，spec scenario 卻要求 mtime 讀取失敗時「記錄該失敗並繼續處理其餘候選檔案」。已改為明確區分致命失敗（放棄整輪清理）與非致命失敗（記錄後繼續下一個），spec 拆為兩個 scenario，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A confidence 100 與 Reviewer B 獨立提出，Critical）：spec 定義候選檔案限定為最終輸出路徑的父目錄，Contract 卻列舉傳入的 `outputDirectory` 參數，兩者在使用者自帶 `-o` 時並不相同。已改為列舉目錄由 `finalPath` 的 parent 推導、與 `outputDirectory` 不符時放棄清理，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 6（Reviewer A，confidence 100，Warning）：delta spec 已把 TOCTOU 窗口中的非目錄項目改為「可能」被刪除並涵蓋 `unlink` 失敗，但 design 的 hardlink 與 Risks 敘述仍保留「會被刪除」的絕對成功保證。已同步限縮為僅在 `unlink` 成功時產生名稱或內容損失，失敗時依單一候選檔非致命規則處理，round 7 verdict 為 resolved。
- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 85，Warning）：delta spec 的驗收 scenario 以「以 `/` 切開」定義 alternative，Implementation Contract 卻以「不位於 `[` 與 `]` 之間的 `/`」定義同一個概念。含中括號的 format（如 `ba[format_note*=A/B]+bv`）下，完全符合 Contract 的實作會被 spec 字面判定為違反。已把 alternative 的定義寫進 requirement 正文並與 Contract 逐字對齊，相關 scenario 改為引用該定義，round 2 的 Reviewer V 判定 resolved。

### tasks.md 跨任務參考在重新編號後失效

`tasks-stale-cross-reference`　出現 2 次　2026-06-29 ～ 2026-08-21

在 `tasks.md` 中，任務以「（見 X.Y）」相互參考。當新增任務群組或插入任務導致後續群組／任務編號順延時，既有的「（見 X.Y）」字面參考未同步更新，會指向錯誤甚至無關的任務，誤導 apply 階段的實作者。

撰寫或修改 `tasks.md` 時，凡調整任務編號（新增群組、插入任務、群組順延），SHALL 一併檢查並更新所有「見 N.M」字面跨參考，確保仍指向原意圖的任務。

**出現紀錄**

- 2026-06-29 — `route-download-command-by-site` — spectra-propose-plus round 2（Reviewer A，confidence 88，Warning）：新增 task group 4 使 UI／測試群組由 4、5 順延為 5、6 後，task 2.1 的「（見 5.1）」仍指向已變成 `EmptyStateView` 文案的 5.1，而非單元測試任務 6.1。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A，confidence 90，Warning，disposition fix-introduced）：新增 tasks 1.14–1.16 後，task 2.3 的「執行任務 1.2 至 1.13 的測試確認全部通過」未擴充範圍，使唯一驗證該輪 Critical 修復的 task 1.14 不會被執行。範圍參考同樣是跨任務字面參考，新增任務時必須一併更新。已改為涵蓋全部新增 task，verdict 為 resolved。

### design 指派了驗證責任，tasks 沒有承接

`unassigned-verification-responsibility`　出現 2 次　2026-08-21

當 `design.md` 寫下「某某由 code review 驗證」「某某由測試涵蓋」這類句子時，它就指派了一項驗證責任。若 `tasks.md` 沒有對應的 task 承接，該責任會憑空消失——artifacts 讀起來像是已經涵蓋，實際上沒有任何人會執行它。這比完全沒提還危險，因為 design 的敘述會讓後續 review 誤以為該面向已有歸屬。

design 每寫下一句指派驗證責任的敘述，SHALL 同時在 tasks 建立承接它的 task，或改為明確指向既有 task。review 時 SHALL 反向檢查：design 提到的每一項驗證責任，都能在 tasks 找到承接者。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 6（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition unresolved-prior）：design 為新增的 observer 機制寫下「日誌內容本身仍由 code review 驗證」，但 tasks 的 Verification 只有一條涵蓋成功刪除的 info 日誌，四個致命放棄路徑與兩條非致命失敗路徑的 warning 日誌既沒有測試也沒有 code review task。這使外部 review 指出的「失敗 warning 沒有驗收」只被修復了一半。已新增對應的 code review task 並把 design 該句改為明確指向它，verdict 為 resolved。
- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 1（Reviewer A，confidence 85，Warning）、round 2（Reviewer V，confidence 80，Warning，disposition unresolved-prior）：delta spec 的 requirement 主詞是「媒體選項查詢」，但唯一宣稱承接它的 task 只執行另一個服務既有的測試，全程不觸及 `fetchMediaOptions`。round 1 修正後 reviewer 判定為 unresolved——因為「有 task 承接」只達成字面：requirement 中「MUST NOT 另行維護第二份訊號清單」這一句沒有任何動作可觀察，實作在被測方法內複製一份清單同樣會讓全部行為測試通過。round 2 改為新增逐字 code review 任務（檢查該檔內沒有第二份訊號字串清單）才判定 resolved。教訓：承接是否成立要用「實作若違反此句，哪個動作會失敗」來檢驗；純否定式的 MUST NOT 條款通常沒有行為測試可觀察，需明確指派為 code review 並寫進 design 的驗證責任歸屬，兩份 artifact 的指派敘述也必須一致。

### Bounded output 缺少可驗收的邊界規則

`bounded-output-rule-unspecified`　出現 1 次　2026-07-13

Artifacts 使用 bounded、limited 或 truncated 描述輸出時，SHALL 指定長度單位、上限、截斷方式與邊界測試，避免不同實作者產生不一致行為。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：error summary 未定義上限、ellipsis 或 Unicode 計數方式。

### Delta spec 的 scenario 前提與 master spec 既有 requirement 矛盾

`delta-spec-contradicts-master-spec`　出現 1 次　2026-08-21

新增 scenario 的 GIVEN 若把某個行為當成既定前提，而同一 capability 的 master spec 正好逐字禁止該行為，archive 後同一份 spec 內會並存互相矛盾的敘述。撰寫 delta spec 前 SHALL 檢查 GIVEN 依賴的每個前提在 master spec 中是否被否定；若程式碼已與 master spec 漂移，SHALL 明確選擇「把該 requirement 納入 MODIFIED 範圍」或「改寫 GIVEN 使其不依賴該前提」，不得沉默地建立在被否定的行為之上。

**出現紀錄**

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 100，Critical）：新 scenario 的 GIVEN 建立在「video-data 403 觸發 Safari cookies fallback」之上，但 master spec `### Requirement: 403 重試維持下載生命週期與 cookies contract` 逐字寫著「單純 target HTTP 403 MUST NOT 觸發 Safari cookies fallback」。該 requirement 已因 `a1dffc6` 的直接修正而與程式碼漂移。已把 GIVEN 改寫為不繫結 cookies 觸發條件的通用形式，master spec 未動，verdict 為 resolved。

### Parallel tasks 共用修改檔案

`parallel-task-shared-file`　出現 1 次　2026-07-13

標記 `[P]` 的 tasks SHALL 具有互不重疊的修改檔案與依賴；若兩個 task 會編輯同一 source 或 test file，必須移除平行標記或重新分配合理的檔案邊界。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 100，Warning）：paste 與 error-summary tasks 同時指定 `TubifyTests/ContentViewTests.swift`。

### Proposal Impact 與實際修改檔案漂移

`proposal-impact-file-scope-drift`　出現 1 次　2026-07-13

Apply 階段若調整或確認實作 scope，proposal `## Impact` 的 affected-code entries SHALL 與 change 實際修改檔案同步，不得保留未修改的路徑或漏列必要檔案。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 5（Reviewer A，confidence 100，Warning）：`## Impact` 列出三個未由本 change 修改的 test files。

### 字串改寫規則漏掉目標語法的某個分隔語意，使自己的全稱保證失效

`rewrite-rule-misses-syntax-separator`　出現 1 次　2026-08-21

Contract 若以「切分、逐段加工、重組」的方式改寫某個外部工具的表達式（format selector、query、filter 字串），並同時寫下「每一段都 MUST 帶上某某限制」這類全稱保證，則規則涵蓋的分隔字元必須窮盡該語法真正的分隔語意。漏掉一個分隔字元，未被切出的那一段就不會被加工，全稱保證會在該語法出現時直接失效——而失效的形態往往正是這個變更要消滅的那一種（例如靜默沿用預設值），因此不會有任何錯誤訊號。

撰寫此類規則時 SHALL 逐一列出目標語法的全部分隔語意並實測確認（例如以工具本身跑一次含該字元的輸入，觀察它是否被當成分隔），無法涵蓋的語法 SHALL 寫入 Risks 並說明其失敗形態是明確失敗還是靜默降級。

**出現紀錄**

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer B，confidence 55；主 agent 實測後依 rubric 提升至 100，Warning）：Implementation Contract 只以不在 `[]` 內的 `/` 與 `+` 切分 yt-dlp 的 format 字串，漏掉 `,`（多重下載語法）。`bv+ba,b` 會被視為單一 alternative，最後一個 `+` part 是 `ba,b`，加工後成為 `bv+ba,b[language=ja]`——`bv+ba` 這一路完全沒有語言限制，正好回到該變更要消滅的「靜默交付原聲」，且直接違反 Contract 自己的「MUST NOT 產生任何不含 `[language=<code>]` 的 alternative」。實測 `-f "ba[language=ja],b"` 輸出 `Downloading 2 format(s): 251-0, 18` 確認 `,` 為合法分隔。已把 `,` 納入切分層級、補 scenario 與測試，並把不涵蓋的括號分組語法寫入 Risks，round 2 的 Reviewer V 判定 resolved。

### tasks.md 驗證範圍在修正後仍保留過期宣稱

`tasks-stale-verification-scope`　出現 1 次　2026-07-13

前置任務移除或改變自動測試保證後，後續整體驗證任務仍宣稱測試命令涵蓋已不存在的案例。這類修正傳播遺漏會讓 apply 階段把無法達成的驗證文字當成完成條件。

修改測試任務或驗證方式時，SHALL 同步檢查所有後續驗證任務與命令描述，確保其宣稱的覆蓋範圍仍和實際測試、手動檢查分工一致。

**出現紀錄**

- 2026-07-13 — `add-clear-all-subtitles` — spectra-propose-plus round 3（Reviewer A，confidence 100，Warning）：移除字幕預設全選的 XCTest 保證後，整體 `xcodebuild test` 任務仍誤稱會覆蓋該行為。

### 檢查任務把識別字錨定在不含它的檔案，該檢查無法執行

`verification-anchor-points-at-wrong-file`　出現 1 次　2026-08-21

「對照 diff 確認某某未被改動」這類 code review 任務會同時指名要檢查的識別字與要檢查的檔案。當識別字實際上定義在別的檔案時，執行者在指定範圍內找不到它——最可能的結果是視為「沒有被改動」而放行，於是這條檢查對它宣稱保護的 Non-Goal 貢獻為零。與 [[tasks-stale-cross-reference]] 的差別在於失效的對象：那裡是任務之間的編號參考，這裡是任務指向程式碼的錨點。

撰寫此類任務時，每一組「識別字 + 檔案」SHALL 以 grep 實際確認該識別字出現在該檔案中；一個檢查點涵蓋多個識別字時 SHALL 逐一確認，或拆成各自指向正確檔案的多個檢查點。

**出現紀錄**

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 95，Warning）：Non-Goals 的迴歸檢查任務要求在 `Tubify/ViewModels/DownloadManager.swift` 與 `Tubify/Views/MediaSelectionView.swift` 確認 `filteredAudioTracks.count > 1` 門檻與 `LanguageFilter.supportedLanguagePrefixes` 未被改動，但後者只存在於 `Tubify/Models/SubtitleInfo.swift:6`（且為 `private static`），兩個指名檔案完全沒有該識別字。已拆為兩個檢查點各指向正確檔案並附上行號，round 2 的 Reviewer V 逐一核對後判定 resolved。

### 檢查任務內嵌未經查證的範圍斷言，使該檢查失去鑑別力

`verification-task-embeds-unverified-premise`　出現 1 次　2026-08-21

檢查或 code review 類的 task 若在敘述中寫入「唯一會改變 X 的情形是 Y」「只有 Z 會受影響」這類範圍斷言，而該斷言未經查證，執行者會依它直接放行：既然「唯一」的情形已由別的 task 涵蓋，這條檢查就沒有事情要做。與 [[unverified-design-claim]] 的差別在於錯誤宣稱的落點——它寄生在驗證動作本身，因此不只是敘述錯誤，而是讓唯一承接某項迴歸的檢查失效。

撰寫檢查任務時 SHALL 避免未經窮舉的「唯一／只有」斷言；需要界定範圍時 SHALL 逐條列出可窮舉的情形並各自標明由誰驗證，或把檢查點改寫為可實際執行的斷言（給定輸入、預期輸出），而非要求執行者宣告一個結論。

**出現紀錄**

- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 3（Reviewer V，confidence 85，Warning，disposition fix-introduced）：round 2 為了修正另一個 finding 而新建的 code review task，括號內寫著「唯一會改變 `handlePostLiveFormatLookupError` 輸入的情形是兩次皆失敗時改以第二次 stderr 為準，已由 3.5 驗證」。方向恰好相反——變更前該路徑唯一的 metadata invocation 一律帶 cookies，變更後依 Contract 的非登入類失敗分支，輸入改以「不帶 cookies 的第一次」stderr 為準，那才是真正改變的主要情形；而「兩次皆失敗」時的第二次正是帶 cookies 那次，反而最接近變更前。該輸入直接決定任務落在 `.postLive` 還是 `.failed`，是這條唯一承接既有 spec 迴歸的檢查要保護的東西。照字面執行，reviewer 會依「唯一」推論已被涵蓋而放行。改為逐字列出兩種情形、並把檢查點換成可執行的 fixture 斷言（cookieless 訊息仍能被分類器判為 ended-live）後，round 4 的兩位 checkpoint reviewer 一致判定 resolved。

---

## Process、取消與錯誤分類

### Process termination 後 stderr drain 可能遺失 403

`stderr-drain-after-termination`　出現 7 次　2026-08-02

`terminationHandler` 與 `readabilityHandler` 沒有完成順序保證；若未先 drain pipe，最後的 target 403 可能變成未知錯誤而不觸發 retry。drain 也必須有界，避免殘留 writer 阻塞 actor。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — apply-r4 Warning：termination 後直接停止 handler，可能遺失 stderr；已改為 bounded non-blocking drain。
- 2026-08-02 — `retry-transient-download-403` — apply-r5 Warning：bounded drain 需涵蓋 continuous writer 與 cleanup evidence；已補 deadline 每輪檢查與 writer PID assertion。
- 2026-08-02 — `retry-transient-download-403` — apply-r6：確認 stderr drain、deadline、lock ordering 與 fixture cleanup，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r7：確認 stdout/stderr 共用 drain deadline，並通過 focused/full suite；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r8 Warning：shared deadline 下 stdout 可能讓 stderr starvation；已加入每個 fd 的 immediate nonblocking read 與 regression test，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r9 Warning：單次 immediate read 仍可能漏掉第二個 stderr chunk；已改用雙 fd poll loop 並補超過 8 KiB stderr regression test，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — apply-r10 Warning：EOF fd 留在 poll 集合可能 busy-spin；已以 `fd = -1` 排除並補 stdout EOF/stderr idle regression test，verdict 為 Resolved。

### Retry cancellation 只以 task ID 綁定 operation

`retry-cancellation-task-identity-race`　出現 1 次　2026-08-02

可重入的 retry flow 若只以可重用 `taskId` 儲存取消狀態，舊 operation 與新 operation 可能互相清除或觀察 cancellation signal，造成取消後錯誤啟動 process 或新下載受到舊取消影響。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer B，confidence 95，Warning）：backoff 中的舊 flow 與同一 `taskId` 的新 download 可能互相清除 `cancelledTaskIds`。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已以 `DownloadOperationID`、active replacement 與 operation-keyed process cleanup 修復；本輪 verdict 為 Resolved。

### Stale operation 在 Process 成功結束後仍可能回傳 success

`stale-operation-post-termination-success`　出現 1 次　2026-08-02

若 operation identity 只在 process termination status 或 retry 起點檢查，stale operation 可能在成功結果解析前穿越 cancellation 邊界並回傳舊結果。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B，Warning）：Process status 0 後缺少 operation identity check；已在成功結果處理前補檢查，verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 3（Reviewer A、Reviewer B，Warning）：outer retry flow 在成功 attempt 後缺少最後的 cancellation／operation identity check；已補上並以 regression test 固定，verdict 為 Resolved。

### Target 403 classification 未排除 Giving up after context

`target-403-giving-up-context-classification`　出現 1 次　2026-08-02

HTTP 403 retry classification 若只匹配 video-data 片段，未同時排除 `Giving up after` context，可能把已明確耗盡 downloader retries 的錯誤誤判為可恢復 target 403。

**出現紀錄**

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer A，confidence 100，Warning）：`isRetryableDownload403` 未排除同時含有 target 403 與 `Giving up after` 的錯誤。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已以分類條件與負向測試修復；本輪 verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 4（Reviewer A、Reviewer B）：production 多行 stderr context 保留與負向 fixture 已修復；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 6（Reviewer A、Reviewer B）：確認多行 context 與 bounded drain 無 blocking warning；verdict 為 Resolved。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 7（Code reviewer）：確認完整 error context、無 `lastError` fallback，且無 blocking warning；verdict 為 Resolved。

---

## UI 與任務恢復的生命週期

### One-shot recovery 與 UI session 重建造成 request 遺失

`ui-session-request-replay-gap`　出現 2 次　2026-07-13

Manager-wide idempotent recovery 若把待處理 request 只送到 view-local state，UI session 重建後可能永久失去操作入口。設計 SHALL 區分一次性 work activation 與每個 UI session 的 unresolved request delivery。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer B，confidence 90，Warning）：selection callbacks 寫入舊 `ContentView` state，新 view 又被 activation flag 阻止重播。
- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 1（Reviewer A，confidence 100，Warning）：實作測試尚未證明 playlist 與 video-or-playlist unresolved requests 對同 session 不重複、對新 session 各重播一次。

### 共用 persisted status 缺少來源 routing

`overloaded-persisted-status-recovery-routing`　出現 1 次　2026-07-13

同一 persisted status 若代表多種工作來源，recovery 設計 SHALL 明確辨識各來源、對應 entry point 與無法重建資料時的安全降級，不得一律送進單一路徑。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 95，Warning）：`fetchingInfo` 同時代表單支影片、playlist placeholder 與 playlist child，初版未區分恢復行為。

### Partial batch removal 未正規化 request 與選項

`partial-batch-request-lifecycle`　出現 1 次　2026-07-13

批次工作在部分 child 被移除後，SHALL 以仍存在的 tasks 重新聚合選項、維持或解除 unresolved request，並限制 confirmation 只影響 active task 的實際可用選項，避免其餘 child 卡住或遭 removed-only selection 污染。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus rounds 3–5（Reviewer B，confidence 95，Warning）：playlist media request 的建立、註冊後移除與舊 request confirmation 依序暴露 partial-batch lifecycle 缺口。

### App-level keyboard monitor 缺少目標視窗 gate

`paste-monitor-window-scope`　出現 1 次　2026-07-13

App-level local keyboard monitor 若只檢查 responder 類型，會在 Settings 或其他非目標視窗攔截事件。設計此類快捷鍵時，SHALL 同時定義可識別目標視窗的 gate 與非目標視窗負向驗證。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer A，confidence 100，Warning）：Command-V routing 未確認 event window 屬於主下載介面。

### Unresolved request registry 未跟隨來源生命週期

`unresolved-request-registry-lifecycle`　出現 1 次　2026-07-13

Manager 保存 unresolved UI request 時，registry SHALL 在來源 task 被移除或清空後同步清理，且 async work 註冊 request 前必須重新確認來源仍存在，避免新 UI session 重播 stale request。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus round 2（Reviewer B，confidence 90，Warning）：task removal、clear-all 與延遲 metadata／playlist completion 可能留下引用已刪除來源的 request。

### View disappearance 被誤當成使用者取消

`view-disappearance-implicit-cancel`　出現 1 次　2026-07-13

`onDisappear` 同時會由 parent teardown、window lifecycle 與 navigation 觸發，不能直接等同 explicit cancel。需要保留 unresolved work 的流程 SHALL 只在明確取消 action 時 resolve 或刪除資料。

**出現紀錄**

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 3（Reviewer B，confidence 100，Warning）：playlist sheet disappearance 會刪除 placeholder，破壞跨 session replay。
