# Propose Plus Review — Round 1

## Reviewer Findings

### Critical

（無）

### Warning

（無——所有原 Warning 經信心過濾後 confidence < 80，皆降級為 Suggestion）

### Suggestion

- severity: `Suggestion`（原 Warning，confidence 50 降級）｜confidence: `50`｜reviewer: `A`
  - location: design.md「Implementation Contract → Interface / data shape」與 tasks.md task 2.2
  - summary: 將 `getCookiesArguments` 納入路由會誤導實作——該 helper 僅由 metadata 路徑呼叫、不被 `downloadSingleTask` 呼叫，且兩種指令皆含相同 `--cookies-from-browser safari` 使路由結果無實質差異。
  - recommendation: 從路由範圍移除 `getCookiesArguments`，僅路由下載指令模板；`getCookiesArguments` 維持讀取全域 `downloadCommand`。

- severity: `Suggestion`（原 Warning，confidence 72 降級）｜confidence: `72`｜reviewer: `B`
  - location: design.md「Context／Failure modes」+ DownloadManager.swift `extractVideoIdSync` 縮圖預取
  - summary: `extractVideoIdSync` 的 `[\w-]{11}` 樣式會誤命中 Instagram 等 11 碼路徑片段，為非 YouTube 任務產生錯誤的 `i.ytimg.com` 縮圖，並非原註記的「優雅降級」。
  - recommendation: 將縮圖預取以 `isValidYouTubeURL()` 閘控，僅 YouTube 網址設定 ytimg 縮圖。

- severity: `Suggestion`（原 Warning，confidence 65 降級）｜confidence: `65`｜reviewer: `B`
  - location: design.md「Non-Goals」+ DownloadManager.swift `isPlaylistSync` 與混合 URL 提示
  - summary: `isPlaylistSync` 只比對 `list=`／`/playlist`，非 YouTube 網址若恰含 `list=` 會誤入清單展開或誤觸「下載單支或整個清單」提示。
  - recommendation: 將 playlist 偵測與混合 URL 提示分支以 `isValidYouTubeURL()` 閘控於 YouTube 網址。

- severity: `Suggestion`｜confidence: `60`｜reviewer: `B`
  - location: tasks.md 3.3 + ContentView.swift `processTextInput`
  - summary: task 3.3 前提不精確——`http(s)` 開頭文字本就會交給 `addURL`，`youtube.com/youtu.be` 比對僅為無 http 前綴文字的 fallback。
  - recommendation: 將 3.3 改為移除已多餘的 fallback 並驗證 http(s) 文字流向 `addURL`。

- severity: `Suggestion`｜confidence: `55`｜reviewer: `B`（與 A 的 cookies 發現同類）
  - location: tasks.md 2.2 + DownloadManager.swift `getCookiesArguments`
  - summary: 路由 `getCookiesArguments` 會牽動三個 metadata 呼叫點且無功能效益。
  - recommendation: 僅路由 `downloadSingleTask` 的下載指令模板。

#### 已捨棄（confidence < 50，不列入決策）

- A：`SettingsView` 未列入 Impact（confidence 35，捨棄）。
- B：非 YouTube `/playlist` URL 進入 `fetchPlaylistInfo` 會產生偽 YouTube watch URL（confidence 45，捨棄；且由 playlist 閘控連帶解決）。

## Rating

- 存活 Critical 數：`0`
- 存活 Warning 數：`0`
- critical_gap: `false`
- 理由：兩位審查者的所有實質發現 confidence 皆 < 80，經信心過濾後一律降級為 Suggestion，機械上無存活的 Critical 或 Warning。惟 B 的兩項 Suggestion（非 YouTube 縮圖誤判、playlist／提示誤觸）與使用者「不動原本 YouTube 好的部份」目標直接相關且確實正確；主代理選擇納入這些實質修正，因其改動了規格與任務範圍，故本回合判定為 `next_round` 以對更動後的成品再次驗證，而非就此 `passed`。

## Fix Actions

採納高價值 Suggestion，修改下列檔案：

- spec.md：新增需求 `YouTube-specific handling is gated to YouTube URLs`（含 playlist／提示／ytimg 縮圖閘控的 Scenario 與範例表）。
- design.md：新增決策「YouTube 專屬處理一併納入路由」；修正「依網址分流」決策使 `getCookiesArguments` 不納入路由；更新 Interface/Failure modes/Acceptance/Scope。
- proposal.md：新增 What Changes 條目（YouTube 專屬分支閘控）；修正 processTextInput fallback 描述；更新 Impact。
- tasks.md：新增 task group 4（4.1 playlist／提示閘控、4.2 縮圖閘控）；修正 2.2（cookies 不路由）、3.3（移除多餘 fallback）；UI 與測試群組順延為 5、6。

`spectra validate` 通過。

## Decision

next_round
