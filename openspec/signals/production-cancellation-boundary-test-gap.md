---
id: production-cancellation-boundary-test-gap
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-02
last_seen: 2026-08-02
links:
  - openspec/changes/retry-transient-download-403/reviews/apply-r1.md
  - openspec/changes/retry-transient-download-403/reviews/apply-r2.md
---

# Cancellation 測試未穿透 production process boundary

Cancellation 測試若只注入 scripted attempt executor，未實際觀察 `executeDownload`、`Process.terminate()`、取消狀態傳遞與 process cleanup，便無法證明 active process 取消及取消後不進入 fallback 的 production wiring。

## Occurrences

- 2026-08-02 — `retry-transient-download-403` — cash-apply round 1（Reviewer B，confidence 88，Warning）：cancellation 測試未執行真實 `executeDownload` 與 `cancel(taskId:)` process boundary。
- 2026-08-02 — `retry-transient-download-403` — cash-apply round 2（Reviewer A、Reviewer B）：已加入可控 executable、真實 `Process` termination、PID exit 與 cookies fallback 負向 assertion；本輪 verdict 為 Resolved。

## Cleanup assertion occurrence

- 2026-08-02 — `retry-transient-download-403` — apply-r2 Reviewer A、Reviewer B：初版 boundary test 未直接觀察 process cleanup；已加入 PID exit assertion，verdict 為 Resolved。
