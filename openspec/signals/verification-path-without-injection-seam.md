---
id: verification-path-without-injection-seam
type: recurring-finding
status: open
occurrences: 1
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/dubbed-audio-track-selection/reviews/propose-r1.md
---

# 指派的驗收手段在受測程式碼中沒有可用接縫

task 指定「以某某方式觀察某某行為」時，若該路徑上的協作者是硬編碼的單例、或其成敗取決於執行機器的權限狀態，該驗收就無法在 apply 階段可靠執行；而既有測試為了繞開它所使用的另一個接縫，往往正好看不到要驗的東西，兩條路互斥。這與 [[test-setup-bypasses-target-condition]] 不同——那裡測試確實跑到了目標，只是被更早的條件攔下；這裡是連進入目標條件的手段都不存在。

指派驗收手段時 SHALL 先確認該手段在受測程式碼中有可用接縫（可注入的協作者、有預設值而可直接呼叫的內部入口、或不依賴機器狀態的純函式）。沒有接縫時 SHALL 拆成數段可執行的斷言並明寫每段各自覆蓋什麼，其餘部分改由 code review 承接，MUST NOT 讓一條做不到的 task 成為某個 scenario 的唯一承接者。

## Occurrences

- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 80，Critical）：delta spec「帶 cookies 的重試同樣帶上 extractor args」scenario 的唯一承接 task 要求以 `download` 加 fixture 觀察第 2 次 invocation，但 `download` 的 cookies fallback 由硬編碼的 `SafariCookiesService.shared.transformCommand` 提供（`Tubify/Services/YTDLPService.swift:281`），缺完整磁碟存取時回傳 `nil`、第 2 次 invocation 根本不會發生；既有 cookies 測試為此全部改走 `executeDownloadFlow(attemptExecutor:)` 接縫，而該接縫以閉包取代真實 process，看不到 fixture argv。已拆為三段承接（第一次 attempt 的 argv、直接驅動 `executeDownloadFlow` 的 fixture、`removeSafariCookies` 的字串斷言）加一條 code review，round 2 的 Reviewer V 判定 resolved。
