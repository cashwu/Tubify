# Tubify 與 Whispify 整合規格

## 概述

本文件定義 Whispify 與 Tubify 之間的雙向 URL Scheme 整合規格，讓使用者可以在 Whispify 中貼上 YouTube URL，**先設定轉錄選項**，再調用 Tubify 下載，下載完成後**自動加入轉錄佇列**。

## 整合流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                          使用者操作流程                               │
└─────────────────────────────────────────────────────────────────────┘

1. 使用者在 Whispify 貼上 YouTube URL
2. Whispify 顯示轉錄設定對話框（語言、模型、提示詞選項）
3. 使用者完成設定，點擊「開始」
4. Whispify 暫存設定，呼叫 Tubify URL Scheme（帶 request_id）
5. Tubify 被啟動，開始下載（使用者可在 Tubify 看到進度）
6. 下載完成後，Tubify 呼叫 Whispify URL Scheme 回調（帶回 request_id）
7. Whispify 用 request_id 找回暫存的設定，自動建立專案並加入佇列

┌──────────┐                              ┌──────────┐
│ Whispify │                              │  Tubify  │
└────┬─────┘                              └────┬─────┘
     │                                         │
     │  [使用者設定轉錄選項]                      │
     │  [暫存設定，生成 request_id]              │
     │                                         │
     │  tubify://download?url=...&request_id=...│
     │────────────────────────────────────────>│
     │                                         │
     │         (使用者在 Tubify 看到下載進度)      │
     │                                         │
     │  whispify://import?request_id=...&file=...│
     │<────────────────────────────────────────│
     │                                         │
     │  [用 request_id 找回設定]                 │
     │  [組合 prompt（自訂 + 標題）]              │
     │  [自動建立專案並加入佇列]                   │
     │                                         │
```

---

## URL Scheme 規格

### 1. Tubify URL Scheme（Whispify → Tubify）

**Scheme**: `tubify://`

**Action**: `download`

**完整格式**:
```
tubify://download?url=<encoded_youtube_url>&callback=<callback_scheme>&request_id=<uuid>
```

**參數**:

| 參數 | 必填 | 說明 | 範例 |
|------|------|------|------|
| `url` | ✅ | URL-encoded 的 YouTube 網址 | `https%3A%2F%2Fyoutube.com%2Fwatch%3Fv%3Dabc123` |
| `callback` | ❌ | 下載完成後的回調 scheme | `whispify` |
| `request_id` | ❌ | 請求識別碼，回調時原樣帶回 | `550e8400-e29b-41d4-a716-446655440000` |

**範例**:
```
tubify://download?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ&callback=whispify&request_id=550e8400-e29b-41d4-a716-446655440000
```

**行為**:
1. Tubify 接收到此 URL 後，自動將影片加入下載佇列
2. Tubify 需要**保存** `callback` 和 `request_id` 到對應的下載任務
3. 如果有 `callback` 參數，下載完成後觸發回調，並帶回 `request_id`
4. 如果沒有 `callback` 參數，行為與一般下載相同（不回調）

---

### 2. Whispify URL Scheme（Tubify → Whispify）

**Scheme**: `whispify://`

**Action**: `import`

**完整格式**:
```
whispify://import?request_id=<uuid>&file=<encoded_file_path>&title=<encoded_title>&duration=<seconds>&thumbnail=<encoded_thumbnail_url>
```

**參數**:

| 參數 | 必填 | 說明 | 範例 |
|------|------|------|------|
| `request_id` | ✅* | 請求識別碼（來自原始請求） | `550e8400-e29b-41d4-a716-446655440000` |
| `file` | ✅ | URL-encoded 的本機檔案路徑 | `%2FUsers%2Fuser%2FDownloads%2Fvideo.mp4` |
| `title` | ❌ | URL-encoded 的影片標題 | `Never%20Gonna%20Give%20You%20Up` |
| `duration` | ❌ | 影片時長（秒） | `212` |
| `thumbnail` | ❌ | URL-encoded 的縮圖 URL | `https%3A%2F%2Fi.ytimg.com%2Fvi%2Fxxx%2Fhqdefault.jpg` |

*如果原始請求有 `request_id`，則回調時必須帶回

**範例**:
```
whispify://import?request_id=550e8400-e29b-41d4-a716-446655440000&file=%2FUsers%2Fuser%2FDownloads%2FNever%20Gonna%20Give%20You%20Up.mp4&title=Never%20Gonna%20Give%20You%20Up&duration=212
```

**行為**:
1. Whispify 接收到此 URL 後，驗證檔案存在
2. 用 `request_id` 查找之前暫存的設定
3. 如果使用者勾選了「附加影片標題到提示詞」，組合最終 prompt
4. 更新專案的時長（`duration`）等 metadata
5. 自動建立轉錄專案並加入佇列（不再顯示對話框）

---

## Prompt 組合邏輯

### 使用者設定

```
┌─────────────────────────────────────────────────────┐
│  提示詞設定                                          │
│                                                     │
│  自訂提示詞（選填）:                                  │
│  [請注意專有名詞的發音...                        ]   │
│                                                     │
│  ☑ 附加影片標題到提示詞                              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 組合規則

| 自訂提示詞 | 附加標題 | 最終 Prompt |
|-----------|---------|-------------|
| 空 | ❌ | （空） |
| 空 | ✅ | `{title}` |
| 有內容 | ❌ | `{自訂}` |
| 有內容 | ✅ | `{自訂}\n{title}` |

**範例**:
- 自訂：`請注意專有名詞的發音`
- 標題：`React 19 新功能完整介紹`
- 最終：`請注意專有名詞的發音\nReact 19 新功能完整介紹`

---

## 暫存設定結構

Whispify 在呼叫 Tubify 前暫存的設定：

```swift
struct PendingDownloadRequest {
    let requestId: UUID
    let youtubeURL: String
    let language: TranscriptionLanguage
    let modelId: UUID
    let customPrompt: String
    let appendTitleToPrompt: Bool  // 是否附加標題
    let enableAutoSegmentBreaks: Bool
    let createdAt: Date
}
```

---

## 時長與 Metadata 更新

| 欄位 | 設定時 | 回調後 |
|------|--------|--------|
| 專案名稱 | 使用 YouTube URL | 更新為 `title`（如果有） |
| 時長 | 無 | 更新為 `duration` |
| 縮圖 | 無 | 可從 `thumbnail` 下載 |
| Prompt | 只有自訂部分 | 組合自訂 + 標題 |

**重新轉錄時**：時長等資訊已存在專案中，設定頁面可顯示。

---

## 錯誤處理

### Tubify 端

| 情況 | 處理方式 |
|------|----------|
| URL 無效 | 顯示錯誤提示，不觸發回調 |
| 下載失敗 | 顯示錯誤提示，觸發失敗回調（可選） |
| 使用者取消 | 不觸發回調 |

**失敗回調格式（可選實現）**:
```
whispify://import?request_id=<uuid>&error=<error_code>&message=<encoded_message>
```

### Whispify 端

| 情況 | 處理方式 |
|------|----------|
| Tubify 未安裝 | 顯示提示，引導使用者下載 Tubify |
| 檔案不存在 | 顯示錯誤提示 |
| 檔案格式不支援 | 顯示錯誤提示 |
| `request_id` 找不到對應設定 | 顯示錯誤或降級處理 |

---

## 暫存設定的清理策略

為避免記憶體洩漏，Whispify 應定期清理過期的暫存設定：

- **過期時間**: 24 小時（可配置）
- **清理時機**: App 啟動時、定時清理
- **持久化**: 可選擇持久化到 UserDefaults，以便 App 重啟後仍能處理回調

---

## 安全考量

1. **路徑驗證**: Whispify 必須驗證 `file` 參數指向的路徑確實存在且為支援的媒體格式
2. **Sandbox**: 兩個 App 都需要適當的 entitlements 來存取檔案
3. **URL 編碼**: 所有參數必須正確 URL encode/decode
4. **Request ID 驗證**: 確保 `request_id` 是有效的 UUID 格式

---

## 版本相容性

| Tubify 版本 | Whispify 版本 | 支援狀態 |
|-------------|---------------|----------|
| < 1.x (無 URL Scheme) | 任意 | ❌ 不支援，顯示升級提示 |
| >= 1.x (有 URL Scheme) | >= 1.x | ✅ 完整支援 |

---

## 測試案例

### 測試 1: 完整流程
1. 在 Whispify 貼上 `https://www.youtube.com/watch?v=dQw4w9WgXcQ`
2. 設定語言、模型，勾選「附加影片標題到提示詞」
3. 點擊「開始」
4. 預期: Tubify 啟動並開始下載
5. 下載完成後，Whispify 自動建立專案並加入佇列
6. 驗證: Prompt 包含影片標題

### 測試 2: Tubify 未安裝
1. 移除 Tubify
2. 在 Whispify 貼上 YouTube URL
3. 點擊「從 YouTube 匯入」
4. 預期: 顯示「請安裝 Tubify」提示

### 測試 3: 下載取消
1. 在 Whispify 觸發下載
2. 在 Tubify 取消下載
3. 預期: Whispify 不收到回調，暫存設定 24 小時後自動清理

### 測試 4: 不附加標題
1. 設定時不勾選「附加影片標題到提示詞」
2. 完成下載
3. 驗證: Prompt 只包含自訂內容，不包含標題

### 測試 5: 重新轉錄
1. 完成一次轉錄
2. 點擊重新轉錄
3. 預期: 設定頁面顯示時長等 metadata

---

## 附錄: URL Scheme 測試指令

```bash
# 測試 Tubify URL Scheme（需先安裝支援 URL Scheme 的 Tubify）
open "tubify://download?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ&callback=whispify&request_id=550e8400-e29b-41d4-a716-446655440000"

# 測試 Whispify URL Scheme（需先安裝支援 URL Scheme 的 Whispify）
open "whispify://import?request_id=550e8400-e29b-41d4-a716-446655440000&file=%2FUsers%2Fuser%2FDownloads%2Ftest.mp4&title=Test%20Video&duration=120"
```
