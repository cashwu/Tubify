# Cash Propose Review — Round 1

## Reviewer Findings

本輪為 unseeded run 的第一輪，所有 surviving `Critical` 與 `Warning` 皆為 blocking，不標註 `disposition`。

### Critical

**C1**（Reviewer A）
- `severity`: Critical
- `confidence`: 100
- `layer`: design
- `location`: design.md `## Implementation Contract` 第 1 點 ↔ specs/download-reliability/spec.md `#### Scenario: 清理失敗不改變下載結果`
- `summary`: Contract 規定「讀取 `finalPath` 的 mtime 失敗時直接 return」，spec scenario 卻要求 mtime 讀取失敗時「記錄該失敗並繼續處理其餘候選檔案」，兩者對同一失敗的處置直接矛盾。
- `recommendation`: 區分致命失敗（放棄整輪清理）與非致命失敗（記錄後繼續下一個候選檔），並補一條 task 驅動「繼續處理」語意。

**C2**（Reviewer A 與 Reviewer B 獨立提出，依 `location + summary` 合併；Reviewer B 追加 fallback stem 風險）
- `severity`: Critical
- `confidence`: 100
- `layer`: design
- `location`: specs/download-reliability/spec.md requirement 本文 ↔ design.md `## Implementation Contract` 第 1 點
- `summary`: spec 定義候選檔案限定為最終輸出路徑的父目錄 `<dir>`，Contract 卻列舉傳入的 `outputDirectory` 參數；兩者在使用者自帶 `-o` 或走 `executeDownload` 的 60 秒最近媒體檔 fallback 時並不相同。Reviewer B 補充：該 fallback 在並行下載共用目錄時可能回傳另一個任務剛完成的影片，使清理拿錯誤的 stem 去掃描共用目錄。
- `recommendation`: 列舉目錄改由 `finalPath` 的 parent 推導，並在兩者不相同時放棄清理。

**C3**（Reviewer A）
- `severity`: Critical
- `confidence`: 100
- `layer`: design
- `location`: specs/download-reliability/spec.md `#### Scenario: cookies fallback 成功後刪除前一 attempt 的 partial 檔` ↔ master spec `### Requirement: 403 重試維持下載生命週期與 cookies contract`
- `summary`: 新 scenario 的 GIVEN 建立在「video-data 403 觸發 Safari cookies fallback」之上，但 master spec 逐字寫著「單純 target HTTP 403 MUST NOT 觸發 Safari cookies fallback」與「系統 MUST NOT 因 HTTP 403 本身建立或執行帶 cookies template」，合併後同一 capability spec 內會出現互相矛盾的敘述。
- `recommendation`: 把 scenario 的 GIVEN 改寫為不繫結 cookies 觸發條件的通用形式，或將 master spec 該 requirement 納入 MODIFIED 範圍並移除對應 Non-Goal。

**C4**（Reviewer A 與 Reviewer B 獨立提出，與 Reviewer A 另一筆「決策 4 敘述與實情不符」為同一 defect mechanism，三者合併）
- `severity`: Critical
- `confidence`: 90
- `layer`: design
- `location`: design.md 決策 4 與 `## Implementation Contract` 第 1 點；specs/download-reliability/spec.md `#### Scenario: stale operation 不執行清理`；tasks.md 1.8
- `summary`: `executeWithTransient403Retries` 在每個成功 attempt 之後、`return outputPath` 之前已呼叫 `isCancelled`（`Tubify/Services/YTDLPService.swift:367`），而 Contract 指定清理使用條件更弱的 `cancellationProbe: nil`，該檢查恆為 false。測試面亦不可行：`activeDownloadOperations`、`cancelledOperationIDs`、`runningProcesses` 皆為 `private`（`:159-161`），`@testable` 無法存取，seam 測試唯一能注入的 `cancellationProbe` 又被 Contract 明文忽略；走 production 雙 operation 路徑則會在 `:367` 就拋出 `.cancelled`，到不了清理點。結果是「有 scenario、有 task，但永遠測不到也永遠不會生效」。決策 4 另宣稱 stale 時「直接讓既有流程拋出 `YTDLPError.cancelled`」，但清理不拋錯、成功出口仍會回傳最終路徑，敘述與實情不符。
- `recommendation`: 承認該檢查冗餘，移除決策 4、對應 spec scenario 與 task，由 `:367` 的既有檢查承擔 stale operation 不清理的語意。

### Warning

**W1**（Reviewer A）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: design.md 決策 6；tasks.md 1.2
- `summary`: 決策 6 宣稱 production fixture 可證明「cookies fallback 分支確實走到清理程式碼」，但 `download` 硬編碼 `SafariCookiesService.shared`（`:245`、`:249`、`:256`），`transformCommand` 依賴 `PermissionService.hasFullDiskAccess()` 與真實 Safari binarycookies，無任何注入 seam；有無完整磁碟存取權限的機器會走進不同分支，既有 production 測試也刻意迴避此路徑。
- `recommendation`: 把宣稱範圍修正為「證明 production `download` 的多 attempt 成功路徑走到清理程式碼」，並讓 fixture 使用不含 `--cookies-from-browser safari` 的 template 以獲得確定性。

### Suggestion

**S1**（Reviewer B，原報 Critical `confidence` 65，經 confidence filter 降級）
- `location`: design.md 決策 2 條件 1 與 Risks
- `summary`: 僅以 `<stem>.` 為前綴判斷候選檔，在標題含點時會誤刪其他並行任務正在寫入的檔案（最終檔 `Lecture 1.mp4` vs 另一任務的 `Lecture 1.5.f401.mp4.part`）。此情境變更前不存在衝突，屬新引入的不可逆檔案破壞。

**S2**（Reviewer B，`confidence` 60）
- `location`: design.md 決策 2、決策 3、Risks
- `summary`: 預設下載目錄 `~/Downloads` 與瀏覽器共用，Firefox 進行中或暫停中的下載即命名為 `<檔名>.part`，可能同時符合前綴與後綴條件；mtime 保護對暫停中的檔案無效。

**S3**（Reviewer B，`confidence` 60）
- `location`: proposal.md Non-Goals；design.md 決策 2
- `summary`: 403 若發生在音訊階段，前一個 attempt 留下的是沒有 `.part` 後綴的完整 `<stem>.f401.mp4`，本方案抓不到，artifacts 對此形態完全沉默。

**S4**（Reviewer A 與 Reviewer B 獨立提出，`confidence` 65，合併）
- `location`: specs/download-reliability/spec.md `#### Scenario: 刪除中間檔留下可辨識日誌` ↔ tasks.md `## 1. Tests`
- `summary`: 該 scenario 是唯一沒有對應 task 的 scenario。

**S5**（Reviewer A，`confidence` 70）
- `location`: tasks.md 1.7；design.md `## Implementation Contract` 第 4 點
- `summary`: `download` 沒有 `sleeper` 注入點，以 video-data 403 驅動「所有 attempts 失敗」會實際套用 2/5/10 秒 backoff，測試耗時 17 秒以上；Contract 的 fixture case 也未定義全失敗行為。

**S6**（Reviewer B，`confidence` 50）
- `location`: design.md 決策 3、Risks；tasks.md 1.2、1.3、1.6
- `summary`: 「嚴格早於」的 mtime 比較在 exFAT（2 秒）或 SMB/NFS 掛載的 volume 上會讓清理常態性失效，fixture 依賴自然寫入時序也會 flaky。

**S7**（Reviewer A，`confidence` 55）
- `location`: specs/download-reliability/spec.md requirement 首句 ↔ design.md 決策 1
- `summary`: spec 主語為「單次 `YTDLPService.download` 呼叫」，但清理實際掛在 internal 的 `executeDownloadFlow` 成功出口，行為邊界與實作落點不完全對齊。

## Rating

- post-filter cumulative blocking set Critical count: 4
- post-filter cumulative blocking set Warning count: 1
- 非 blocking triaged finding count: 7
- `critical_gap`: true
- `round_type`: full

rationale：本輪為 unseeded run 的第一輪，4 個 Critical 與 1 個 Warning 全部進入 cumulative blocking set。C1、C2、C3 皆為 artifact 之間可直接引證的矛盾，依評分標準給 100；C4 由兩位 reviewer 獨立驗證到同一個「檢查恆 false 且無法測試」的機制，並由主 agent 覆核 `YTDLPService.swift:159-161` 的 `private` 存取層級與 `:367` 的既有檢查位置確認成立。存在 blocking Critical，因此 `decision: next_round`。

## Fix Actions

**C1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md` 與 `openspec/changes/cleanup-orphaned-part-files/specs/download-reliability/spec.md`：design 新增決策 6 明確區分致命失敗（快照取得失敗、最終輸出檔不存在或無法讀取 mtime、目錄列舉失敗 → 記錄 warning 後放棄整輪清理）與非致命失敗（單一候選檔的 mtime 讀取或刪除失敗 → 記錄後繼續下一個）；spec 對應拆為兩個 scenario「判斷前提不成立時放棄整輪清理」與「單一候選檔處理失敗時繼續處理其餘候選檔」。修改 `openspec/changes/cleanup-orphaned-part-files/tasks.md`，新增 task 1.11 與 1.12 分別驅動兩個分支。

**C2 — 修復**。修改 design.md 與 spec.md：新增決策 5，列舉目錄改由 `finalPath` 的 parent 推導，與 `outputDirectory` 標準化後不相同時放棄清理；spec requirement 新增條件 1，並新增 scenario「最終輸出檔不在該次下載的輸出目錄時不清理」。修改 tasks.md 新增 task 1.10 驅動該 scenario。Reviewer B 追加的 fallback stem 風險由決策 5 與決策 3 的快照共同緩解，並在 design 決策 5 記錄其殘餘限制。

**C3 — 修復**。修改 spec.md：scenario 改名為「較早 attempt 留下的中間檔被刪除」，GIVEN 改寫為不繫結 cookies 觸發條件的通用形式（較早 attempt 失敗留下中間檔、後續 attempt 以不同格式成功）。修改 tasks.md task 1.2 同步移除 cookies 措辭。master spec 未被修改，proposal 的對應 Non-Goal 保留。

**C4 — 修復**。修改 design.md：移除原決策 4 的 operation identity 檢查，改以新的決策 7 說明該檢查冗餘的理由並引用 `Tubify/Services/YTDLPService.swift:367`。修改 spec.md 移除 scenario「stale operation 不執行清理」。修改 tasks.md 移除原 task 1.8，並在 task 2.2 明確要求不呼叫 `isCancelled`。Contract 中的 `operationID` 參數一併移除。

**W1 — 修復**。修改 design.md 決策 8（原決策 6）：宣稱範圍改為「證明 production `download` 的多 attempt 成功路徑走到清理程式碼」，並明文說明 fixture 使用不含 `--cookies-from-browser safari` 的 template、不宣稱涵蓋 cookies fallback 分支。修改 proposal.md Non-Goals 新增「不新增 Safari cookies 轉換或 `PermissionService` 的注入 seam」。

**S1 — 修復**（非 blocking，一併處理）。修改 design.md 決策 2 與 spec.md requirement 條件 3：候選檔案在 `<stem>.` 前綴之外，剩餘部分必須整體符合 `^(f[0-9]+\.)?[A-Za-z0-9]{1,5}\.(part|ytdl|part-Frag[0-9]+)$`。新增 spec scenario「主幹為前綴且含點的其他影片中間檔保留」與 tasks.md task 1.6。proposal.md `## Alternatives Considered` 新增「只以檔名主幹為前綴判斷候選檔」條目記錄此取捨。

**S2 — 修復**（非 blocking，一併處理）。修改 design.md 新增決策 3：`executeDownloadFlow` 在第一個 attempt 前取得輸出目錄檔名快照，已存在於快照中的檔案一律不刪除。spec requirement 新增條件 2 並新增 scenario「下載開始前就已存在的中間檔保留」，tasks.md 新增 task 1.7。殘餘風險（同名第三方下載在本次呼叫期間才開始）記於 design Risks 第一項。

**S3 — 修復**（非 blocking，一併處理）。修改 proposal.md Non-Goals 明確排除沒有 `.part`、`.ytdl` 或 `.part-Frag<N>` 後綴的完整中間檔並說明理由；design.md Risks 新增對應條目。

**S4 — 修復**（非 blocking，一併處理）。修改 tasks.md 新增 task 3.2，以程式碼審查驗證刪除日誌包含 task ID 與被刪除檔名。

**S5 — 修復**（非 blocking，一併處理）。修改 design.md Implementation Contract 第 5 點：fixture 新增「單次失敗」case，以同時含有 `Giving up after` 與 video-data 403 片段的訊息失敗，`isRetryableDownload403` 對此回傳 false，單次 attempt 即結束。tasks.md task 1.9 同步指定使用該 case。

**S6 — 修復**（非 blocking，一併處理）。修改 design.md 決策 4 說明低時間戳解析度 volume 上清理常態性不生效並列為可接受的保守失敗；決策 8 要求 fixture 以 `touch -t` 明確設定 mtime。tasks.md task 1.1 同步要求。

**S7 — 修復**（非 blocking，一併處理）。修改 spec.md requirement 首句為「單次下載流程整體成功並取得最終輸出路徑後」，並補一句說明 `YTDLPService.download` 的所有成功路徑都經過該收尾點。

**Downgrade trace — Reviewer B `confidence` 45 的 finding 已依 confidence filter 丟棄**。該 finding 指出收斂單一成功出口後既有 seam 測試都會執行一次清理，而 Contract 未明說「`finalPath` 不存在時 no-op」。其建議已被 C1 的修復自然涵蓋：決策 6 明文將「最終輸出檔不存在」列為致命失敗並放棄清理，Contract 第 7 點另要求既有 seam 測試不得產生檔案系統副作用，tasks.md task 1.13 驅動之。

**驗證**：修復涉及 proposal、design、spec、tasks 四個 artifact，已重新執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`。

**Change 目錄外檔案修改**：本輪 Fix Actions 未修改 `openspec/changes/` 以外的任何檔案，因此不呼叫 `touched ensure` 與 `touched record`。

## Decision

next_round

cumulative blocking set 中仍有 4 個 Critical 與 1 個 Warning 已完成修復但尚未經 reviewer 驗證。依 graded convergence 規則，本輪為本 run 的第一輪且以 `next_round` 結束，下一輪位置為第二輪，因此下一輪為 `micro` round，由 Reviewer V 對 cumulative blocking set 逐一給出 resolved/unresolved verdict，並檢查修復是否引入新缺陷。
