# Apply Plus Review — Round 4

## Reviewer Findings

### Critical

None.

### Warning

1. reviewer: `B`
   - severity: `Warning`
   - confidence: `95`
   - layer: `design`
   - location: `Tubify/ViewModels/DownloadManager.swift:257-263, 592-639`
   - summary: Playlist 批次的部分移除生命週期仍不完整；request 註冊後移除一個 task 會刪除整筆 unresolved request，讓其餘 task 卡在 `.waitingForMediaSelection`，而 metadata 批次完成前移除的 task 也可能污染剩餘 task 的媒體選項集合。
   - recommendation: 移除 task 時將既有 media request 正規化為仍存在的 tasks 並維持 request identity／confirmation resolution；metadata 聚合只納入最終仍存在的 tasks，並為 request 註冊後部分移除與已移除 child 唯一具有選項的情境加入回歸測試。

### Suggestion

None.

## Rating

- Critical: 0
- Warning: 1
- critical_gap: `false`
- round_type: `full`

Reviewer A 未發現問題；Reviewer B 的 partial-removal lifecycle finding 以 confidence 95 保留為 `Warning`，因此本輪為 `next_round`。此 finding 涉及 production behavior，下一輪必須是 `full`。

## Fix Actions

- 修改 `Tubify/ViewModels/DownloadManager.swift`：部分移除時保留原 request identity 並以剩餘 tasks 正規化 request 與可用媒體選項；舊批次確認可解除 normalized request；playlist metadata 選項改由最終仍有效的 tasks 聚合。
- 修改 `TubifyTests/DownloadManagerTests.swift`：新增 request 註冊後移除單一 child 並跨 session 重播剩餘 child，以及已移除 child 的獨有選項不得污染剩餘 child 的回歸測試；mock metadata service 增加 per-URL options 與完成查詢觀察點。
- 驗證：兩個 targeted regression tests 修正前共 4 個 assertion failures，修正後 2/2 通過；完整 `DownloadManagerTests` 63/63 通過；post-fix mechanical self-check 與 `spectra validate improve-download-ui-workflows` 通過。

## Decision

next_round
