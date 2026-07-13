---
id: view-disappearance-implicit-cancel
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-07-13
last_seen: 2026-07-13
links:
  - openspec/changes/improve-download-ui-workflows/reviews/propose-r3.md
---

# View disappearance 被誤當成使用者取消

`onDisappear` 同時會由 parent teardown、window lifecycle 與 navigation 觸發，不能直接等同 explicit cancel。需要保留 unresolved work 的流程 SHALL 只在明確取消 action 時 resolve 或刪除資料。

## Occurrences

- 2026-07-13 — `improve-download-ui-workflows` — spectra-propose-plus round 3（Reviewer B，confidence 100，Warning）：playlist sheet disappearance 會刪除 placeholder，破壞跨 session replay。
