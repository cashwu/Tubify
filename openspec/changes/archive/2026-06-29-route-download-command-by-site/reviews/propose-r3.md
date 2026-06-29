# Propose Plus Review — Round 3

## Reviewer Findings

### Critical

（無）

### Warning

（無）

### Suggestion

- severity: `Suggestion`（原 Warning，confidence 50 降級）｜confidence: `50`｜reviewer: `A`
  - location: proposal.md「What Changes」`genericDownloadCommand` 條目
  - summary: design／spec／tasks 已要求常數為完整指令，但 proposal 該條目的括號仍寫「通用格式選擇器，如 `bv*+ba/b`」，可能被誤讀為只存選擇器，是四份成品唯一未對齊「完整指令」之處。
  - recommendation: 將括號改為「完整通用指令，僅 `-f` 改為通用選擇器」以對齊 design／spec／tasks。

- severity: `Suggestion`｜confidence: `55`｜reviewer: `B`
  - location: tasks.md task 2.1／6.1 + repo 既有 `URLValidationTests` 慣例
  - summary: 成品未指定 `effectiveDownloadCommand(for:)` 的存取層級；repo 慣例（`URLValidationTests` 複製 `isValidYouTubeURL` 內文測試）顯示 `private` 成員無法經 `@testable import` 測試，將導致 6.1 測試複製邏輯而非驗證真實方法。
  - recommendation: 指定 `effectiveDownloadCommand(for:)` 為 `internal`，使測試實例化 `DownloadManager` 並呼叫真實方法。

#### 確認

- A 確認 r2 修正乾淨：唯一跨參考 task 2.1「見 6.1」正確指向單元測試任務；5 項 spec 需求皆有 backing task；任務編號 group 1–6 無缺口無重複；6 個 design `###` 決策標題皆出現於任務；7 條 What Changes 皆對映任務。
- B 確認下載接縫單一、cookies 重試邏輯鍵於 `--cookies-from-browser safari`（通用常數將包含）、無測試引用 `notYouTubeURL`、`ContentView` 權限檢查讀取 `downloadCommand` 不受影響；先前 `--no-playlist`、無 scheme 文字、邊際 URL 形狀均不回退 YouTube 路徑。

## Rating

- 存活 Critical 數：`0`
- 存活 Warning 數：`0`
- critical_gap: `false`
- 理由：兩項發現 confidence 皆 < 80，經信心過濾後為 Suggestion，無存活的 Critical 或 Warning，依機械規則本回合判定為 `passed`。兩項 Suggestion 屬零風險的純文字／存取層級澄清，於定稿時一併採納，不改變任何邏輯，無需再啟一回合。

## Fix Actions

- proposal.md：`genericDownloadCommand` 條目括號改為「完整 yt-dlp 指令，結構同 `downloadCommand`，僅 `-f` 改為通用選擇器如 `bv*+ba/b`」。
- tasks.md：task 2.1 指定 helper 存取層級為 `internal`（非 `private`）；task 6.1 明訂測試經 `@testable import` 呼叫真實方法並涵蓋 `youtube.com/playlist?list=`。

`spectra validate` 通過。

## Decision

passed
