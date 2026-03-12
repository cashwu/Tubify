## Context

目前 Tubify 在偵測到播放清單 URL 時，會在 `DownloadManager.expandPlaylist()` 中透過 `YouTubeMetadataService.fetchPlaylistInfo()` 取得所有影片資訊，然後全部自動加入下載佇列。使用者沒有機會選擇要下載哪些影片。

專案已有類似的 sheet 互動模式：`MediaSelectionView` 用於字幕/音軌選擇，透過 `onMediaSelectionNeeded` callback 從 `DownloadManager` 觸發，在 `ContentView` 中以 `.sheet` 呈現。

## Goals / Non-Goals

**Goals:**

- 讓使用者在播放清單展開後，透過勾選介面選擇要下載的影片
- 提供全選 / 全部取消的快捷操作
- 選集確認後銜接現有的字幕/音軌選擇流程
- 字幕/音軌設定統一套用到所有已選影片

**Non-Goals:**

- 不支援每部影片個別設定字幕/音軌
- 不改變單一影片的下載流程
- 不新增播放清單的搜尋或篩選功能

## Decisions

### 使用 callback 模式觸發選集 UI

沿用現有 `MediaSelectionView` 的架構模式：`DownloadManager` 透過 callback（`onPlaylistSelectionNeeded`）將影片列表傳給 `ContentView`，由 `ContentView` 以 `.sheet` 呈現 `PlaylistSelectionView`。

**替代方案**：直接在 `DownloadManager` 中使用 async/await 暫停等待使用者選擇。但這會讓 ViewModel 耦合 UI 邏輯，不符合現有架構慣例。

### 兩段式 sheet 流程

選集確認後關閉 `PlaylistSelectionView`，接著彈出 `MediaSelectionView` 進行字幕/音軌選擇。兩個 sheet 依序呈現，不疊加。

**替代方案**：合併成一個大視窗同時選影片和字幕/音軌。但這會增加 UI 複雜度，且字幕/音軌資訊需要額外的 metadata 查詢，不適合在選集階段就載入。

### 選集資料結構

新增 `PlaylistSelectionRequest` 結構，包含播放清單標題、影片列表（`[VideoInfo]`）、佔位任務 ID，以及 callback 相關資訊。與現有 `MediaSelectionRequest` 模式一致。

## Risks / Trade-offs

- [大型播放清單的 UI 效能] → 使用 `LazyVStack` 搭配 `ScrollView`，只渲染可見項目
- [兩段式 sheet 的 UX 中斷感] → 兩個 sheet 間的切換應該是順暢的，SwiftUI 的 sheet dismiss/present 動畫會自然銜接
- [字幕/音軌 fallback 邏輯] → 個別影片不支援所選字幕/音軌時，沿用現有的預設行為（不下載該字幕/音軌），不需要額外處理
