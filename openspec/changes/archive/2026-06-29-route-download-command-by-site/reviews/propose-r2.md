# Propose Plus Review — Round 2

## Reviewer Findings

### Critical

（無）

### Warning

- severity: `Warning`｜confidence: `88`｜reviewer: `A`
  - location: tasks.md task 2.1
  - summary: 跨參考失效——task 2.1 的驗證寫「見 5.1」，但 `effectiveDownloadCommand(for:)` 的單元測試實際為 task 6.1；task 5.1 是無關的 `EmptyStateView` 文案任務。
  - recommendation: 將 task 2.1 的「（見 5.1）」改為「（見 6.1）」。

### Suggestion

- severity: `Suggestion`（原 Warning，confidence 60 降級）｜confidence: `60`｜reviewer: `B`
  - location: tasks.md task 1.1 / design.md「通用指令採用固定常數」
  - summary: `commandTemplate` 由 `YTDLPService` 整條解析執行；`genericDownloadCommand` 若只存格式選擇器 `bv*+ba/b` 會產生無效 yt-dlp 呼叫，須為完整指令。
  - recommendation: 明訂 task 1.1：常數為與 `downloadCommand` 結構相同的完整指令，僅 `-f` 選擇器改為通用值。

#### 已捨棄（confidence < 50，不列入決策）

- B：非 YouTube playlist URL 的 metadata 與下載 `--no-playlist` 不對稱（confidence 40，捨棄）。
- B：`youtube.com/watch?list=` 無 `v=` 的邊際 URL 形狀（confidence 30，捨棄）。
- B：移除 fallback 改變無 scheme 文字的錯誤訊息路徑（confidence 35，捨棄）。

#### 重要否證

- B 對「將 playlist 處理閘控於 `isValidYouTubeURL()` 會破壞 YouTube 清單流程」的疑慮經查為**誤報**（confidence 95）：`isValidYouTubeURL()` 的 pattern 3 `youtube\.com/playlist\?(.*&)?list=` 確實匹配 YouTube 清單 URL；且該函式原本即為入口關卡，今日能進入清單展開的 URL 皆已通過它，重用於閘控不可能回退任何現行可運作的 YouTube 路徑。

## Rating

- 存活 Critical 數：`0`
- 存活 Warning 數：`1`
- critical_gap: `false`
- 理由：A 的跨參考失效發現 confidence 88（≥ 80）存活為 Warning，依規則本回合判定為 `next_round`；B 的完整指令發現雖降級為 Suggestion，但屬正確且廉價的澄清，一併修正。

## Fix Actions

- tasks.md：task 2.1 跨參考「（見 5.1）」改為「（見 6.1）」。
- tasks.md：task 1.1 明訂 `genericDownloadCommand` 為完整 yt-dlp 指令（結構同 `downloadCommand`，僅 `-f` 改為通用選擇器）。
- design.md：「通用指令採用固定常數」決策補充「完整指令、不可只存格式選擇器」。

`spectra validate` 通過。

## Decision

next_round
