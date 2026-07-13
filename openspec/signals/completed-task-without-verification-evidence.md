---
id: completed-task-without-verification-evidence
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r5.md
  - openspec/changes/improve-download-ui-workflows/reviews/apply-r6.md
---

# Task 完成宣稱缺少驗收證據

Tasks 若把完整測試或手動整合步驟列為 verification target，在勾選完成前 SHALL 執行並保留可稽核結果；無法由當前環境執行時，必須明確記錄限制、未驗證項目與替代證據，不得以未對應實際 wiring 的單元測試直接取代。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-apply-plus rounds 5–6（Reviewer A，confidence 100，Warning）：完整 suite 與多數 UI 檢查已補做，但 playlist view rebuild、真正重啟 recovery 與鍵盤焦點巡覽仍缺少手動證據或限制紀錄。
