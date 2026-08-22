---
id: verification-anchor-points-at-wrong-file
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/dubbed-audio-track-selection/reviews/propose-r1.md
---

# 檢查任務把識別字錨定在不含它的檔案，該檢查無法執行

「對照 diff 確認某某未被改動」這類 code review 任務會同時指名要檢查的識別字與要檢查的檔案。當識別字實際上定義在別的檔案時，執行者在指定範圍內找不到它——最可能的結果是視為「沒有被改動」而放行，於是這條檢查對它宣稱保護的 Non-Goal 貢獻為零。與 [[tasks-stale-cross-reference]] 的差別在於失效的對象：那裡是任務之間的編號參考，這裡是任務指向程式碼的錨點。

撰寫此類任務時，每一組「識別字 + 檔案」SHALL 以 grep 實際確認該識別字出現在該檔案中；一個檢查點涵蓋多個識別字時 SHALL 逐一確認，或拆成各自指向正確檔案的多個檢查點。

## Occurrences

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 95，Warning）：Non-Goals 的迴歸檢查任務要求在 `Tubify/ViewModels/DownloadManager.swift` 與 `Tubify/Views/MediaSelectionView.swift` 確認 `filteredAudioTracks.count > 1` 門檻與 `LanguageFilter.supportedLanguagePrefixes` 未被改動，但後者只存在於 `Tubify/Models/SubtitleInfo.swift:6`（且為 `private static`），兩個指名檔案完全沒有該識別字。已拆為兩個檢查點各指向正確檔案並附上行號，round 2 的 Reviewer V 逐一核對後判定 resolved。
