## Context

Tubify 目前以 SwiftUI `ContentView` 管理主視窗，並由單例 `DownloadManager` 持久化任務與發出媒體選擇 callback。全域鍵盤 monitor、callback 設定時機及完成任務自動移除，使部分操作跨越主視窗、Settings scene 或 App 重啟後失去正確狀態。這個變更橫跨 View、DownloadManager、通知服務與 UserDefaults，但不改變 yt-dlp 執行協定或既有下載格式。

## Goals / Non-Goals

**Goals:**

- 文字編輯器中的 Command-V 維持標準貼上，主介面仍可用 Command-V 新增一個或多個 URL。
- 所有持久化的中斷狀態在 UI callbacks 就緒後可安全恢復，且恢復流程可重複呼叫而不重複建立工作。
- 失敗與完成任務都有使用者可發現、可操作的後續路徑。
- Settings 僅由原生 Settings scene 呈現，並保持指令與資料夾設定可診斷。
- 主要 icon controls 支援鍵盤焦點與可存取性名稱，字級使用一致的語意層級。

**Non-Goals:**

- 不重寫 yt-dlp command parser、下載佇列演算法或播放清單展開流程。
- 不新增第三方 UI、通知或 persistence dependency。
- 不建立下載歷史資料庫；完成項目仍使用既有任務 persistence。
- 不改變已儲存的 `autoRemoveCompleted` 使用者偏好，只調整沒有既有值時的預設值。

## Decisions

### Focus-aware paste monitor lifecycle

保留現有 local key event monitor，因為它能在主視窗沒有文字欄位時提供直接貼上 URL 的體驗。`ContentView` 取得承載它的 `NSWindow` 後，以固定 identifier 標記主下載視窗；處理 Command-V 時必須同時確認 event window 帶有該 marker，且 first responder 不是 `NSTextView` 或其他文字輸入 responder。Settings 或其他非主下載視窗一律原樣交回事件，即使當下焦點不是文字欄位。

monitor lifecycle 集中在同檔案內的 internal `PasteMonitorController`：它保存唯一 token，`install()` 在已有 token 時無動作，`uninstall()` 移除並清空 token。controller 接受可注入的 add/remove closures，讓 XCTest 直接觀察安裝與移除次數；SwiftUI `.onAppear`／`.onDisappear` wiring 仍以關閉、重開主視窗後只新增一次 URL 的手動整合檢查驗證。相較於重建整套 FocusedValue command routing，這是較小且可測試的修正。

### UI-activated persisted task recovery

`DownloadManager` 初始化只載入資料，不在 UI callback 尚未註冊時發出需要呈現 sheet 的工作。`ContentView` 為每個 view lifecycle 建立一個穩定 `UUID` session identifier，設定三種 callback 後呼叫 `resumePersistedTasksAfterUIActivation(sessionID:)`：

- `downloading` 回到 `pending`，保留既有媒體選擇後重新排隊。
- `fetchingInfo` 重新取得 metadata。
- `waitingForMediaSelection` 使用已持久化的字幕與音軌重建 request；若選項缺失則回到 metadata fetch。
- 既有 `pending` 工作在 recovery 完成後啟動 queue。

manager 將 activation 分成兩層 idempotency：內部 recovery flag 保證 persisted state transition、metadata fetch 與 queue activation 在 manager lifetime 只啟動一次；delivered-session set 保證 unresolved selection requests 對同一 `sessionID` 只送一次，但新 `ContentView` session 可重播仍待處理的 request，而不重啟 recovery work。

media、playlist 與 video-or-playlist choice request 在 manager 內以既有 request identity 暫存，先註冊再呼叫目前 callback，並在 confirm/cancel 時移除。`ContentView` 消失時呼叫 `deactivateUI(sessionID:)`，只有 active session 相符時才解除 callbacks。若 async work 在沒有 active UI 時完成，request 留在 manager registry；下一個 session activation 後發出一次。這些 registries 只處理 process 內的 UI 重連，persisted recovery 仍由 task 狀態重建，不新增 persistence shape。

`PlaylistSelectionView` 不再以 `.onDisappear` 推論使用者取消，因為 parent teardown 與 session reconnect 也會觸發 disappearance。只有明確按下「取消」才呼叫 manager cancel；確認下載仍呼叫 confirm。sheet 使用 `.interactiveDismissDisabled()`，讓 Escape 走明確取消按鈕，而主視窗／parent teardown 只 detach UI，不移除 placeholder 或 resolve registry request。

現有 `fetchingInfo` 同時涵蓋三種來源，恢復時依現有持久化資料做明確 routing，不改 `DownloadTask` Codable shape：

- title 為既有 placeholder marker「載入播放清單中...」且 URL 仍被辨識為 playlist 的任務，重新呼叫既有 `expandPlaylist`，恢復 playlist selection。
- 已展開的 playlist child 只有個別影片 URL 與標題，group membership 未持久化；重啟後安全降級為個別 `fetchMetadataForTask`，需要媒體選擇時可各自提出 request，不重新建立原 playlist group。
- 其他 `fetchingInfo` 任務沿用單支影片的 `fetchMetadataForTask`。

不以所有 playlist-shaped URL 一律判定 placeholder，避免含 `list` query 的 child video 被誤展開；placeholder marker 與 playlist URL 兩者必須同時成立。

### Actionable error presentation

失敗 row 保留精簡狀態 badge，並加入「詳細資訊」控制。完整 `errorMessage` 由 alert 呈現，使用者可複製；摘要由純函式取得 trim 後第一個非空白行。摘要最多 160 個 Swift `Character`；超過時保留前 159 個並附加單一 `…`，總長仍為 160。nil、空字串或只有空白行時使用固定 localized fallback。這使多行、超長與多位元 Unicode 輸出都能穩定測試，且不破壞列表排版。權限錯誤仍保留前往設定操作。

### Persistent completion and notification navigation

沒有既有 preference 時，`autoRemoveCompleted` 預設為 false，讓成功 row 保留 Finder action。`NotificationService` 成為 `UNUserNotificationCenterDelegate`，在初始化時設定 delegate。internal `NotificationOutputRouter` 只接受 notification `userInfo`，並透過可注入的 `fileExists` 與 `revealInFinder` closures 驗證及開啟 `outputPath`；production closures 使用 `FileManager` 與 `NSWorkspace`。delegate 直接轉交 internal `handleActivatedNotification(userInfo:completionHandler:)`，該 helper 呼叫 router 並保證 completion handler 對有效、缺少及無效路徑都恰好執行一次。另以實際點擊有效通知及輸出檔案已刪除的通知驗證系統 delegate wiring。

### Single native Settings scene

保留 `Settings { SettingsView() }` 作為唯一設定容器，移除額外 Settings command 與主畫面 sheet。齒輪透過 `openSettings` environment action 開啟同一個原生設定視窗，避免兩份 SettingsView 同時存在。

### Semantic typography and accessible controls

主畫面、下載 row、設定與選擇 sheet 改用 `.largeTitle`、`.title2`、`.headline`、`.body`、`.callout`、`.caption` 等語意字級，避免 10pt 到 33pt 的不一致固定值。可操作 icon button 不再強制 `.focusable(false)`，並以明確 accessibility label 描述動作；tooltips 繼續保留。

### Lightweight settings validation

internal 純函式 `validateDownloadCommand(_:)` 回傳 `DownloadCommandValidation.valid`、`.empty` 或 `.missingYouTubeURLPlaceholder`，`SettingsView` 直接以此結果在 editor 下方顯示對應 localized 紅色驗證訊息與重設入口。這一版不改成 draft/transactional settings，避免重做所有 AppStorage save semantics。資料夾 panel 使用 `URL(fileURLWithPath:)` 定位既有本機路徑。

## Implementation Contract

**Behavior**

- 只有帶有主下載視窗 marker 的 event window 接收 Command-V 且 first responder 不是文字輸入時，剪貼簿內每行有效 HTTP(S) URL 各新增一次；文字輸入 responder 或 Settings 等非主下載視窗活躍時，不得新增任務且事件必須交回 AppKit。
- `ContentView` 的 paste monitor 在同一個 view lifecycle 最多存在一個，view 消失後必須移除。
- `DownloadManager.resumePersistedTasksAfterUIActivation(sessionID:)` 對同一 session 必須可重複呼叫而不重複 metadata fetch、selection request 或 queue activation；新 session 必須重播仍 unresolved 的 request 一次，但不得重啟 manager-wide recovery work。
- 持久化的 `downloading`、`fetchingInfo`、`waitingForMediaSelection` 與 `pending` 任務必須依設計決策恢復；`fetchingInfo` playlist placeholder 重新展開，playlist child 安全降級為個別 metadata recovery。`completed`、`failed`、`cancelled`、`paused`、`scheduled`、`livestreaming` 與 `postLive` 不得自動改變或觸發 recovery work。
- 一般 failed row 必須呈現非空白摘要並提供完整錯誤與複製操作；摘要遵守 160 個 `Character` 上限，沒有 errorMessage 時顯示穩定 fallback 文案。
- 新安裝預設保留 completed row；既有使用者明確保存的 auto-remove preference 必須維持。
- 完成通知點擊且 outputPath 有效時必須在 Finder 選取輸出檔案；無效或缺少路徑時必須安全結束。
- playlist sheet 因 parent/view disappearance 關閉時不得視為取消；只有明確取消 action 才移除 placeholder 與 unresolved request。
- 主畫面齒輪與 Command-, 必須指向同一個 Settings scene，App 不得同時維護 settings sheet。
- 下載 command 缺少 `$youtubeUrl` 或只有空白時必須出現可見驗證訊息。
- 本機下載資料夾包含空格時，folder picker 必須能以該路徑作為起始目錄。

**Interfaces and data**

- 新增 `DownloadManager.resumePersistedTasksAfterUIActivation(sessionID: UUID)` 與 `deactivateUI(sessionID: UUID)` 作為 callback lifecycle 邊界；manager 維護 process-local unresolved request registries、active session 與 delivered-session bookkeeping。
- `ContentView.swift` 內新增 internal `PasteMonitorController` 與純 routing helper；controller 以注入的 add/remove closures 暴露可測試 lifecycle，主視窗使用固定 `NSWindow.identifier` marker。
- `NotificationService.swift` 內新增 internal `NotificationOutputRouter` 與 `handleActivatedNotification(userInfo:completionHandler:)`；前者以注入的 `fileExists`／`revealInFinder` closures 隔離系統副作用，後者是 delegate 共用且可測試的 completion bridge。
- `SettingsView.swift` 內新增 internal `DownloadCommandValidation` 與純函式 `validateDownloadCommand(_:)`，供 view 與 XCTest 共用。
- `NotificationService` 保持 `NotificationServiceProtocol` 對外方法不變，僅增加 notification delegate 行為。
- UserDefaults keys 與 `DownloadTask` Codable shape 不變。

**Failure modes**

- 空剪貼簿或不含 HTTP(S) URL 的文字維持無動作，不建立錯誤任務。
- 恢復中的 metadata fetch 失敗沿用既有 DownloadManager fallback 與下載錯誤處理。
- notification response 的 outputPath 無效時不得開啟其他位置或拋出未處理錯誤。
- selection callback 在 UI 缺席時不得丟棄 request；新 session 只重播 unresolved request，不重啟 metadata 或 queue work。
- 指令驗證只提供明確 UI 回饋，不在本變更內自動重寫使用者輸入。

**Acceptance criteria**

- 新增或更新單元測試覆蓋 paste routing、`PasteMonitorController` install/uninstall 次數、各持久化狀態恢復、七種排除狀態、playlist placeholder/child routing、同 session idempotency、新 session unresolved request replay、UI 缺席時完成的 async request、錯誤摘要邊界、notification output routing、delegate completion bridge、completion branch 的預設保留／既有 preference 移除，以及 `validateDownloadCommand(_:)` 三種結果。
- 執行 macOS `xcodebuild test` 必須全部通過。
- `spectra analyze improve-download-ui-workflows` 與 `spectra validate improve-download-ui-workflows` 不得有 Critical finding 或 validation error。
- 手動檢查主視窗貼上 URL、Settings editor 與非文字控制聚焦時不建立任務、關閉再重開主視窗後一次貼上只新增一次、playlist sheet 顯示中重建主視窗後 placeholder 保留且 unresolved request 恰好重播一次、失敗詳情、completed row Finder action、點擊有效完成通知會在 Finder 選取檔案、通知送出後先刪除輸出檔再點擊可安全結束、Settings 單一視窗、鍵盤焦點、以 Accessibility Inspector 或 VoiceOver 確認 toolbar 與 download row icon controls 的 localized labels，以及把下載資料夾設為有效且含空格的路徑後確認 folder picker 以該目錄起始。

**Scope boundaries**

- In scope: proposal Impact 所列 SwiftUI views、DownloadManager recovery、AppSettings default、NotificationService delegate 及對應 tests。
- Out of scope: yt-dlp executable discovery、command argument parsing、callback URL scheme、下載格式與 playlist metadata service 行為。

## Risks / Trade-offs

- [Risk] local event monitor 仍是 App 層級機制，未來新增其他自訂 text responder 時可能需要擴充辨識 → 將判斷集中為可測試 helper，預設對標準 `NSTextView` 放行。
- [Risk] playlist child 的 group membership 未持久化，重啟後無法重建單一批次 media-selection request → 明確降級為逐項 metadata recovery；不擴充 Codable shape，避免 migration 風險。
- [Risk] manager-owned unresolved request registries 增加 process-local UI 狀態 → registry 只保存既有 request value、以 confirm/cancel 移除，並以 session identifier 控制重播，不建立第二套持久化模型。
- [Risk] waitingForMediaSelection recovery 重新呈現多任務 request 時可用選項可能來自舊 metadata → 優先使用 persistence 以避免額外網路成本；缺資料時才重新 fetch。
- [Risk] 完成項目預設保留會增加列表長度 → 既有清除完成與 auto-remove setting 仍可控制。
- [Risk] notification delegate 是 shared service 的全域 delegate → 本 App 目前只有單一通知服務，集中處理可避免競爭。
