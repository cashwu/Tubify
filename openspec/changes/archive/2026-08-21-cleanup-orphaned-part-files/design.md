## Context

`YTDLPService.executeDownloadFlow` 為了處理 video-data 403 與登入類錯誤，會在同一次 `download` 呼叫內啟動多個獨立的 yt-dlp process：

- `executeWithTransient403Retries` 對同一 processed template 最多執行 initial attempt 加 3 次 retry
- 首段失敗且 `shouldRetryWithCookies` 成立時，改以 Safari cookies template 再跑一整組 attempts

每個 attempt 都是全新的 yt-dlp process，會重新解析格式與媒體 URL。yt-dlp 只在自己 process 內清理它寫過的中間檔，前一個 process 留下的 partial 檔完全不在它的視野內。當兩個 attempt 選中不同格式（實測：不帶 cookies 選中 f401 連續下載，帶 cookies 改走 46 fragment 分段串流），前一個 attempt 的 partial 檔既不會被續傳也不會被刪除。

`executeDownloadFlow` 目前有三個成功 return 點，沒有共同的成功收尾位置。

清理的難點在於下載目錄是共用的：`DownloadManager` 支援 1 至 5 個並行下載，全部寫入同一個資料夾，預設為 `~/Downloads`，而該資料夾同時也是瀏覽器等第三方工具的下載目的地。刪除條件必須窄到足以排除這些檔案。

`TubifyTests/YTDLPServiceTests.swift` 已具備 `makeYTDLPFixture` 基礎設施：以可控 shell script 扮演 yt-dlp、由真實 `Process` 執行、驅動真實的 `YTDLPService.download`，並可依 invocation 次數決定該次 attempt 成功或回傳 403。本變更的驗證以此基礎設施為主。

## Goals / Non-Goals

Goals：

- 在整體下載成功後，清除同一次 `download` 呼叫中由較早失敗 attempt 留下的孤兒中間檔
- 清理範圍精確界定在本次呼叫期間新增、且符合 yt-dlp 中間檔命名形態的檔案
- 清理不得改變下載結果：任何清理失敗只記錄日誌
- 在共用下載目錄下，寧可漏刪也不可誤刪其他任務或其他應用程式的檔案

Non-Goals：

- 不在下載最終失敗時刪除任何檔案
- 不改動 403 retry 次數、backoff 秒數與 cookies fallback 觸發條件
- 不提供全域下載目錄清理功能
- 不改動 yt-dlp 指令模板
- 不新增 cookies 轉換或 `PermissionService` 的注入 seam

## Decisions

### 決策 1：清理點放在 `executeDownloadFlow` 的單一成功出口

`executeDownloadFlow` 現有三個 return 點（首段成功、無 cookies 可用時的原 template 重試成功、cookies template 成功）。將三者收斂為單一成功出口，並在該出口執行清理。

理由：

- 這是「整體下載成功」的唯一語意位置。放在 `executeDownload` 內會在每個 attempt 後執行，可能刪掉當前 attempt 正在使用的續傳檔
- `download` 的所有 production 呼叫都必經此處，單一出口讓三條成功路徑共用同一段收尾程式碼

### 決策 2：候選檔案必須同時符合檔名主幹與 yt-dlp 中間檔形態

設最終輸出路徑為 `<dir>/<stem>.<ext>`。候選檔案取 `<dir>` 的直接內容（不遞迴），檔名必須以 `<stem>.` 開頭，且**去掉該前綴後的剩餘部分整體**符合下列形態：

```
^(f[0-9]+\.)?[A-Za-z0-9]{1,5}\.(part|ytdl|part-Frag[0-9]+)$
```

單純以 `<stem>.` 為前綴並不足夠。標題含有點時，前綴比對會誤中其他影片：最終檔為 `Lecture 1.mp4`（stem 為 `Lecture 1`）時，另一個任務的 `Lecture 1.5.f401.mp4.part` 同樣以 `Lecture 1.` 開頭。加上形態比對後，其剩餘部分 `5.f401.mp4.part` 不符合上式而被排除。

`.ytdl` 是 yt-dlp 的續傳中繼資料檔，與 `.part` 成對產生；只刪 `.part` 會留下另一個孤兒。字幕檔（`<stem>.zh-TW.srt` 的剩餘部分為 `zh-TW.srt`）與最終影片檔皆不符合上式，天然被排除。

形態比對只看名稱，不保證項目是檔案。候選項目另須是一般檔案，以免對名稱碰巧符合上式的目錄或 symbolic link 執行刪除。實測確認 `URLResourceKey.isRegularFileKey` 對一般檔案為 true，對目錄、symbolic link（含 dangling symlink、指向檔案或目錄的 symlink）與 FIFO 皆為 false。無法判定型別時視為不符合條件，保留該項目。

`isRegularFileKey` 對 hardlink 回傳 true，與一般檔案無法區分。名稱碰巧符合全部條件的 hardlink 若被 `unlink` 成功刪除，會失去該連結名稱本身，內容仍由其他名稱保留，殘餘風險記於 Risks。

型別檢查是**提早排除**的手段，不是最終保證：檢查與刪除之間存在 TOCTOU 窗口。「對任何目錄一律失敗」這個絕對保證由決策 9 的刪除原語承擔。

最終輸出檔自身不需要獨立的排除條件。其檔名去掉 `<stem>.` 前綴後恰為單一副檔名而不含點，而上式每個分支都要求剩餘部分至少含一個點，因此最終輸出檔在任何形狀下都不可能通過形態比對（實測涵蓋 `video.mp4`、`a.b.mp4`、`video.part`、`video.mp4.part`、`clip.f401.mp4.part`、`x.ytdl`、無副檔名七種形狀，全部不通過）。實作仍保留一道 `path != finalPath` 的比對作為 defence-in-depth，但它在現行形態條件下恆為真、不會攔下任何項目，因此**不列為 spec 的獨立條件**——把一個永遠不生效的檢查寫成規範性的 MUST，正是 `openspec/signals/unreachable-guard-or-dead-test.md` 記錄的缺陷。

### 決策 3：只刪除本次呼叫期間才出現的檔案

`executeDownloadFlow` 在啟動第一個 attempt 前，先對輸出目錄的直接內容取一次檔名快照。清理時，已存在於快照中的檔案一律不刪除。

理由：孤兒中間檔必然是本次呼叫的某個 attempt 產生的，一定不在快照中。快照條件排除了下載開始前就存在的第三方 partial 檔——例如 Firefox 進行中或暫停中的下載就命名為 `<檔名>.part`，當本次最終檔為 `Report.mp4` 而該檔為 `Report.mp4.part` 時，決策 2 的形態比對無法區分兩者（yt-dlp 單格式下載的中間檔形態完全相同），只有快照能擋下。

快照取得失敗時，視為「無法證明候選檔是本次產生」，該次清理直接放棄。

### 決策 4：以 mtime 早於最終輸出檔作為額外保護

候選檔案的 content modification date 必須早於最終輸出檔的 content modification date 才會被刪除。這道保護針對的是「另一個並行任務在本次呼叫期間才開始寫入」而躲過快照的情形：正在寫入的檔案 mtime 接近當下，不早於最終檔。

代價是在時間戳解析度較低的 volume 上（exFAT 為 2 秒，SMB/NFS 掛載視伺服器而定），相隔數百毫秒的兩個檔案 mtime 會完全相同，清理在這些 volume 上將常態性不生效。這是刻意選擇的失敗方向：漏刪只是留下一個檔案，誤刪則不可逆。

### 決策 5：列舉目錄由最終輸出路徑推導，與輸出目錄不符時不清理

列舉的目錄取自 `finalPath` 的 parent，而非傳入的 `outputDirectory`，避免 stem 與列舉範圍來自不同來源。若兩者不相同（使用者自帶 `-o`），清理直接放棄。

這道條件**不涵蓋** `executeDownload` 的 60 秒最近媒體檔 fallback。該 fallback 只列舉 `outputDirectory` 本身，因此它回傳的路徑其 parent 恆等於 `outputDirectory`，永遠通過本條件的相等性檢查。在並行下載共用同一目錄時，該 heuristic 可能回傳另一個任務剛完成的影片，此時清理會拿別的任務的 stem 去掃描共用目錄——這個風險完全由決策 2 的形態比對、決策 3 的快照與決策 4 的 mtime 三者承擔，本決策對它沒有貢獻，殘餘風險記於 Risks。

### 決策 6：區分致命與非致命的清理失敗

- **致命（放棄整輪清理）**：快照取得失敗、最終輸出路徑的父目錄與輸出目錄不符、最終輸出檔不存在或無法讀取其 content modification date、目錄列舉失敗。四者都使判斷前提不成立，記錄一筆 warning 後直接返回，不刪除任何檔案，並各自對應決策 10 的一個 `AbandonReason`。
- **非致命（記錄後繼續下一個候選檔）**：單一候選檔的屬性讀取失敗、單一候選檔刪除失敗。

清理函式不拋出錯誤，也不改變回傳的 output path。

候選檔的型別與 mtime 來自同一次 `getattrlist`：讀不到 mtime 的項目，其 `isRegularFileKey` 必然也讀不到。若把「型別讀取失敗跳過」與「mtime 讀取失敗記錄後繼續」拆成兩條分支，排在前面的型別檢查會完全遮蔽後者，使它成為原理上不可達的死分支——正是 `openspec/signals/unreachable-guard-or-dead-test.md` 記錄的缺陷類別。

因此候選檔的兩個屬性 SHALL 以單次 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])` 一併讀取，讀取失敗收斂為單一非致命分支。該分支有穩定注入手段：對候選檔設定 ACL `deny readattr` 後，它仍出現在目錄列舉結果中，但屬性讀取以 `NSCocoaErrorDomain` 257 整批失敗，可由測試驅動。

四個致命失敗全部可注入並由測試驅動：快照取得失敗、父目錄不符、目錄列舉失敗，以及最終輸出檔不可用。最後一項的兩個觸發條件中，「無法讀取 content modification date」沒有獨立的注入手段——實測對最終輸出檔設定 ACL `deny readattr` 會使 `FileManager.fileExists` 與 `resourceValues` 同時以 257 失敗——但兩個觸發條件共用同一段處置，由「最終輸出檔不存在」的測試覆蓋該處置即可，不需要另外的 code review 豁免。

「最終輸出檔不存在即放棄」同時是既有 `executeDownloadFlow` seam 測試的安全保證：那些測試傳入的 `outputDirectory` 與 output path 並不存在於檔案系統，清理必須對它們完全無副作用。

### 決策 7：不新增 operation identity 檢查

清理不呼叫 `isCancelled`。`executeWithTransient403Retries` 在每個成功 attempt 之後、`return outputPath` 之前已經做過同一個檢查，stale 或已取消的 operation 會在該處拋出 `YTDLPError.cancelled`，根本到不了清理點。在清理內重複一次條件更弱的檢查（`cancellationProbe: nil`）恆為 false，既無法生效也無法被測試驅動。

stale operation 因此不會執行清理，這個性質由既有檢查承擔，不需要新的機制，也不在本變更的 spec 中重述。

### 決策 8：驗證以 production fixture 為主

清理行為的主要測試透過 `makeYTDLPFixture` 擴充：fixture script 在第一次 invocation 建立候選檔並以 video-data 403 失敗，第二次 invocation 建立最終輸出檔並印出 `FINAL_PATH:`。測試呼叫真實的 `YTDLPService.download`，再以 `FileManager.default.fileExists(atPath:)` 斷言檔案存否。

fixture 使用**不含** `--cookies-from-browser safari` 的 command template。`download` 硬編碼 `SafariCookiesService.shared`，其 `transformCommand` 依賴 `PermissionService.hasFullDiskAccess()` 與真實的 Safari binarycookies，沒有注入點；有無完整磁碟存取權限的機器會走進不同分支。不帶 cookies 的 template 使 `cookieTemplateProvider` 為 nil，走確定性的 backoff retry 路徑，同樣涵蓋「多個 attempt、後一個成功」這個清理所需的前提。

因此本變更的測試證明的是 production `download` 的**多 attempt 成功路徑**走到清理程式碼，不宣稱涵蓋 cookies fallback 分支。

fixture script 以 `touch -t` 明確設定候選檔與最終輸出檔的 mtime，不依賴兩次 invocation 的自然寫入時序，避免測試在低時間戳解析度的 `TMPDIR` 上 flaky。

不帶 cookies 的 template 使 `allowTransient403Retries` 為 true，因此「多 attempt 成功」case 在第一次 403 之後會實際 `Task.sleep` 2 秒才啟動第二次 invocation，而 `download` 沒有 `sleeper` 注入點。每個使用該 case 的測試固定付出 2 秒，這是 `download` 缺少 sleeper seam 的既有限制，本變更不為此新增注入點。

### 決策 9：以 `unlink` 執行刪除，由 kernel 保證不刪目錄

刪除 SHALL 使用 POSIX `Darwin.unlink(path)`，MUST NOT 使用 `FileManager.removeItem(atPath:)`。

`removeItem` 對目錄是遞迴刪除，決策 2 的型別檢查只能縮短 TOCTOU 窗口而無法消除它——路徑若在屬性讀取後被替換成目錄，`removeItem` 仍會連同其中的使用者資料一併刪除。spec 對目錄的絕對保證（「即使在條件 5 通過之後才被替換成目錄，刪除仍 MUST 失敗」）因此無法由檢查本身承擔，必須由刪除原語提供。

`unlink` 把保證下推到 kernel：實測對目錄以 `EPERM` 失敗且目錄完好，對一般檔案成功。無論檢查與刪除之間發生什麼替換，目錄都不可能被刪除。

`unlink` 不 follow symbolic link：實測對指向目錄的 symlink 只刪除連結本身，target 內容完好。因此型別檢查後被替換為 symlink 的殘餘窗口，最壞後果是刪掉一個連結名稱，不會波及其指向的內容。這個殘餘窗口記於 Risks。

`unlink` 回傳 -1 時視為單一候選檔刪除失敗，走決策 6 的非致命分支。

`unlink` 對目錄的失敗與是否為空無關：非 root 下對任何目錄都以 `EPERM` 失敗。`man 2 unlink` 的 ERRORS 對 super-user 留有例外，但 Tubify 是使用者身分執行的 GUI app、不以 root 執行，因此 spec 得以無條件形式陳述該保證。這點必須是刪除原語的性質而非「不遞迴」——`rmdir` 與 libc `remove(3)`（對目錄轉呼叫 `rmdir`）同樣不遞迴，卻會成功刪除空目錄。

**TOCTOU 窗口為何無法消除**（實測環境：macOS 26.5.2 / Darwin 25.5、APFS、非 root）：關鍵在於 macOS 沒有「把受檢項目綁定成 inode identity、再以該 identity 為條件刪除」的原語。

`funlinkat`（FreeBSD 提供的「僅當 fd 與 path 指向同一 inode 時才 unlink」原語）在 macOS SDK 未宣告、dyld cache 查無符號，`sys/syscall.h` 中檔案系統的 unlink 系列 syscall 只有 `SYS_unlink` 與 `SYS_unlinkat`，沒有 fd 版本。

`man 2 unlinkat` 列出五個 flag，逐一檢視都不構成 identity 綁定：

| flag | 條件 | 為何不適用 |
|---|---|---|
| `AT_REMOVEDIR` | 切換為 `rmdir` 語意 | 與 identity 無關，且會使目錄變成可刪 |
| `AT_SYMLINK_NOFOLLOW_ANY` | 路徑解析不跟隨 symlink | 只作用於**中間**元件。實測對最終元件是 symlink 的相對路徑回傳 0 並刪除該連結；把同一 symlink 放在中間元件才以 `ELOOP` 失敗 |
| `AT_RESOLVE_BENEATH` | 路徑不得逃出起始目錄 | 同樣只約束路徑解析。實測以相對路徑或 dirfd 呼叫時對最終元件 symlink 回傳 0 並刪除；絕對路徑搭配 `AT_FDCWD` 則以 `ENOTCAPABLE` 失敗，不是保護效果 |
| `AT_NODELETEBUSY` | 路徑上有開啟中的 fd 即失敗 | 條件極性相反，與「先 `open` 綁定再刪」互斥——實測持有開啟 fd 時以 `EBUSY` 失敗 |
| `AT_UNIQUE` | 解析到的 vnode link count > 1 即失敗 | 條件是 link count 而非 identity。實測對 2 個 hardlink 的檔案以 `ENOTCAPABLE` 失敗、單一 link 則回傳 0 |

`open(O_NOFOLLOW)` 能把項目綁到 fd 來*檢查*（實測對 symlink 以 `ELOOP` 失敗），但上表沒有任何 flag 能以該 fd 為條件執行刪除，fd 綁定因此無法消除這個窗口。

唯一可行的方向是 rename-then-verify（`rename` 不跟隨最終元件的 symlink，可先搬進私有目錄、`lstat` 驗型別、不符再搬回），但那是一套新的刪除機制與新的失敗模式，本變更不採用。

### 決策 10：以 cleanup outcome observer 提供可驗收的失敗觀察

`executeDownloadFlow` 新增一個選用的 observer 參數，清理結束時以本次結果呼叫它；production 呼叫傳 nil。

理由：spec 要求每個致命與非致命失敗都留下日誌，但這些失敗在現有基礎設施下無法被測試觀察——`TubifyLogger` 是 `os.Logger`，`LogFileManager` 是 `private init()` 的 singleton 且寫入真實的 `~/Library/Logs/Tubify/`。沒有 observer 時，「放棄整輪清理」這個事件本身無法被斷言，致命失敗的測試只能斷言「沒有檔案被刪除」——而列舉失敗必然導致取不到候選檔清單，該斷言在 guard 存在與否時都成立，是不具鑑別力的假綠燈。

observer 沿用 `attemptExecutor`、`sleeper`、`cancellationProbe` 的既有注入慣例，不改變 production 行為。

## Implementation Contract

`Tubify/Services/YTDLPService.swift`：

1. 新增 private method：

   ```
   private func directoryEntryNames(_ directory: String) -> Set<String>?
   ```

   以 `FileManager.default.contentsOfDirectory(atPath:)` 回傳目錄的直接內容檔名集合；失敗時回傳 nil。

2. 新增 private method：

   ```
   private func cleanupOrphanedPartFiles(
       finalPath: String,
       outputDirectory: String,
       preexistingEntryNames: Set<String>?,
       taskId: UUID,
       observer: ((CleanupOutcome) -> Void)?
   )
   ```

   依序：

   - `preexistingEntryNames` 為 nil 時記錄 warning 並 return（決策 6 致命）
   - `finalPath` 的 parent 與 `outputDirectory` 標準化後不相同時記錄 warning 並 return（決策 5）
   - `finalPath` 不存在或無法讀取其 content modification date 時記錄 warning 並 return（決策 6 致命）
   - 以 `FileManager.default.contentsOfDirectory(atPath:)` 列舉該 parent 目錄，失敗時記錄 warning 並 return（決策 6 致命）
   - 對每個項目依序套用：不在 `preexistingEntryNames` 中、檔名以 `<stem>.` 開頭、剩餘部分符合決策 2 的形態、路徑不等於 `finalPath`（defence-in-depth，見決策 2）；名稱層面全部成立後，對該項目**新建**一個 `URL(fileURLWithPath:)` 並以單次 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])` 讀取屬性，要求 `isRegularFile` 為 true 且 mtime 早於最終輸出檔；全部成立才以 `Darwin.unlink(path)` 刪除（決策 9）。MUST NOT 使用 `FileManager.removeItem(atPath:)`
   - 被名稱層條件、型別檢查或 mtime 條件過濾掉的項目既不列入 `deleted` 也不列入 `failed`：它們不是處理失敗，而是不符合候選資格
   - `unlink` 回傳 -1 時視為該候選檔刪除失敗，記錄 warning 後繼續下一個候選檔（決策 6 非致命）。對目錄的 `EPERM` 失敗即為此路徑，型別檢查後被替換為目錄的項目因此不可能被刪除
   - 屬性 MUST NOT 取自 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取快取。預取的 URL 會回傳列舉當下的值，使 mtime 與型別判定和 `unlink` 之間的窗口從微秒級擴大到整個列舉迴圈。「對任何目錄一律失敗」已由決策 9 的 `unlink` 承擔，此處要守的是 mtime 判定的時效性與 symbolic link 替換窗口
   - 單一候選檔的屬性讀取失敗或刪除失敗記錄 warning 後繼續下一個候選檔（決策 6 非致命）
   - 每次成功刪除記錄一筆 info 日誌，內含 task ID 與被刪除的檔名
   - 不拋出任何錯誤
   - 每個 return 路徑（含正常結束）MUST 以本次結果呼叫 `observer` 恰好一次（決策 10）

3. 新增 internal 型別描述清理結果，供決策 10 的 observer 使用：

   ```
   enum CleanupOutcome: Equatable {
       enum AbandonReason: Equatable {
           case snapshotUnavailable
           case outputDirectoryMismatch
           case finalPathUnavailable
           case directoryEnumerationFailed
       }
       case abandoned(AbandonReason)
       case completed(deleted: [String], failed: [String])
   }
   ```

   `deleted` 為成功刪除的檔名，`failed` 為屬性讀取失敗或 `unlink` 失敗而跳過的候選檔名，兩者皆為檔名而非完整路徑。被名稱層條件、型別檢查或 mtime 條件過濾掉的項目兩者皆不列入。

   兩個陣列在呼叫 observer 之前 SHALL 以檔名遞增排序。`contentsOfDirectory(atPath:)` 的回傳順序在 APFS 上既非建立順序也非字典序（實測：依 f407→f400 建立 8 個檔案，列舉回傳 `f401, f400, f406, f407, …`），型別又是 `Equatable`，不排序會讓任何含兩個以上元素的相等性斷言在 CI 上間歇失敗。

4. `executeDownloadFlow` 在第一個 attempt 之前呼叫 `directoryEntryNames(outputDirectory)` 取得快照，並將三個現有 return 點收斂為單一成功出口；該出口呼叫 `cleanupOrphanedPartFiles`，再回傳 output path。`executeDownloadFlow` 新增選用參數 `cleanupObserver: ((CleanupOutcome) -> Void)? = nil` 並原樣傳入；`download` 不傳該參數。

5. 不修改 `executeWithTransient403Retries`、`executeDownload`、`download` 的簽名與既有錯誤路徑，也不新增 `isCancelled` 呼叫。

`TubifyTests/YTDLPServiceTests.swift`：

6. 擴充 `YTDLPFixture` 與 `makeYTDLPFixture` 的 script，加入兩個新 case，既有 case 分支與既有欄位語意不得改變：

   - **多 attempt 成功 case**：第一次 invocation 依設定建立候選檔、名稱符合形態的目錄（內含一個檔案）與名稱符合形態的 symbolic link，並設定其 mtime，然後以 `ERROR: unable to download video data: HTTP Error 403: Forbidden` 失敗；第二次 invocation 建立最終輸出檔（mtime 明確晚於前述項目）並印出 `FINAL_PATH:`

     「多 attempt 成功」case 另 MUST 能依設定建立任意檔名的干擾檔，涵蓋其他主幹（`<other-stem>.f401.mp4.part`）與含點主幹（`Lecture 1.5.f401.mp4.part`）兩種形態。

     所有干擾用項目 MUST 由 fixture 在 invocation 期間建立，不得由測試在呼叫 `download` 之前建立——否則它們會落入決策 3 的目錄快照，被條件 2 提前排除而保留，測試雖然全綠卻完全不會走到後續條件。這對每一個「保留」類測試都成立：條件 5 的型別檢查、決策 2 的前綴與形態比對，都只有在項目未被條件 2 攔下時才會執行，而後者正是本變更「寧可漏刪也不可誤刪」的核心防護。

     mtime 設定方式：一般檔案與目錄用 `touch -t`，symbolic link MUST 用 `touch -h -t`。實測在 macOS 上，不帶 `-h` 的 `touch` 會 follow symlink——對指向既有檔案的 symlink 設到的是 target 的 mtime，對 dangling symlink 甚至會憑空建立 target 檔案。目錄的 `touch -t` MUST 在建立其內層檔案之後執行，否則內層檔案的建立會覆寫目錄的 mtime。
   - **單次失敗 case**：建立候選檔後，以同時含有 `Giving up after` 與 video-data 403 片段的訊息失敗。`isRetryableDownload403` 對此回傳 false，`download` 單次 attempt 即結束，不套用 2/5/10 秒 backoff

7. production fixture 測試覆蓋：多 attempt 成功後刪除前一 attempt 的 `.fNNN.<ext>.part`、同時刪除對應 `.ytdl` 與 `.part-Frag<N>`、保留字幕檔與最終影片檔、保留檔名主幹不同的其他影片中間檔、保留主幹為前綴且含點的其他影片中間檔、保留名稱符合形態的目錄與其中的檔案、保留名稱符合形態的 symbolic link、保留下載開始前就已存在的同名 `.part`、保留 mtime 不早於最終檔的候選檔、整體失敗時不刪除任何檔案。

8. `attemptExecutor` seam 測試覆蓋：最終輸出路徑的父目錄與 `outputDirectory` 不同時不清理；最終輸出檔不存在時放棄整輪清理並回傳原本的最終輸出路徑；快照取得失敗時放棄整輪清理；目錄列舉失敗時放棄整輪清理；單一候選檔屬性讀取失敗時仍處理其餘候選檔並回傳原本的最終輸出路徑；單一候選檔刪除失敗時仍處理其餘候選檔並回傳原本的最終輸出路徑；既有 seam 測試不得產生任何檔案系統副作用。

   快照取得失敗的注入方式 SHALL 為讓 `outputDirectory` 在取得快照時尚不存在，並由 `attemptExecutor` 在執行期間才建立該目錄與其中的檔案。目錄列舉失敗的注入方式 SHALL 為在 `attemptExecutor` 回傳前把該目錄的 POSIX 權限設為 `0o333`（可寫、可搜尋、不可讀），使 `fileExists` 與最終輸出檔的 mtime 讀取仍成功、`contentsOfDirectory` 以 `NSCocoaErrorDomain` 257 失敗，而 `unlink` 仍可成功。MUST NOT 使用 `0o111`：該權限同時使 `unlink` 失敗，測試無法區辨「清理放棄了」與「清理想刪但刪不掉」。候選檔屬性讀取失敗的注入方式 SHALL 為對該候選檔設定 ACL `deny readattr`，使其仍出現在目錄列舉結果中而屬性讀取以 `NSCocoaErrorDomain` 257 失敗。

   每個致命失敗測試 MUST 斷言 `cleanupObserver` 收到對應的 `CleanupOutcome.abandoned` reason。這是唯一具鑑別力的斷言：列舉失敗必然使清理取不到候選檔清單，「沒有檔案被刪除」在 guard 存在與否時都成立。每個致命失敗測試另 MUST 在輸出目錄中放置至少一個滿足其餘全部條件的候選檔並斷言其仍存在，作為輔助斷言。1.16 的候選檔 MUST 由 `attemptExecutor` 在改動權限之前建立。

   非致命失敗測試 MUST 斷言 `cleanupObserver` 收到的 `CleanupOutcome.completed` 中，失敗的候選檔名出現在 `failed`、其餘候選檔名出現在 `deleted`。成功路徑測試 SHOULD 斷言 `deleted` 的內容。`observer` 斷言證明的是「該 return 路徑被走到」，不證明該路徑寫了日誌。spec 對「每個致命與非致命失敗都留下日誌」的驗收由 Verification 的 code review task 承擔，涵蓋四個致命 return 與兩個非致命 continue 分支。

   所有改動檔案系統狀態的注入（`chflags uchg`、`0o333`、ACL）MUST 以 `defer` 或 `addTeardownBlock` 註冊還原動作。這些測試是 `async throws`，中途任何 `try` 拋出都會跳過尾端的還原敘述，而 `makeYTDLPFixture` 不會刪除自己的暫存目錄——未還原的 `uchg` 檔與 `0o333` 目錄都會擋下遞迴刪除，在 CI 上留下無法回收的殘留。

   單一候選檔刪除失敗的注入方式 SHALL 為對該候選檔設定 immutable flag（`chflags uchg`），並在測試結束前以 `nouchg` 還原。不得以 `chmod` 降低該檔案本身的權限：在 macOS 上 unlink 取決於父目錄的寫入權限，唯讀檔案仍會被 `unlink` 成功刪除，該注入不會進入非致命失敗分支。也不得將整個目錄設為唯讀，那會使所有刪除都失敗而破壞「其餘候選檔仍被刪除」的斷言。

9. 刪除原語測試覆蓋：對含有檔案的目錄呼叫 `Darwin.unlink` 時回傳 -1、`errno` 為 `EPERM`、該目錄與其中的檔案保持完整；對**空目錄**呼叫時同樣回傳 -1、`errno` 為 `EPERM`、該目錄仍存在；對指向目錄的 symbolic link 呼叫時回傳 0、連結消失而 target 內容完整。

   空目錄的斷言不可省略：spec 的保證是「與該目錄是否為空無關」，而空目錄正是區分 `unlink` 與 `rmdir`／`remove(3)` 的關鍵反例——後兩者同樣不遞迴，卻會成功刪除空目錄。

   這個測試**不經過候選條件序列**，直接驗證決策 9 所依賴的刪除原語性質。它必須獨立於 seam 測試存在：目錄的 `isRegularFile` 為 false，任何走完整清理流程的測試都會在型別檢查就把目錄濾掉，`unlink` 根本不會被呼叫，因此無法驗證「刪除操作本身拒絕目錄」。走完整流程的近似寫法還會落入另一個陷阱——被型別檢查濾掉的項目既不在 `deleted` 也不在 `failed`，任何斷言它出現在 `failed` 的測試都是恆紅的。


## Risks / Trade-offs

- **同名第三方下載在本次呼叫期間開始**：使用者在本次下載進行中，於同一目錄用其他工具開始下載同名檔案（例如 Firefox 的 `Report.mp4.part`，而本次最終檔為 `Report.mp4`），該檔可能同時躲過決策 3 的快照並符合決策 2 的形態。決策 4 的 mtime 保護在該下載停滯時亦可能失效。此情境需要檔名與時序同時巧合，接受此殘餘風險。
- **fallback 取錯 stem**：`executeDownload` 在 `--print` 與行解析都失敗時，會退回掃描輸出目錄中 60 秒內修改過的媒體檔並取最新一個。並行下載共用同一目錄時，該 heuristic 可能回傳另一個任務剛完成的影片，清理因而以錯誤的 stem 掃描共用目錄。決策 5 對此無約束力，緩解僅來自決策 2、決策 3 與決策 4：被誤取的 stem 只能命中本次呼叫期間新增、符合中間檔形態且 mtime 更早的檔案。
- **型別檢查後的路徑替換**：決策 9 的 `unlink` 保證目錄絕不會被刪除，但可能刪除任何非目錄項目的名稱；若 `unlink` 失敗，則依決策 6 的單一候選檔非致命失敗規則處理。若某個候選檔在屬性讀取通過後、`unlink` 之前被替換成 symbolic link 且刪除成功，該連結名稱會消失（實測 `unlink` 不 follow symlink，其指向的內容完好）；被替換成 FIFO、socket 等其他非一般檔案且刪除成功時同樣只失去該名稱；最壞的情形是被替換成另一個真實的一般檔案且刪除成功——那會連同該檔內容一併失去。此窗口為微秒級且需要外部行為者精確地在該時點替換，且如決策 9 所述無法以現有系統呼叫消除，接受此殘餘風險。
- **名稱符合形態的 hardlink**：`isRegularFileKey` 對 hardlink 回傳 true，型別檢查無法排除。名稱與屬性滿足 Contract 第 2 點候選條件序列的 hardlink 若被 `unlink` 成功刪除，會失去該連結名稱本身；因為 hardlink 蘊含至少兩個名稱，內容仍由其他名稱保留，只有在使用者已刪掉其他所有名稱時才會真的失去資料。接受此殘餘風險，不新增條件。
- **同標題並行下載**：兩個任務同時下載標題完全相同的影片時，兩個 yt-dlp process 本來就會寫入同一個 partial 檔，在本變更之前即為衝突狀態。本變更不使其惡化，也不承諾解決。
- **低時間戳解析度的 volume**：決策 4 使清理在 exFAT 或部分網路磁碟上常態性不生效。屬於可接受的保守失敗。
- **無 `.part` 後綴的完整中間檔**：403 若發生在音訊階段，前一個 attempt 可能已寫完視訊而留下沒有 `.part` 後綴的 `<stem>.f401.mp4`。它不符合決策 2 的形態，本變更不清理，理由記於 proposal Non-Goals。
- **擴充共用 fixture**：決策 8 修改 `makeYTDLPFixture` 這個被多個既有測試共用的 helper，有影響既有測試的風險。緩解方式是只新增 case 分支與新欄位，不改動既有分支與既有欄位語意。
