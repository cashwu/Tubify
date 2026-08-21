# Cash Apply Review — Round 4

## Reviewer Findings

本輪為 micro round，由 Reviewer V 對 cumulative blocking set 驗證並檢查 Round 3 修復的 fix propagation。

### Cumulative blocking set verdict

- **M1: resolved** — Reviewer V 於 macOS 26.5.2 / Darwin 25.5、APFS、uid 501 重現全部三項實測：(1) `funlinkat` 在 SDK headers 全域 grep 無宣告、`ctypes.CDLL(None)` 探測為 ABSENT（同批 `unlinkat`／`openat`／`fstatat`／`unlink`／`rename` 皆 PRESENT），`sys/syscall.h` 只有 `SYS_unlink 10` 與 `SYS_unlinkat 472`；(2) `unlinkat(dirfd, "link", AT_SYMLINK_NOFOLLOW_ANY)` 對最終元件是 symlink 的路徑回傳 0 並刪除連結、target 內層檔案完好，把同一 symlink 放在**中間**元件則以 `ELOOP` 失敗；(3) `open(O_NOFOLLOW)` 對 symlink 以 `ELOOP` 失敗且無以該 fd 為條件的刪除原語。M1 的缺陷本體——spec 指名一個 macOS 不存在的機制、並把平台限制寫成「本變更不提供」的範圍取捨——已消除：spec 現為單句平台事實，機制論述整段移入 design 決策 9，且「此窗口無法以現有系統呼叫消除」這個結論經實測成立。verifying reviewer：Reviewer V。

cumulative blocking set 現為空。

### Warning

**N1**（Reviewer V）
- `severity`: Warning
- `confidence`: 85
- `layer`: design
- `location`: `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 9 的 `unlinkat` flag 列舉；連帶 `specs/download-reliability/spec.md` 的平台事實單句
- `summary`: 決策 9 新寫入的「`unlinkat` 的 flag 只有 `AT_REMOVEDIR`、`AT_SYMLINK_NOFOLLOW_ANY` 與 `AT_RESOLVE_BENEATH`」是可驗證的錯誤敘述。`man 2 unlinkat` 明列**五個** flag，另兩個為 `AT_NODELETEBUSY`（路徑上有開啟中的 fd 即失敗）與 `AT_UNIQUE`（解析到 link count > 1 的 vnode 即失敗），且兩者與已被引用的兩個 flag 位於 `sys/fcntl.h` 同一個 `__DARWIN_C_FULL` 區塊，沒有可用性上的理由排除。Reviewer V 實測兩者都確實被 kernel 執行：`AT_UNIQUE` 對 2 個 hardlink 的檔案回傳 `-1 / ENOTCAPABLE` 且不刪除、對單一 link 回傳 0；`AT_NODELETEBUSY` 在持有開啟 fd 時回傳 `-1 / EBUSY` 且不刪除。連帶地，spec 的單句「macOS 未提供以 file descriptor 或 inode identity 為條件的刪除原語」在字面上可被 `AT_NODELETEBUSY` 反證——它正是一個以 file descriptor 狀態為條件的刪除原語（只是條件極性相反、無法與「先 open 綁定再刪」併用）。M1 的實質結論不受影響（兩個遺漏的 flag 都不提供 inode identity 綁定，窗口仍無法消除），但 M1 的修復目的正是讓 spec／design 承載**準確**的平台事實，而這份平台調查留下一個可被推翻的「只有」與一個可被字面反證的全稱句，屬同一個 `openspec/signals/unverified-design-claim.md` 型態。
- `recommendation`: 決策 9 改為列出五個 flag 並逐一說明為何都不構成 identity 綁定；spec 單句改為「未提供把受檢項目綁定為 inode identity、再以該 identity 為條件刪除的原語」以避免字面反例；標註實測環境，並補上 `AT_RESOLVE_BENEATH` 的重現條件（相對路徑或 dirfd，絕對路徑搭配 `AT_FDCWD` 會以 `ENOTCAPABLE` 失敗，那不是保護效果）。
- `disposition`: fix-introduced
- `introduced_by`: Round 3 的 M1 修復——把機制論述搬入 design 決策 9 時，逐字沿用了 apply-r3 記錄的三項 flag 列舉，未自行查證 man page 的完整清單。

### Suggestion

**N2**（Reviewer V，`confidence` 60，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 3 的 S4 修復）
- `location`: `design.md` 決策 2 收尾句與 Implementation Contract 第 2 點；同一措辭亦見於 `Tubify/Services/YTDLPService.swift` 的註解
- `summary`: S4 已把保證的性質從「不遞迴刪除目錄」改為「對任何目錄一律失敗」，並在決策 9 明文說明為何前者不足，但決策 2 與 Contract 第 2 點仍寫「『絕不遞迴刪除目錄』／『不遞迴刪除目錄』由決策 9 承擔」——正是決策 9 明文否定的命名方式。只讀決策 2 或 Contract 的讀者會取得比 spec 弱的保證敘述。

**N3**（Reviewer V，`confidence` 55，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 3 的 S1 修復）
- `location`: scenario「刪除操作的型別性質」的 `##### Example:`
- `summary`: S1 為該 scenario 擴充了 symbolic link 的第二組 GIVEN/WHEN/THEN，但 Example 未同步——其「此 scenario 驗收的是刪除操作本身的性質，與條件 5 是否先攔下該項目無關」只以目錄為例，symlink 半段沒有同樣的定位說明。requirement body 寫「條件 5 評估時為 symbolic link 的項目 MUST NOT 被刪除」，scenario 卻寫「symbolic link → 刪除 SHALL 只移除該連結」，缺少定位句時兩者表面上互相否定，正是原 Critical 的閱讀路徑。

**N4**（Reviewer V，`confidence` 50，`layer` text，`disposition` fix-introduced，`introduced_by`: Round 3 的 S1 修復）
- `location`: 同一 scenario 本體（兩組 GIVEN/WHEN/THEN）
- `summary`: 在單一 scenario 本體內放入兩組 GIVEN/WHEN/THEN，在本 repo 既有 spec 中沒有先例。Reviewer V 掃描 `openspec/specs/*/spec.md` 的 76 個 scenario，只有 3 個含第二個 `WHEN`，且三者一律把第二組放在 `##### Example:` 子區塊內、本體維持單一 WHEN。不影響機械驗收，但兩個獨立行為共用一個 scenario 名會讓 task ↔ 行為的追溯變成一對多。

**N5**（Reviewer V，`confidence` 50，`layer` design，`disposition` fix-introduced，`introduced_by`: Round 3 的 S4 修復）
- `location`: spec 的「對任何目錄一律失敗」 vs `design.md` 決策 9 的「非 root 下」限定
- `summary`: S4 讓 spec 以無條件形式陳述該保證，而同一輪新增的 design 句子卻加了「非 root 下」限定；`man 2 unlink` 的 ERRORS 亦對 super-user 留有例外。實測（uid 501）空／非空目錄皆 `EPERM`，與 spec 一致，且 Tubify 是使用者身分執行的 GUI app，實作面無風險。缺陷只在於 spec 對外宣告的保證強度高於 design 與平台文件所支持的範圍。

### 其他驗證通過的項目

- **S2 窮盡性**：spec 的「任何非目錄項目」是全稱敘述，涵蓋 symlink／FIFO／socket／device／hardlink／一般檔案。實測 `unlink` 對 FIFO、unix socket、hardlink 皆回傳 0 只移除該名稱。「被替換成另一個一般檔案是最壞後果」正確——目錄不會被刪、其餘型別只失去名稱，只有一般檔案會連內容一併失去。
- **S1 可驗收性**：既有測試確實斷言 `unlink(link.path) == 0`、連結消失（lstat 語意）、target 內層檔案仍存在，完整對應新的第二組 GIVEN/THEN。
- **S4 與實作一致**：實作為 `Darwin.unlink`，實測對非空與空目錄皆 `-1 / EPERM` 且目錄完整，支持「無論該目錄是否為空」。
- **Cross-reference 完整性**：tasks 引用的 scenario 名與 spec 逐字對應、無 dangling 引用；proposal 兩處已同步；design 決策 9 的 S6 cross-reference 已指向現存措辭。
- **全套件**：`Executed 310 tests, with 0 failures`。

## Rating

- post-filter cumulative blocking set Critical count: 0
- post-filter cumulative blocking set Warning count: 1
- 非 blocking triaged finding count: 4
- `critical_gap`: false
- `round_type`: micro

rationale：M1 取得 `resolved` verdict 並以 verified resolution 離開 cumulative blocking set。本輪新增的 N1 `confidence` 85、`disposition` 為 `fix-introduced` 且 `introduced_by` 指向 Round 3 的具體修復動作，依規則進入 cumulative blocking set，因此 `decision: next_round`。N2–N5 經 confidence filter 後為 `Suggestion`，不進入該集合。

## Fix Actions

**N1 — 修復**。修改 `openspec/changes/cleanup-orphaned-part-files/design.md` 決策 9：`unlinkat` 的 flag 改以表格列出全部五個，逐一說明為何都不構成 identity 綁定——`AT_REMOVEDIR` 只切換 `rmdir` 語意；`AT_SYMLINK_NOFOLLOW_ANY` 與 `AT_RESOLVE_BENEATH` 只約束路徑解析，實測不保護最終元件；`AT_NODELETEBUSY` 的條件極性與「先 `open` 綁定再刪」互斥；`AT_UNIQUE` 的條件是 link count 而非 identity。同時標註實測環境（macOS 26.5.2 / Darwin 25.5、APFS、非 root），並補上 `AT_RESOLVE_BENEATH` 的重現條件（相對路徑或 dirfd；絕對路徑搭配 `AT_FDCWD` 會以 `ENOTCAPABLE` 失敗，那不是保護效果）。修改 `specs/download-reliability/spec.md` 的平台事實單句為「macOS 未提供『把受檢項目綁定為 inode identity、再以該 identity 為條件刪除』的原語」，消除 `AT_NODELETEBUSY` 的字面反例。

**N2 — 修復**（非 blocking，一併處理）。修改 design 決策 2 收尾句與 Implementation Contract 第 2 點，兩處「絕不遞迴刪除目錄」／「不遞迴刪除目錄」改為「對任何目錄一律失敗」。連帶修改 `Tubify/Services/YTDLPService.swift` 的兩處註解，同步為「對任何目錄一律以 EPERM 失敗（與是否為空無關）」，並補上「`removeItem` 會遞迴刪除，`rmdir` 則會刪掉空目錄，兩者都沒有這個保證」。此為註解修改，不影響任何行為。

**N3、N4 — 修復**（非 blocking，一併處理）。依 repo 慣例把兩組 GIVEN/WHEN/THEN 拆為兩個獨立 scenario：「刪除操作本身拒絕目錄」與「刪除操作不跟隨 symbolic link」，兩者本體各維持單一 WHEN。新的 symlink scenario 附 `##### Example:` 說明其定位——條件 5 評估時就是 symbolic link 的項目本來就不會進入刪除路徑，此處驗收的是刪除原語的性質，只可能發生在 TOCTOU 窗口內。目錄 scenario 的 Example 補上「與該目錄是否為空無關」。`tasks.md` task 1.18 的 scenario 引用同步為同時列出兩個 scenario 名（既有測試 `testUnlinkRefusesDirectoryAndDoesNotFollowSymlink` 已同時驗收兩者，未新增測試）。spec 的 scenario 數因此由 14 增為 15。

**N5 — 修復**（非 blocking，一併處理）。在 design 決策 9 的「非 root 下對任何目錄都以 `EPERM` 失敗」之後補一句：`man 2 unlink` 的 ERRORS 對 super-user 留有例外，但 Tubify 是使用者身分執行的 GUI app、不以 root 執行，因此 spec 得以無條件形式陳述該保證。spec 維持無條件寫法。

**驗證**：修復涉及 `specs/download-reliability/spec.md`、`design.md`、`tasks.md` 三個 artifact 與 `Tubify/Services/YTDLPService.swift` 的註解。已執行 `cash validate cleanup-orphaned-part-files`，結果為 `Validation passed.`；mechanical self-check 確認 15 個 scenario 全數被 tasks 覆蓋、每個 scenario 本體各只有一個 WHEN、「不遞迴」措辭在 spec／design／proposal 三份文件均無殘留。已執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，結果為 **310 tests, 0 failures**。

**Change 目錄外檔案修改**：本輪 Fix Actions 修改了 `Tubify/Services/YTDLPService.swift`（僅註解），已以 `touched record` 記錄。

## Decision

next_round

cumulative blocking set 中有 1 個 Warning（N1）已完成修復但尚未經 reviewer 驗證。本輪為本 run 的第二輪，下一輪位置為第三輪，非第四輪，因此下一輪為 `micro` round，由 Reviewer V 對 N1 給出 resolved/unresolved verdict 並檢查本輪修復是否引入新缺陷。
