---
id: folder-picker-verification-gap
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r2.md
---

# Folder picker 起始位置 requirement 缺少整合驗證

Folder picker 的初始目錄是系統 UI 行為；若現有 test target 無法觀察 panel state，tasks SHALL 明列具體路徑資料與手動整合步驟，確認 picker 實際定位正確。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer A，confidence 100，Warning）：含空格下載路徑 scenario 沒有確認 panel 起始目錄的驗證路徑。
