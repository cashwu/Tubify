## 1. Tests

- [x] 1.1 擴充 `TubifyTests/YTDLPServiceTests.swift` 的 `YTDLPFixture` 與 `makeYTDLPFixture`，依 design Implementation Contract 第 6 點加入「多 attempt 成功」與「單次失敗」兩個新 case。「多 attempt 成功」case MUST 能在 invocation 期間建立候選檔、名稱符合形態的目錄（內含一個檔案）與 symbolic link；mtime 以 `touch -t` 設定，symbolic link MUST 用 `touch -h -t`，目錄的 `touch -t` MUST 在建立內層檔案之後執行；執行既有 `YTDLPServiceTests` 全部測試確認既有 case 分支與既有欄位語意未變
- [x] 1.2 加入 production fixture 測試：較早 attempt 留下的 `<stem>.f401.mp4.part` 被刪除且下載回傳最終 `<stem>.mp4` 路徑（scenario「較早 attempt 留下的中間檔被刪除」），此時應失敗
- [x] 1.3 加入 production fixture 測試：`<stem>.f401.mp4.ytdl` 與 `<stem>.f251.webm.part-Frag12` 一併被刪除（scenario「同一主幹的續傳中繼檔與 fragment 暫存檔一併刪除」），此時應失敗
- [x] 1.4 加入 production fixture 測試：`<stem>.mp4` 與 `<stem>.zh-TW.srt` 在清理後仍存在（scenario「最終輸出檔與字幕檔保留」）
- [x] 1.5 加入 production fixture 測試：檔名主幹不同的 `<other-stem>.f401.mp4.part` 在清理後仍存在（scenario「其他影片的中間檔保留」）。該干擾檔 MUST 由 fixture 在 invocation 期間建立而非由測試在呼叫 `download` 之前建立，否則會落入目錄快照被條件 2 提前排除，決策 2 的前綴比對完全不會被執行
- [x] 1.6 加入 production fixture 測試：最終輸出檔為 `Lecture 1.mp4` 時，`Lecture 1.5.f401.mp4.part` 在清理後仍存在（scenario「主幹為前綴且含點的其他影片中間檔保留」）。該干擾檔 MUST 由 fixture 在 invocation 期間建立而非由測試在呼叫 `download` 之前建立，否則會落入目錄快照被條件 2 提前排除，決策 2 的形態比對完全不會被執行
- [x] 1.7 加入 production fixture 測試：第一個 attempt 啟動前就已存在的 `<stem>.mp4.part` 在清理後仍存在（scenario「下載開始前就已存在的中間檔保留」）
- [x] 1.8 加入 production fixture 測試：content modification date 不早於最終輸出檔的 `<stem>.f401.mp4.part` 在清理後仍存在（scenario「mtime 不早於最終輸出檔的中間檔保留」）
- [x] 1.9 加入 production fixture 測試：以 design Implementation Contract 第 6 點的「單次失敗」case 驅動，下載拋出既有錯誤且 `<stem>.f401.mp4.part` 仍存在（scenario「下載最終失敗時不刪除任何檔案」）
- [x] 1.10 加入 `attemptExecutor` seam 測試：attempt 回傳的最終輸出路徑其父目錄與傳入的 `outputDirectory` 不同時，斷言 `cleanupObserver` 收到 `CleanupOutcome.abandoned(.outputDirectoryMismatch)`、該目錄中的候選檔未被刪除。`outputDirectory` MUST 實際存在且快照可取得，否則會先命中 `.snapshotUnavailable`——既有 seam 測試一律傳入不存在的 `/Downloads`，不可照抄（scenario「最終輸出檔不在該次下載的輸出目錄時不清理」，design Implementation Contract 第 8 點）
- [x] 1.11 加入 `attemptExecutor` seam 測試：最終輸出檔不存在時，斷言 `cleanupObserver` 收到 `CleanupOutcome.abandoned(.finalPathUnavailable)`、不刪除任何檔案且回傳原本的最終輸出路徑（scenario「判斷前提不成立時放棄整輪清理」的最終輸出檔不可用分支，design Implementation Contract 第 8 點）。輸出目錄 MUST 含有至少一個滿足其餘全部條件的區辨性候選檔並斷言其在清理後仍存在，該候選檔須由 `attemptExecutor` 在執行期間建立（但不建立所回傳的 final path）。`outputDirectory` MUST 在取得快照前即存在，否則會先命中 `.snapshotUnavailable` 而非目標的 `.finalPathUnavailable`
- [x] 1.12 加入 `attemptExecutor` seam 測試：以 `chflags uchg` 對其中一個候選檔設定 immutable flag 使其刪除失敗（還原動作 MUST 以 `defer` 或 `addTeardownBlock` 註冊，確保中途拋錯仍會執行 `nouchg`）時，斷言 `cleanupObserver` 收到的 `CleanupOutcome.completed` 中該檔名出現在 `failed`、其餘候選檔名出現在 `deleted`（兩個陣列已由實作排序，斷言 MUST 以排序後的預期值比較），其餘符合條件的候選檔仍被刪除、回傳原本的最終輸出路徑且不拋出錯誤（scenario「單一候選檔處理失敗時繼續處理其餘候選檔」）。不得改以 `chmod` 降低該檔案本身權限：macOS 的 unlink 取決於父目錄寫入權限，唯讀檔案仍會被成功刪除，測試將無法進入非致命失敗分支
- [x] 1.13 加入斷言確認既有 `executeDownloadFlow` seam 測試不產生任何檔案系統副作用（design Implementation Contract 第 8 點）
- [x] 1.14 加入 production fixture 測試：名為 `<stem>.f401.mp4.part` 的目錄（其中含有其他檔案）與名為 `<stem>.f402.mp4.part` 的 symbolic link 在清理後都仍存在，且該目錄中的檔案未被刪除（scenario「名稱符合形態的目錄與 symbolic link 保留」，design Implementation Contract 第 7 點）。兩者 MUST 由 fixture 在 invocation 期間建立而非由測試在呼叫 `download` 之前建立，否則會落入目錄快照被條件 2 排除，測試將完全不會走到條件 5 的型別檢查
- [x] 1.15 加入 `attemptExecutor` seam 測試：`outputDirectory` 在取得快照時尚不存在、由 `attemptExecutor` 在執行期間才建立該目錄與其中的檔案時，斷言 `cleanupObserver` 收到 `CleanupOutcome.abandoned(.snapshotUnavailable)`、不刪除任何檔案且回傳原本的最終輸出路徑（scenario「判斷前提不成立時放棄整輪清理」的快照取得失敗分支，design Implementation Contract 第 8 點）。`attemptExecutor` 建立的檔案 MUST 包含至少一個滿足其餘全部條件的區辨性候選檔，並斷言它在清理後仍存在
- [x] 1.16 加入 `attemptExecutor` seam 測試：由 `attemptExecutor` 在回傳前把輸出目錄的 POSIX 權限設為 `0o333`，使 `contentsOfDirectory` 以 `NSCocoaErrorDomain` 257 失敗而最終輸出檔的 `fileExists` 與 mtime 讀取仍成功、`unlink` 仍可行時，斷言 `cleanupObserver` 收到 `CleanupOutcome.abandoned(.directoryEnumerationFailed)`、不刪除任何檔案且回傳原本的最終輸出路徑（scenario「判斷前提不成立時放棄整輪清理」的目錄列舉失敗分支，design Implementation Contract 第 8 點）。MUST NOT 使用 `0o111`：該權限同時使 `unlink` 失敗，測試無法區辨「清理放棄了」與「清理想刪但刪不掉」。`attemptExecutor` MUST 在改動權限之前建立最終輸出檔本身與至少一個滿足其餘全部條件的候選檔（候選檔 mtime 早於最終輸出檔），並斷言該候選檔仍存在；若未建立最終輸出檔，檢查順序會在更早的一步就以 `.finalPathUnavailable` 放棄，`.directoryEnumerationFailed` 永遠到不了。權限還原 MUST 以 `defer` 或 `addTeardownBlock` 註冊
- [x] 1.17 加入 `attemptExecutor` seam 測試：對其中一個候選檔設定 ACL `deny readattr` 使其屬性讀取以 `NSCocoaErrorDomain` 257 失敗時，斷言 `cleanupObserver` 收到的 `CleanupOutcome.completed` 中該檔名出現在 `failed`、其餘候選檔名出現在 `deleted`（兩個陣列已由實作排序，斷言 MUST 以排序後的預期值比較），該候選檔在清理後仍存在、其餘符合條件的候選檔仍被刪除、回傳原本的最終輸出路徑且不拋出錯誤（scenario「單一候選檔處理失敗時繼續處理其餘候選檔」的屬性讀取失敗分支，design Implementation Contract 第 8 點）。ACL 還原 MUST 以 `defer` 或 `addTeardownBlock` 註冊

- [x] 1.18 加入刪除原語測試（不經過候選條件序列）：對含有檔案的目錄呼叫 `Darwin.unlink` 斷言回傳 -1、`errno == EPERM`、目錄與其中的檔案保持完整；對空目錄呼叫斷言同樣回傳 -1、`errno == EPERM`、目錄仍存在（空目錄是區分 `unlink` 與 `rmdir`／`remove(3)` 的關鍵反例）；對指向目錄的 symbolic link 呼叫 `Darwin.unlink` 斷言回傳 0、連結消失而 target 內容完整（scenario「刪除操作本身拒絕目錄」與「刪除操作不跟隨 symbolic link」，design Implementation Contract 第 9 點）。MUST NOT 改以走完整清理流程的方式驗證：目錄的 `isRegularFile` 為 false，會在型別檢查就被濾掉而根本不呼叫 `unlink`，且被過濾的項目既不在 `deleted` 也不在 `failed`，任何斷言它出現在 `failed` 的測試都是恆紅的

## 2. Implementation

- [x] 2.1 在 `Tubify/Services/YTDLPService.swift` 依 design Implementation Contract 第 1、3、4 點新增 `CleanupOutcome` 型別、新增 `directoryEntryNames(_:)`、為 `executeDownloadFlow` 新增選用參數 `cleanupObserver: ((CleanupOutcome) -> Void)? = nil`（`download` 不傳該參數），並讓 `executeDownloadFlow` 在第一個 attempt 前取得輸出目錄檔名快照，同時將三個成功 return 點收斂為單一成功出口；既有錯誤路徑不變，執行既有 `YTDLPServiceTests` 全部測試確認無回歸
- [x] 2.2 在 `Tubify/Services/YTDLPService.swift` 新增 `cleanupOrphanedPartFiles(finalPath:outputDirectory:preexistingEntryNames:taskId:observer:)`，依 design Implementation Contract 第 2、3 點實作致命與非致命失敗處置、候選條件序列、刪除與日誌。呼叫 `observer` 前 MUST 將 `deleted` 與 `failed` 以檔名遞增排序（Contract 第 3 點）。型別與 mtime MUST 以單次 `resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])` 一併讀取、讀取失敗收斂為單一非致命分支，且 MUST NOT 使用 `contentsOfDirectory(at:includingPropertiesForKeys:)` 的預取快取。刪除 MUST 使用 `Darwin.unlink(path)`、MUST NOT 使用 `FileManager.removeItem(atPath:)`（design 決策 9）。每個 return 路徑 MUST 以本次結果呼叫 `observer` 恰好一次；不拋出錯誤、不呼叫 `isCancelled`
- [x] 2.3 在 `executeDownloadFlow` 的單一成功出口呼叫 `cleanupOrphanedPartFiles`，再回傳 output path；執行任務 1.2 至 1.18 的測試確認全部通過

## 3. Verification

- [x] 3.1 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS'`，確認全部測試通過
- [x] 3.2 以程式碼審查確認 `cleanupOrphanedPartFiles` 每次成功刪除都記錄一筆含 task ID 與被刪除檔名的 info 日誌（scenario「刪除中間檔留下可辨識日誌」）
- [x] 3.3 以程式碼審查確認 `cleanupOrphanedPartFiles` 的四個致命 return 分支（快照取得失敗、父目錄不符、最終輸出檔不可用、目錄列舉失敗）各記錄一筆含 task ID 與放棄原因的 warning 日誌，兩個非致命 continue 分支（候選檔屬性讀取失敗、`unlink` 失敗）各記錄一筆含 task ID 與候選檔名的 warning 日誌，且每個分支的日誌與 `observer` 呼叫成對出現（spec「系統 SHALL 記錄該失敗」）
- [x] 3.4 確認 `openspec/changes/cleanup-orphaned-part-files/proposal.md` 的 `## Impact` affected-code 條目與本變更實際修改的檔案一致
