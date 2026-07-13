## 1. 字幕選取行為測試

- [x] 1.1 在 `TubifyTests/MediaSelectionLogicTests.swift` 為同檔案內、internal 的 `clearSelectedSubtitles(_:)` 純函式新增 `Clear all selected subtitles` 測試，證明呼叫後字幕集合為空、函式未接收或改動音軌狀態，且清空後可只重新加入一種字幕；以新增的 XCTest cases 通過驗證。

## 2. 字幕批次取消介面

- [x] 2.1 在 `Tubify/Views/MediaSelectionView.swift` 以同檔案內、internal 的 `clearSelectedSubtitles(_:)` 純函式實作標示為「全部取消」的字幕區塊操作，使其清空 `selectedSubtitleLanguages`；以 XCTest 驗證狀態轉換，並以 SwiftUI preview 手動驗證 `Preserve default subtitle selection`：視窗初次出現仍全選支援字幕，按鈕確實連到清空操作、視窗未 dismiss、`selectedAudioLanguage` 與音軌 UI 選擇不變，以及三種字幕可一次取消後只重新勾選 `en`。

## 3. 整體驗證

- [x] 3.1 執行 `xcodebuild test -project Tubify.xcodeproj -scheme Tubify -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`，確認字幕批次取消純函式及既有音軌選擇測試全部通過；字幕預設全選仍依 task 2.1 的 SwiftUI preview 手動檢查驗證。
