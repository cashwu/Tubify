# Tubify 修改指南 - URL Scheme 整合

本文件說明如何在 Tubify 中新增 URL Scheme 支援，以便與 Whispify 整合。

> ⚠️ **重要**: 所有修改都是**新增功能**，不會影響 Tubify 現有的操作方式。

---

## 修改概覽

| 檔案 | 修改類型 | 說明 |
|------|----------|------|
| `Info.plist` | 修改 | 新增 URL Scheme 註冊 |
| `Tubify/TubifyApp.swift` | 修改 | 新增 URL 處理邏輯 |
| `Tubify/Models/DownloadTask.swift` | 修改 | 新增回調相關欄位 |
| `Tubify/ViewModels/DownloadManager.swift` | 修改 | 新增回調觸發邏輯 |
| `Tubify/Services/CallbackService.swift` | 新增 | URL Scheme 回調服務 |

---

## 1. 修改 Info.plist

在 `Info.plist` 中新增 URL Scheme 註冊：

```xml
<!-- 在 <dict> 內新增以下內容 -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.cashwu.Tubify</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tubify</string>
        </array>
    </dict>
</array>
```

**位置**: 放在 `</dict>` 結束標籤之前即可。

---

## 2. 修改 TubifyApp.swift

在 `AppDelegate` 類別中新增 URL 處理：

```swift
// MARK: - URL Scheme 處理

/// 處理外部 URL Scheme 呼叫
/// 格式: tubify://download?url=<encoded_url>&callback=<callback_scheme>&request_id=<uuid>
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        handleIncomingURL(url)
    }
}

private func handleIncomingURL(_ url: URL) {
    guard url.scheme == "tubify" else { return }

    switch url.host {
    case "download":
        handleDownloadURL(url)
    default:
        Logger.shared.warning("未知的 URL action: \(url.host ?? "nil")")
    }
}

private func handleDownloadURL(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems else {
        Logger.shared.error("無法解析 URL 參數")
        return
    }

    // 解析參數
    var videoURL: String?
    var callbackScheme: String?
    var requestId: String?

    for item in queryItems {
        switch item.name {
        case "url":
            videoURL = item.value?.removingPercentEncoding
        case "callback":
            callbackScheme = item.value
        case "request_id":
            requestId = item.value
        default:
            break
        }
    }

    guard let videoURL = videoURL, !videoURL.isEmpty else {
        Logger.shared.error("缺少必要的 url 參數")
        return
    }

    Logger.shared.info("收到外部下載請求: \(videoURL), callback: \(callbackScheme ?? "無"), request_id: \(requestId ?? "無")")

    // 通知 DownloadManager 新增下載任務
    NotificationCenter.default.post(
        name: .externalDownloadRequest,
        object: nil,
        userInfo: [
            "url": videoURL,
            "callback": callbackScheme as Any,
            "request_id": requestId as Any
        ]
    )

    // 將 App 帶到前景
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

同時在檔案頂部新增 Notification 擴展：

```swift
// MARK: - Notification Names

extension Notification.Name {
    static let externalDownloadRequest = Notification.Name("externalDownloadRequest")
}
```

---

## 3. 修改 DownloadTask.swift

在 `DownloadTask` 類別中新增回調相關欄位：

```swift
// 在現有屬性之後新增

/// 下載完成後的回調 Scheme（例如 "whispify"）
/// 如果為 nil，表示不需要回調
var callbackScheme: String?

/// 請求識別碼，回調時原樣帶回給呼叫方
/// 用於讓呼叫方對應到原始請求
var requestId: String?
```

**位置**: 放在其他屬性宣告附近。

如果 `DownloadTask` 有使用 `Codable`，也需要更新編解碼邏輯：

```swift
// 在 CodingKeys enum 中新增
case callbackScheme
case requestId

// 在 init(from decoder:) 中新增
callbackScheme = try container.decodeIfPresent(String.self, forKey: .callbackScheme)
requestId = try container.decodeIfPresent(String.self, forKey: .requestId)

// 在 encode(to encoder:) 中新增
try container.encodeIfPresent(callbackScheme, forKey: .callbackScheme)
try container.encodeIfPresent(requestId, forKey: .requestId)
```

---

## 4. 新增 CallbackService.swift

建立新檔案 `Tubify/Services/CallbackService.swift`：

```swift
import Foundation
import AppKit

/// 處理下載完成後的 URL Scheme 回調
actor CallbackService {
    static let shared = CallbackService()

    private init() {}

    /// 觸發回調通知外部 App
    /// - Parameters:
    ///   - scheme: 回調的 URL Scheme（例如 "whispify"）
    ///   - task: 完成的下載任務
    ///   - filePath: 下載檔案的本機路徑
    func triggerCallback(
        scheme: String,
        task: DownloadTask,
        filePath: String
    ) async {
        // 建構回調 URL
        var components = URLComponents()
        components.scheme = scheme
        components.host = "import"

        var queryItems: [URLQueryItem] = []

        // 必填: request_id（如果有的話）
        if let requestId = task.requestId {
            queryItems.append(URLQueryItem(
                name: "request_id",
                value: requestId
            ))
        }

        // 必填: 檔案路徑
        queryItems.append(URLQueryItem(
            name: "file",
            value: filePath
        ))

        // 選填: 標題
        if !task.title.isEmpty {
            queryItems.append(URLQueryItem(
                name: "title",
                value: task.title
            ))
        }

        // 選填: 時長（如果有的話）
        if let duration = task.duration, duration > 0 {
            queryItems.append(URLQueryItem(
                name: "duration",
                value: String(Int(duration))
            ))
        }

        // 選填: 縮圖 URL
        if let thumbnail = task.thumbnail {
            queryItems.append(URLQueryItem(
                name: "thumbnail",
                value: thumbnail.absoluteString
            ))
        }

        components.queryItems = queryItems

        guard let callbackURL = components.url else {
            Logger.shared.error("無法建構回調 URL")
            return
        }

        Logger.shared.info("觸發回調: \(callbackURL.absoluteString)")

        // 在主執行緒開啟 URL
        await MainActor.run {
            NSWorkspace.shared.open(callbackURL)
        }
    }

    /// 檢查目標 App 是否已安裝
    /// - Parameter scheme: URL Scheme
    /// - Returns: 是否可以開啟該 Scheme
    func canOpenScheme(_ scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else {
            return false
        }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}
```

---

## 5. 修改 DownloadManager.swift

### 5.1 新增監聽外部下載請求

在 `init()` 方法中新增：

```swift
// 監聽外部下載請求
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleExternalDownloadRequest(_:)),
    name: .externalDownloadRequest,
    object: nil
)
```

新增處理方法：

```swift
@objc private func handleExternalDownloadRequest(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let urlString = userInfo["url"] as? String else {
        return
    }

    let callbackScheme = userInfo["callback"] as? String
    let requestId = userInfo["request_id"] as? String

    // 建立下載任務，帶上 callback 和 request_id 資訊
    addURL(urlString, callbackScheme: callbackScheme, requestId: requestId)
}
```

### 5.2 修改 addURL 方法

更新 `addURL` 方法簽名以支援 callback 和 request_id：

```swift
/// 新增下載任務
/// - Parameters:
///   - urlString: YouTube URL
///   - callbackScheme: 下載完成後的回調 Scheme（可選）
///   - requestId: 請求識別碼，回調時原樣帶回（可選）
func addURL(_ urlString: String, callbackScheme: String? = nil, requestId: String? = nil) {
    // ... 現有邏輯 ...

    // 建立 DownloadTask 時設定 callbackScheme 和 requestId
    let task = DownloadTask(
        url: urlString,
        // ... 其他參數 ...
    )
    task.callbackScheme = callbackScheme
    task.requestId = requestId

    // ... 後續邏輯 ...
}
```

### 5.3 下載完成時觸發回調

在下載完成的處理邏輯中（通常在 `downloadCompleted` 或類似方法）：

```swift
// 在標記任務為 completed 之後
if let callbackScheme = task.callbackScheme,
   let filePath = task.outputPath {  // outputPath 是下載檔案的路徑
    Task {
        await CallbackService.shared.triggerCallback(
            scheme: callbackScheme,
            task: task,
            filePath: filePath
        )
    }
}
```

**找到正確位置的提示**：
- 搜尋 `status = .completed` 或 `DownloadStatus.completed`
- 或搜尋下載完成時發送通知的地方

---

## 6. 可選：確保 duration 屬性

如果 `DownloadTask` 目前沒有 `duration` 屬性，可以從 metadata 取得：

在 `YouTubeMetadataService` 取得 metadata 後，確保 `duration` 被保存到 `DownloadTask`：

```swift
// 在 fetchVideoInfo 完成後
task.duration = videoInfo.duration
```

---

## 測試步驟

### 1. 編譯並執行修改後的 Tubify

### 2. 使用終端機測試 URL Scheme

```bash
# 測試基本下載（無回調）
open "tubify://download?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ"

# 測試帶回調的下載（無 request_id）
open "tubify://download?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ&callback=whispify"

# 測試完整參數（帶 request_id）
open "tubify://download?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ&callback=whispify&request_id=550e8400-e29b-41d4-a716-446655440000"
```

### 3. 驗證行為

- [ ] Tubify 應該啟動並開始下載
- [ ] 下載進度應正常顯示
- [ ] 原有的手動新增下載功能應正常運作
- [ ] 帶 callback 的任務完成後應觸發回調
- [ ] 回調 URL 應包含 request_id（如果原始請求有提供）

---

## 注意事項

1. **向後相容**: 所有修改都是可選的。沒有 `callbackScheme` 和 `requestId` 的任務行為與之前完全相同。

2. **錯誤處理**: 如果回調失敗（例如目標 App 未安裝），Tubify 只會記錄日誌，不會影響下載功能。

3. **Sandbox**: 確保 `Tubify.entitlements` 沒有阻止 URL Scheme 的開啟。通常不需要額外權限。

4. **App 啟動**: 透過 URL Scheme 啟動 Tubify 時，App 會被帶到前景，使用者可以看到下載進度。

5. **持久化**: `callbackScheme` 和 `requestId` 會被持久化到 `tasks.json`，確保 App 重啟後仍能正確回調。

---

## 相關檔案參考

| 功能 | 現有檔案 | 參考 |
|------|----------|------|
| 日誌記錄 | `Utilities/Logger.swift` | 使用 `Logger.shared` |
| 下載邏輯 | `Services/YTDLPService.swift` | 了解下載完成判斷 |
| Metadata | `Services/YouTubeMetadataService.swift` | 取得 title、duration |
| 持久化 | `Services/PersistenceService.swift` | 確保新欄位被保存 |

---

## 回調 URL 範例

假設下載任務：
- `requestId`: `550e8400-e29b-41d4-a716-446655440000`
- `callbackScheme`: `whispify`
- `title`: `React 19 新功能完整介紹`
- `duration`: `1234` 秒
- `filePath`: `/Users/user/Downloads/React 19 新功能完整介紹.mp4`

回調 URL：
```
whispify://import?request_id=550e8400-e29b-41d4-a716-446655440000&file=%2FUsers%2Fuser%2FDownloads%2FReact%2019%20%E6%96%B0%E5%8A%9F%E8%83%BD%E5%AE%8C%E6%95%B4%E4%BB%8B%E7%B4%B9.mp4&title=React%2019%20%E6%96%B0%E5%8A%9F%E8%83%BD%E5%AE%8C%E6%95%B4%E4%BB%8B%E7%B4%B9&duration=1234
```
