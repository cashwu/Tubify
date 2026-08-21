---
id: unverified-design-claim
type: recurring-finding
status: open
occurrences: 4
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r1.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r2.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r4.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r3.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r4.md
---

# design 對某機制效力的宣稱未經程式碼驗證

`design.md` 宣稱「某測試能證明某分支被覆蓋」或「某條件能擋下某風險」時，若未對照實際程式碼驗證，宣稱可能完全不成立，而下游會據此認為該風險已被處理。每個此類宣稱 SHALL 引用具體的程式碼位置，並確認該位置的行為真的支撐宣稱；無法支撐時 SHALL 縮小宣稱範圍並把殘餘風險寫進 Risks。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 85，Warning）：design 宣稱 production fixture 可證明「cookies fallback 分支確實走到清理程式碼」，但 `download` 硬編碼 `SafariCookiesService.shared`（`Tubify/Services/YTDLPService.swift:245`、`:249`、`:256`），`transformCommand` 依賴 `PermissionService.hasFullDiskAccess()` 與真實 Safari binarycookies，無注入 seam，有無權限的機器會走進不同分支。已把宣稱範圍限縮為「多 attempt 成功路徑」，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 2（Reviewer V，confidence 85，Warning，disposition fix-introduced）：design 決策宣稱目錄相等性檢查可擋下「`executeDownload` 的 60 秒最近媒體檔 fallback 找到別處的檔案」，但該 fallback 只列舉 `outputDirectory` 本身（`:849`），回傳路徑的 parent 恆等於 `outputDirectory`，相等性檢查永遠通過，該決策對此風險貢獻為零。已刪去錯誤宣稱並新增 Risks 條目，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition fix-introduced）：design 以「列舉後才刪除的候選檔仍會讀到 URL 的快取值」論證某分支不可測，但該行為只在 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取 URL 下成立；Contract 未指定清理階段的列舉 API，改用 `contentsOfDirectory(atPath:)` 加新建 URL 時該讀取會以 `NSCocoaErrorDomain` 260 真實失敗。已明確指定列舉 API 並禁止取用預取快取，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 3 與 round 4（Reviewer B confidence 90、Reviewer V confidence 85，皆 Warning）：修正 spec 的 symbolic link 矛盾時，先寫了「要消除此 TOCTOU 窗口需以 file descriptor 綁定受檢項目」——實測 `funlinkat` 在 macOS 不存在、`unlinkat` 的 nofollow flag 只作用於中間路徑元件，該機制根本不存在，等於把平台限制寫成了範圍取捨。改為平台事實並搬入 design 後，該份平台調查本身又寫錯：宣稱 `unlinkat` 只有三個 flag，實際有五個，遺漏的 `AT_NODELETEBUSY` 恰好字面反證了同段的全稱句。根因是直接沿用上一位 reviewer 給的列舉而未自行查證 man page。已改為表格列出全部五個 flag 並逐一說明為何都不構成 identity 綁定，由後續 reviewer 以窮盡性實測（其餘五個 `AT_*` 傳入 `unlinkat` 皆 `EINVAL`）確認完整，verdict 為 resolved。教訓：修正一個未驗證宣稱時，替代敘述同樣需要獨立查證，不可沿用他人未經自己驗證的清單。
