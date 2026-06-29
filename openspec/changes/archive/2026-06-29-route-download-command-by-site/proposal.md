## Why

目前 Tubify 在 `DownloadManager.addURL` 設有 `isValidYouTubeURL()` 硬性關卡，只允許 YouTube 網址進入下載佇列。然而下載後端 yt-dlp 原生支援上千個網站（x.com、Instagram 等），這道關卡是唯一阻擋使用者下載其他網站影片的限制。我們希望開放這些網站，同時不影響已運作良好的 YouTube 路徑。

## What Changes

- 放寬 `DownloadManager.addURL` 的入口驗證：移除 `isValidYouTubeURL()` 拒絕關卡，改用通用的 `isValidURLFormat()`（http/https 格式檢查）。任何格式正確的網址都能加入佇列。
- 將 `isValidYouTubeURL()` 從「擋路關卡」轉為「分流路由器」：在 `downloadSingleTask` 依任務網址判斷，YouTube 網址沿用現有 `downloadCommand`，非 YouTube 網址改用新的通用指令。
- 新增固定常數 `AppSettingsDefaults.genericDownloadCommand`（一條完整的 yt-dlp 指令，結構對齊內建預設 `AppSettingsDefaults.downloadCommand`、非使用者改過的值，僅 `-f` 改為通用選擇器如 `bv*+ba/b`），**不**進入設定頁、不可由使用者編輯。
- 將 `addURL` 內既有的 YouTube 專屬分支閘控於 YouTube 網址：playlist 偵測／展開、混合影片＋清單網址的提示、以及 video ID 推導的 `i.ytimg.com` 縮圖預取，非 YouTube 網址一律走單一任務路徑且不帶 ytimg 縮圖。
- 移除 `ContentView.processTextInput` 中現已多餘的 `youtube.com/youtu.be` 文字比對 fallback（http/https 開頭文字本就會交給 `addURL`）。
- 移除 `URLValidationResult.notYouTubeURL` case 與對應的「僅支援 YouTube 網址」錯誤訊息。
- UI 文案中性化：將「拖放或貼上 YouTube 連結」等 YouTube 字眼改為通用影片用語。

## Non-Goals (optional)

（不適用，Non-Goals 記於 design.md 的 Goals/Non-Goals 段落）

## Capabilities

### New Capabilities

- `multi-site-download`: 依任務網址分流下載指令——YouTube 沿用既有最佳化指令，非 YouTube 走通用指令；並放寬入口驗證以接受任何有效網址。

### Modified Capabilities

（無——現有 specs 皆為 YouTube 功能專屬，不涉及入口驗證或下載指令選擇的需求變更）

## Impact

- Affected specs: 新增 `multi-site-download`
- Affected code:
  - New:
    - openspec/changes/route-download-command-by-site/specs/multi-site-download/spec.md
  - Modified:
    - Tubify/ViewModels/DownloadManager.swift（移除 YouTube 入口關卡、新增指令分流 helper、將 playlist／提示／縮圖預取閘控於 YouTube）
    - Tubify/Models/AppSettings.swift（新增 genericDownloadCommand 預設常數）
    - Tubify/Views/ContentView.swift（移除多餘文字 fallback、移除 notYouTubeURL 處理）
    - Tubify/Views/EmptyStateView.swift（UI 文案中性化）
  - Removed:
    - （無檔案刪除；僅移除 URLValidationResult.notYouTubeURL enum case）
