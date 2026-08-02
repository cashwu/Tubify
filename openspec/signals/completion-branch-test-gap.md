---
id: completion-branch-test-gap
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-07-13
last_seen: 2026-08-02
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r2.md
  - openspec/changes/retry-transient-download-403/reviews/propose-r1.md
---

# Preference test 未走實際 completion branch

當 requirement 規定 preference 影響完成後行為，tasks SHALL 驅動實際 completion branch 並驗證可觀察結果；只檢查 default 或儲存值不足以證明 runtime 行為。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 2（Reviewer A，confidence 100，Warning）：原 task 只覆蓋 auto-remove preference，未驗證完成項目保留或移除。
- 2026-08-02 — `retry-transient-download-403` — cash-propose round 1（Reviewer A，confidence 100，Warning）：原 test seam 只驅動內層 retry helper，無法證明 production `download` 的 first template、`shouldRetryWithCookies` 與 cookie-template fallback 實際分支。
