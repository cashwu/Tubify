## Why

Tubify 的核心下載流程已有測試保障，但目前的全域貼上快捷鍵、重啟後任務恢復、失敗原因呈現與完成後導向存在會阻斷或混淆使用者的行為。這次調整要讓主要 UI 工作流程可恢復、可診斷，並符合 macOS 一致的設定與鍵盤操作習慣。

## What Changes

- 讓 Command-V 只在主下載介面處理影片連結，文字輸入元件仍保有正常貼上行為，且事件監聽不會重複累積。
- App 啟動時恢復中斷的下載與媒體選擇任務，避免任務永久停在無法操作的狀態。
- 在下載項目內提供簡短失敗摘要與查看、複製完整錯誤的入口。
- 保留完成項目供使用者在 Finder 中定位，並讓完成通知點擊可開啟輸出位置。
- 統一設定入口為 macOS Settings scene，移除重複的設定呈現與快捷鍵。
- 改善語意字級、鍵盤焦點、可存取性標籤、指令驗證與資料夾選擇定位。

## Capabilities

### New Capabilities

- `download-ui-workflows`: 定義貼上、任務恢復、錯誤診斷、完成後導向、設定入口與鍵盤可存取性的使用者行為。

### Modified Capabilities

(none)

## Impact

- Affected specs: download-ui-workflows
- Affected code:
  - Modified:
    - Tubify.xcodeproj/project.pbxproj
    - Tubify/TubifyApp.swift
    - Tubify/ViewModels/DownloadManager.swift
    - Tubify/Views/ContentView.swift
    - Tubify/Views/DownloadItemView.swift
    - Tubify/Views/EmptyStateView.swift
    - Tubify/Views/MediaSelectionView.swift
    - Tubify/Views/PlaylistSelectionView.swift
    - Tubify/Views/SettingsView.swift
    - Tubify/Models/AppSettings.swift
    - Tubify/Services/NotificationService.swift
    - Tubify/Services/PersistenceService.swift
    - TubifyTests/ContentViewTests.swift
    - TubifyTests/DownloadManagerTests.swift
  - New:
    - TubifyTests/DownloadItemViewTests.swift
    - TubifyTests/NotificationServiceTests.swift
    - TubifyTests/SettingsViewTests.swift
  - Removed: none
