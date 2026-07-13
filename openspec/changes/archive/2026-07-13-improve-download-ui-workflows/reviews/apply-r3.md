# Apply Plus Review — Round 3

## Reviewer Findings

### Critical

None.

### Warning

1. reviewer: `B`
   - severity: `Warning`
   - confidence: `95`
   - layer: `design`
   - location: `Tubify/ViewModels/DownloadManager.swift:207-215, 616-636`
   - summary: `registerMediaRequest` 對整批來源採 all-or-nothing 存在性檢查；若 playlist metadata 處理期間只移除其中一個 child，仍存在的 child 已進入 `.waitingForMediaSelection`，但整筆 request 會被捨棄而卡住。
   - recommendation: 進入等待狀態與註冊 request 前，先將批次過濾為仍存在於 manager 的 tasks，並加入移除單一 child 後其餘 child 仍收到一次媒體選擇請求的回歸測試。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 1
- critical_gap: `false`
- round_type: `full`

Reviewer A 未發現問題；Reviewer B 的 partial playlist batch finding 以 confidence 95 保留為 `Warning`，因此本輪為 `next_round`。此 finding 涉及 production behavior，下一輪必須是 `full`。

## Fix Actions

- 修改 `Tubify/ViewModels/DownloadManager.swift`：playlist 批次完成 metadata 後，只讓仍存在於 manager 且維持 `.fetchingInfo` 的 tasks 進入媒體選擇等待與 request registry。
- 修改 `TubifyTests/DownloadManagerTests.swift`：新增批次處理期間移除單一 child，剩餘 child 仍收到一次媒體選擇請求的回歸測試。
- 驗證：targeted regression test 修正前穩定失敗、修正後通過；完整 `DownloadManagerTests` 61/61 通過。

## Decision

next_round
