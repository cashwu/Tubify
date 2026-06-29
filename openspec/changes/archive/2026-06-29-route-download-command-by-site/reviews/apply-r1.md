# Apply Plus Review — Round 1

## Reviewer Findings

### Critical

（無）

### Warning

（無——所有 Warning 經信心過濾後 confidence < 80，降級為 Suggestion）

### Suggestion

- severity: `Suggestion`（原 Warning，confidence 75 降級）｜confidence: `75`｜reviewer: `A`
  - location: tasks.md task 6.3；implementation-notes.md open-question 條目
  - summary: task 6.3 手動 e2e（以實際 x.com／Instagram 網址驗證 metadata、通用指令下載、`--cookies-from-browser safari` 是否有效）延後由使用者執行，保留 `[ ]`，誠實追蹤未誤標完成。
  - recommendation: 使用者於 Xcode 16+ 環境執行 app，加入一個公開 x.com 與一個 Instagram 貼文網址，確認各以單一任務入列、縮圖由 metadata 補上、下載完成（或留下明確失敗紀錄），記錄 Safari cookies 是否有效，然後勾選 6.3。

- severity: `Suggestion`｜confidence: `50`｜reviewer: `A`
  - location: implementation-notes.md deviation 條目（task 6.1）
  - summary: 測試置於既有 `DownloadManagerTests.swift` 而非新檔——理由充分（專案未用 file-system-synchronized groups，新檔需重產 project.pbxproj；task 6.1 僅要求 `@testable import` 呼叫真實方法，已達成）。
  - recommendation: deviation 接受，無需動作。

#### 已捨棄（confidence < 50，不列入決策）

- A：`xcodebuild test`／建置未在本環境執行（confidence 25，捨棄）——active 為 Xcode 15.4，專案為 format 77 需 Xcode 16+，屬環境限制非程式缺陷。
- B：`addURLAsSingleVideo`（約 line 566）的 `extractVideoIdSync`→ytimg 縮圖未閘控（confidence 35，捨棄）——經呼叫圖追蹤，該 private 方法僅經 `confirmVideoOrPlaylistChoice` ← 受 `isPlaylist`（含 `isValidYouTubeURL`）保護的混合 URL 提示可達，對非 YouTube 不可達；加 guard 屬 Surgical 紀律不鼓勵的防禦性處理。
- B：`getCookiesArguments` 對非 YouTube metadata 仍讀全域 `downloadCommand`（confidence 30，捨棄）——符合 task 2.2 明確指示，且與 open-question 6.3 重疊。

## Rating

- 存活 Critical 數：`0`
- 存活 Warning 數：`0`
- critical_gap: `false`
- 理由：兩位審查者確認實作忠實對齊 proposal／design Implementation Contract／spec／tasks，所有程式碼任務（1.1–6.2）完成，YouTube 路徑零回退、無 orphan 參考、新測試斷言真實 `commandTemplate` 並排除以 domain 為判斷的實作。唯一原 Warning（6.3 手動 e2e）confidence 75，經信心過濾降級為 Suggestion，且使用者已明確選擇「先以程式碼審查為準繼續」、將測試與實機 e2e 延後自行執行；該項屬環境限制而非程式缺陷。過濾後無存活的 Critical／Warning，依機械規則本回合判定為 `passed`。

## Fix Actions

None; pass condition met.

備註（非阻擋，供使用者於 archive 前完成）：
- 於 Xcode 16+ 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，確認全綠（涵蓋本次新增的 4 個路由測試）。
- 完成 task 6.3 手動 e2e 並勾選。

## Decision

passed
