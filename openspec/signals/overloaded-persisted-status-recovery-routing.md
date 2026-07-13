---
id: overloaded-persisted-status-recovery-routing
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r1.md
---

# 共用 persisted status 缺少來源 routing

同一 persisted status 若代表多種工作來源，recovery 設計 SHALL 明確辨識各來源、對應 entry point 與無法重建資料時的安全降級，不得一律送進單一路徑。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 1（Reviewer B，confidence 95，Warning）：`fetchingInfo` 同時代表單支影片、playlist placeholder 與 playlist child，初版未區分恢復行為。
