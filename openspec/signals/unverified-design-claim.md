---
id: unverified-design-claim
type: recurring-finding
status: open
occurrences: 6
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r1.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r2.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/propose-r4.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r3.md
  - openspec/changes/cleanup-orphaned-part-files/reviews/apply-r4.md
  - openspec/changes/cookieless-subtitle-detection/reviews/propose-r1.md
  - openspec/changes/cookieless-subtitle-detection/reviews/propose-r2.md
  - openspec/changes/cookieless-subtitle-detection/reviews/apply-r1.md
---

# design 對某機制效力的宣稱未經程式碼驗證

`design.md` 宣稱「某測試能證明某分支被覆蓋」或「某條件能擋下某風險」時，若未對照實際程式碼驗證，宣稱可能完全不成立，而下游會據此認為該風險已被處理。每個此類宣稱 SHALL 引用具體的程式碼位置，並確認該位置的行為真的支撐宣稱；無法支撐時 SHALL 縮小宣稱範圍並把殘餘風險寫進 Risks。

## Occurrences

- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 1（Reviewer A，confidence 85，Warning）：design 宣稱 production fixture 可證明「cookies fallback 分支確實走到清理程式碼」，但 `download` 硬編碼 `SafariCookiesService.shared`（`Tubify/Services/YTDLPService.swift:245`、`:249`、`:256`），`transformCommand` 依賴 `PermissionService.hasFullDiskAccess()` 與真實 Safari binarycookies，無注入 seam，有無權限的機器會走進不同分支。已把宣稱範圍限縮為「多 attempt 成功路徑」，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 2（Reviewer V，confidence 85，Warning，disposition fix-introduced）：design 決策宣稱目錄相等性檢查可擋下「`executeDownload` 的 60 秒最近媒體檔 fallback 找到別處的檔案」，但該 fallback 只列舉 `outputDirectory` 本身（`:849`），回傳路徑的 parent 恆等於 `outputDirectory`，相等性檢查永遠通過，該決策對此風險貢獻為零。已刪去錯誤宣稱並新增 Risks 條目，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-propose round 4（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning，disposition fix-introduced）：design 以「列舉後才刪除的候選檔仍會讀到 URL 的快取值」論證某分支不可測，但該行為只在 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取 URL 下成立；Contract 未指定清理階段的列舉 API，改用 `contentsOfDirectory(atPath:)` 加新建 URL 時該讀取會以 `NSCocoaErrorDomain` 260 真實失敗。已明確指定列舉 API 並禁止取用預取快取，verdict 為 resolved。
- 2026-08-21 — `cleanup-orphaned-part-files` — cash-apply round 3 與 round 4（Reviewer B confidence 90、Reviewer V confidence 85，皆 Warning）：修正 spec 的 symbolic link 矛盾時，先寫了「要消除此 TOCTOU 窗口需以 file descriptor 綁定受檢項目」——實測 `funlinkat` 在 macOS 不存在、`unlinkat` 的 nofollow flag 只作用於中間路徑元件，該機制根本不存在，等於把平台限制寫成了範圍取捨。改為平台事實並搬入 design 後，該份平台調查本身又寫錯：宣稱 `unlinkat` 只有三個 flag，實際有五個，遺漏的 `AT_NODELETEBUSY` 恰好字面反證了同段的全稱句。根因是直接沿用上一位 reviewer 給的列舉而未自行查證 man page。已改為表格列出全部五個 flag 並逐一說明為何都不構成 identity 綁定，由後續 reviewer 以窮盡性實測（其餘五個 `AT_*` 傳入 `unlinkat` 皆 `EINVAL`）確認完整，verdict 為 resolved。教訓：修正一個未驗證宣稱時，替代敘述同樣需要獨立查證，不可沿用他人未經自己驗證的清單。
- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 1（Reviewer A，confidence 100，Warning）與 round 2（Reviewer V，confidence 90，Warning，disposition fix-introduced）：同一個 issue class 在一次 run 內出現兩次。round 1 是 design 與 proposal 宣稱下載路徑的 cookies fallback 分類函式是 `indicatesLoginRequired(_:)`，實際 gate 是其嚴格超集 `shouldRetryWithCookies(_:)`（`Tubify/Services/YTDLPService.swift:336`、`:698-699`），漏掉 `isDownloadVideoData403` 這一半。round 2 更值得記：修正 round 1 時新寫的 Contract 條款宣稱「stderr 為空時分類輸入為既有的 `未知錯誤` fallback 字串」，但既有程式碼是 `String(data: errorData, encoding: .utf8) ?? "未知錯誤"`——空 `Data` 以 UTF-8 解碼回傳空字串而非 `nil`，fallback 根本不生效，照此寫成的測試會是一條對照既有實作必然失敗、卻標為「驗證既有行為」的測試。兩者 verdict 皆為 resolved。教訓與既有條目一致並再次應驗：新寫的事實敘述（尤其是描述「既有行為」的那種）同樣要逐字對照程式碼，`??` 這類 fallback 的觸發條件必須確認，不能從語意直覺推斷。

- 2026-08-21 — `cookieless-subtitle-detection` — cash-apply round 1（Reviewer A，confidence 85，Warning）：design Risks 宣稱把手動驗證的驗收點改為「實際產生對應語言的字幕檔」可「使這個失敗模式在驗證時可被看見」，但實際驗證回合證明該驗收點對該失敗模式毫無鑑別力：yt-dlp 先寫字幕、後抓 video data，cookieless 的第一次 invocation 在 `unable to download video data: HTTP Error 403: Forbidden` 之前就已把 `.zh.srt` 寫到磁碟（`~/Library/Logs/Tubify/tubify-2026-08-21.log`：15:26:41.472 字幕 `100% of 20.08KiB` → 15:26:41.518 403 → 15:26:41.573 帶 cookies 重試 → 15:26:44.164 `missing subtitles languages ... zh`），因此帶 cookies 的重試即使完全取不到該語言字幕，輸出目錄仍有字幕檔而使驗收通過——失敗模式確實發生了，驗收點卻放行。已改為據實敘明該驗收點無法觀察此失敗模式、其可觀察訊號是日誌中的 `missing subtitles languages` 警告，並把 tasks 4.7 驗收點二改寫為三項可歸因的判準（第一次執行命令不含 cookies 且含 `--write-sub` 與語言碼、該次 invocation 進度輸出顯示字幕下載完成、字幕檔 mtime 落在該次 invocation 期間以排除殘留檔），verdict 為 resolved。教訓：這是本 signal 首次出現在**手動驗證**的驗收點上而非測試上——宣稱某個驗收點「能讓某風險被看見」時，SHALL 先確認該驗收點觀察的產物不會由範圍外的其他機制同樣產生，否則它只能證明產物存在、無法歸因於哪一次嘗試。
