---
id: completed-task-without-verification-evidence
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-08-21
links:
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r5.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r6.md
  - openspec/changes/dubbed-audio-track-selection/reviews/apply-r1.md
---

# Task 完成宣稱缺少驗收證據

Tasks 若把完整測試或手動整合步驟列為 verification target，在勾選完成前 SHALL 執行並保留可稽核結果；無法由當前環境執行時，必須明確記錄限制、未驗證項目與替代證據，不得以未對應實際 wiring 的單元測試直接取代。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus rounds 5–6（Reviewer A，confidence 100，Warning）：完整 suite 與多數 UI 檢查已補做，但 playlist view rebuild、真正重啟 recovery 與鍵盤焦點巡覽仍缺少手動證據或限制紀錄。
- 2026-08-21 — `dubbed-audio-track-selection` — cash-apply round 1（Reviewer A，confidence 90，Warning）：task 5.9 的手動驗收指定「選定日文音軌」且驗收點一要求確認清單至少含英文與日文，實際執行卻選了 `zh-Hant`，且未記錄該替換。同一個 task 的驗收點三改用其他 oracle 時有記 deviation，語言替換卻沒有，形成不對稱且不可稽核的紀錄。修復方式為補一筆 `deviation` 條目，載明替換內容、`ja` 與 `zh-Hant` 在 C3／C4／C5 上為同一條路徑同一種輸入的等價性論證、以解析層導出的可稽核 oracle（實跑 yt-dlp 取得純音訊軌 22 種語言，經 `LanguageFilter.isSupportedLanguage` 過濾為 `["en", "ja", "zh-Hans", "zh-Hant"]`，同時滿足 `count > 1` 與 spec Example 的「同時包含 `en` 與 `ja`」），並明示未直接觀察 UI 清單渲染結果。round 2 的 Reviewer V 獨立複驗全部數值與 log 證據後判定 resolved。附帶發現：app 的檔案日誌在結構上不記錄音軌偵測結果（`parseAudioTracks` 的計數只走 `os.Logger`），因此該驗收點本就無法以 app log 承接，解析層 oracle 是唯一可行的替代。
