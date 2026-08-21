# Cash Apply Review — Round 5

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 驗證並檢查 Round 4 修復的 fix propagation。

### Cumulative blocking set verdict

- **N1: resolved** — Reviewer V 於 Darwin 25.5.0 / uid 501 / APFS 實測驗證決策 9 的修正表格。(1) **flag 清單完整性**：本機 `man 2 unlinkat` 恰列五個 flag，與表格逐字一致；Reviewer V 另做了未被要求的窮盡性檢查——把 `sys/fcntl.h` 其餘五個 `AT_*`（`AT_EACCESS`、`AT_SYMLINK_NOFOLLOW`、`AT_SYMLINK_FOLLOW`、`AT_REALDEV`、`AT_FDONLY`）傳入 `unlinkat` 一律 `-1 / EINVAL`，含 `unlinkat(fd, "", AT_FDONLY)` 這個最可能構成 fd 綁定刪除的組合，因此 kernel 實際接受的集合也恰為這五個。(2) **逐 flag 描述正確**：`AT_SYMLINK_NOFOLLOW_ANY` 對最終元件 symlink 回傳 0 並刪除、放中間元件才 `ELOOP`；`AT_RESOLVE_BENEATH` 在 dirfd 或 `AT_FDCWD` 搭配相對路徑時同樣回傳 0 並刪除，絕對路徑才 `ENOTCAPABLE`；`AT_NODELETEBUSY` 持有開啟 fd 時 `EBUSY`、關閉後回傳 0；`AT_UNIQUE` 對 2 個 hardlink `ENOTCAPABLE`、單一 link 回傳 0，且對 symlink（target 單一 link）回傳 0 只刪連結，證實其條件是解析後 vnode 的 link count 而非受檢項目的 identity。(3) **spec 新單句無字面反例**：`AT_NODELETEBUSY` 的條件是「路徑解析結果目前是否有任何開啟 fd」，不接受呼叫端持有的 fd 作為 identity（實測相反：持有 fd 反而失敗）。verifying reviewer：Reviewer V。

cumulative blocking set 現為空。

### 其他驗證通過的項目

- **未查證平台宣稱掃描**：Reviewer V 另實測三項先前未被驗證的宣稱，全部成立——決策 2 的 `isRegularFileKey` 對各型別的回傳值（含 `resourceValues` 不 follow symlink，因此 `testCleanupKeepsDirectoryAndSymlinkMatchingCandidateShape` 的 symlink 確實靠型別檢查而非 mtime 條件被保留，該測試的鑑別力註解成立）、決策 6 的 ACL `deny readattr` 行為、決策 8 的 `touch -h` 與 dangling symlink 憑空建立 target。
- **N2 措辭同步徹底**：spec／design／proposal／tasks／程式碼註解五處皆為「對任何目錄一律失敗」；殘留的「遞迴」字樣只有四處合法用法（列舉範圍、`removeItem` 反面對照、測試的暫存目錄清理）。
- **N3/N4 scenario 覆蓋**：15 個 scenario 全數被 tasks 覆蓋，無 dangling 引用，每個 scenario 本體各只有一個 WHEN。
- **註解與實作相符**，刪除確為 `unlink`，未使用 `removeItem`。
- **全套件**：`Executed 310 tests, with 0 failures`。

### Suggestion

**F1**（Reviewer V，`confidence` 60，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 4 的 N3/N4 修復）
- `location`: `specs/download-reliability/spec.md` 的兩個刪除原語 scenario
- `summary`: scenario 拆分把 Example 放錯位置——「刪除操作本身拒絕目錄」沒有 Example，「刪除操作不跟隨 symbolic link」底下連續掛了兩個 `##### Example:`，其中第二個談的是 `unlink` 對目錄的 `EPERM` 與 `removeItem` 的遞迴刪除，內容完全屬於目錄 scenario，卻以「此 scenario 驗收的是刪除操作本身的性質」自稱，形成 scope 錯配。Round 4 的 Fix Actions 明文寫「目錄 scenario 的 Example 補上『與該目錄是否為空無關』」，實際上該 Example 留在了被拆分出去的 symlink scenario 下，宣稱的修復動作沒有照描述完成。

**F2**（Reviewer V，`confidence` 35，`disposition` new）— 經 confidence filter 丟棄，downgrade trace 見 `## Fix Actions`。

**F3**（Reviewer V，`confidence` 30，`disposition` new）— 經 confidence filter 丟棄，downgrade trace 見 `## Fix Actions`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 0
- 非 blocking triaged finding count: 1
- `critical_gap`: false
- `round_type`: micro

rationale：cumulative blocking set 的唯一 member N1 取得 Reviewer V 的 `resolved` verdict 並以 verified resolution 離開集合，集合現為空。本輪新增的三個 finding 中，F1 `confidence` 60 經 confidence filter 後為 `Suggestion`，F2 與 F3 `confidence` 低於 50 遭丟棄，皆不進入 cumulative blocking set。pass 條件成立，因此 `decision: passed`。

## Fix Actions

pass 條件在任何修復之前即已成立。以下三項一併處理：F1 是 Round 4 的 Fix Actions 記錄與實際動作不符，必須更正；F2 與 F3 雖經 confidence filter 丟棄，但前者屬本 loop 已連續兩輪成為 blocking 的同一型態（可被字面推翻的全稱句），後者補的是 spec 明文保證「與是否為空無關」中唯一未被驗收的分支，成本各為一句與一段。

**F1 — 修復**。修改 `specs/download-reliability/spec.md`：把談 `unlink` 對目錄 `EPERM` 的 Example 整段移回 scenario「刪除操作本身拒絕目錄」之下，使兩個 scenario 各有一個對應自身的 Example。同時把該 Example 擴充為明確列出兩個反面對照——`FileManager.removeItem(atPath:)` 會遞迴刪除、`rmdir` 與 libc `remove(3)` 雖不遞迴卻會刪掉空目錄，兩者都不滿足這條 scenario。

**F2 — 修復**（經 confidence filter 丟棄，仍處理）。Reviewer V 指出決策 9 的「`sys/syscall.h` 也只有 `SYS_unlink` 與 `SYS_unlinkat`」可被 `SYS_delete`、`SYS_shm_unlink`、`SYS_sem_unlink` 字面推翻。實質結論不受影響（`delete(2)` 是路徑式的舊 HFS 刪除、後兩者是 POSIX IPC，都不提供 inode identity 綁定），但這正是 N1 指出的同一型態。已改為限定式敘述：「`sys/syscall.h` 中檔案系統的 unlink 系列 syscall 只有 `SYS_unlink` 與 `SYS_unlinkat`，沒有 fd 版本」。

**F3 — 修復**（經 confidence filter 丟棄，仍處理）。Reviewer V 指出 requirement body 的保證是「無論該目錄是否為空」，但刪除原語測試只以含檔案的目錄驗收，空目錄分支沒有斷言——而空目錄正是 Round 3 的 S4 用來論證「必須是刪除原語的性質而非不遞迴」的關鍵反例。修改 `design.md` Implementation Contract 第 9 點，明訂空目錄的斷言並說明其不可省略的理由；`tasks.md` task 1.18 同步；`TubifyTests/YTDLPServiceTests.swift` 的 `testUnlinkRefusesDirectoryAndDoesNotFollowSymlink` 補上對空目錄的 `unlink` 斷言（回傳 -1、`errno == EPERM`、目錄仍存在）。

**驗證**：修復涉及 `specs/download-reliability/spec.md`、`design.md`、`tasks.md` 與 `TubifyTests/YTDLPServiceTests.swift`。已執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；mechanical self-check 確認 15 個 scenario 全數被 tasks 覆蓋、每個 scenario 本體各只有一個 WHEN 且至多一個 Example。已執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，結果為 **310 tests, 0 failures**。

**Change 目錄外檔案修改**：本輪 Fix Actions 修改了 `TubifyTests/YTDLPServiceTests.swift`，已以 `touched record` 記錄。

## Decision

passed
