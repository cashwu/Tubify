## Why

字幕選擇器目前預設勾選所有可用字幕；當字幕選項很多而使用者只需要其中一種時，必須逐項取消，操作成本過高。

## What Changes

- 在字幕區塊提供「全部取消」操作，一次清除所有已勾選的字幕。
- 清除後保留選擇視窗，讓使用者重新勾選需要的字幕，再按「下載」。
- 保留字幕預設全選行為。
- 音軌選擇與下載行為維持不變。

## Non-Goals

- 不變更音軌選擇器、預設音軌或音訊下載行為。
- 不改變字幕語言過濾、字幕下載格式或選擇視窗的送出流程。
- 不新增跨 view 的共用選取元件或新的資料模型。

## Capabilities

### New Capabilities

- `subtitle-selection`: 定義字幕預設選取、批次取消與取消後重新選取的互動行為。

### Modified Capabilities

(none)

## Impact

- Affected specs: `subtitle-selection`
- Affected code:
  - Modified:
    - `Tubify/Views/MediaSelectionView.swift`
    - `TubifyTests/MediaSelectionLogicTests.swift`
  - New: (none)
  - Removed: (none)
