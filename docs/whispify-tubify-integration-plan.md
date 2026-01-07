# Whispify Mac - Tubify 整合實作計畫

本文件說明 Whispify Mac 版需要進行的修改，以支援 Tubify 整合。

---

## 核心設計

### 流程

```
1. 使用者貼上 YouTube URL
2. 顯示設定對話框（語言、模型、提示詞選項）← 先設定
3. 點擊「開始」
4. 暫存設定 + 生成 request_id
5. 呼叫 Tubify 下載
6. Tubify 下載完成後回調（帶回 request_id + metadata）
7. 用 request_id 找回設定，組合 prompt，自動建立專案
```

### Prompt 組合

| 自訂提示詞 | 附加標題 | 最終 Prompt |
|-----------|---------|-------------|
| 空 | ❌ | （空） |
| 空 | ✅ | `{title}` |
| 有內容 | ❌ | `{自訂}` |
| 有內容 | ✅ | `{自訂}\n{title}` |

---

## 修改概覽

| 檔案 | 修改類型 | 說明 |
|------|----------|------|
| `Info.plist` | 修改 | 新增 `whispify://` URL Scheme |
| `WhispifyApp.swift` | 修改 | 處理 URL Scheme 回調 |
| `Services/TubifyIntegrationService.swift` | 新增 | 與 Tubify 整合的服務 |
| `Models/PendingDownloadRequest.swift` | 新增 | 暫存設定的資料結構 |
| `Views/YouTubeDownloadSheet.swift` | 新增 | YouTube URL 輸入與設定對話框 |
| `Views/ProjectListView.swift` | 修改 | 新增「從 YouTube 下載」按鈕 |
| `DI/DependencyContainer.swift` | 修改 | 註冊新服務 |

---

## 實作細節

### 1. Info.plist - 新增 URL Scheme

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.cashwu.Whispify</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>whispify</string>
        </array>
    </dict>
</array>
```

---

### 2. 新增 PendingDownloadRequest.swift

```swift
import Foundation

/// 暫存的下載請求設定
/// 在呼叫 Tubify 前保存，回調時用 requestId 查找
struct PendingDownloadRequest: Codable {
    let requestId: UUID
    let youtubeURL: String
    let language: TranscriptionLanguage
    let modelId: UUID
    let customPrompt: String
    let appendTitleToPrompt: Bool
    let enableAutoSegmentBreaks: Bool
    let createdAt: Date

    init(
        youtubeURL: String,
        language: TranscriptionLanguage,
        modelId: UUID,
        customPrompt: String,
        appendTitleToPrompt: Bool,
        enableAutoSegmentBreaks: Bool
    ) {
        self.requestId = UUID()
        self.youtubeURL = youtubeURL
        self.language = language
        self.modelId = modelId
        self.customPrompt = customPrompt
        self.appendTitleToPrompt = appendTitleToPrompt
        self.enableAutoSegmentBreaks = enableAutoSegmentBreaks
        self.createdAt = Date()
    }

    /// 組合最終 prompt
    /// - Parameter title: 影片標題（來自 Tubify 回調）
    /// - Returns: 組合後的 prompt
    func buildFinalPrompt(title: String?) -> String {
        var parts: [String] = []

        let trimmedCustom = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustom.isEmpty {
            parts.append(trimmedCustom)
        }

        if appendTitleToPrompt, let title = title, !title.isEmpty {
            parts.append(title)
        }

        return parts.joined(separator: "\n")
    }
}
```

---

### 3. 新增 TubifyIntegrationService.swift

```swift
import Foundation
import AppKit
import SwiftData

/// 與 Tubify 整合的服務
@MainActor
@Observable
final class TubifyIntegrationService {

    /// 暫存的下載請求（key: requestId）
    private var pendingRequests: [UUID: PendingDownloadRequest] = [:]

    /// 過期時間（24 小時）
    private let expirationInterval: TimeInterval = 24 * 60 * 60

    /// 持久化 key
    private let storageKey = "pendingDownloadRequests"

    init() {
        loadPendingRequests()
        cleanExpiredRequests()
    }

    // MARK: - Tubify 檢查

    /// 檢查 Tubify 是否已安裝
    var isTubifyInstalled: Bool {
        guard let url = URL(string: "tubify://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    // MARK: - 發起下載

    /// 建立暫存請求並呼叫 Tubify 下載
    /// - Parameter request: 下載請求設定
    func startDownload(request: PendingDownloadRequest) {
        // 暫存設定
        pendingRequests[request.requestId] = request
        savePendingRequests()

        // 建構 Tubify URL
        var components = URLComponents()
        components.scheme = "tubify"
        components.host = "download"
        components.queryItems = [
            URLQueryItem(name: "url", value: request.youtubeURL),
            URLQueryItem(name: "callback", value: "whispify"),
            URLQueryItem(name: "request_id", value: request.requestId.uuidString)
        ]

        guard let url = components.url else {
            LoggerService.shared.error("無法建構 Tubify URL")
            return
        }

        LoggerService.shared.info("呼叫 Tubify: \(url.absoluteString)")
        NSWorkspace.shared.open(url)
    }

    // MARK: - 處理回調

    /// 從 Tubify 回調中取得暫存的請求
    /// - Parameter requestId: 請求 ID
    /// - Returns: 暫存的請求（如果存在）
    func getPendingRequest(requestId: UUID) -> PendingDownloadRequest? {
        return pendingRequests[requestId]
    }

    /// 移除已處理的請求
    /// - Parameter requestId: 請求 ID
    func removePendingRequest(requestId: UUID) {
        pendingRequests.removeValue(forKey: requestId)
        savePendingRequests()
    }

    // MARK: - 持久化

    private func savePendingRequests() {
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadPendingRequests() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let requests = try? JSONDecoder().decode([UUID: PendingDownloadRequest].self, from: data) else {
            return
        }
        pendingRequests = requests
    }

    private func cleanExpiredRequests() {
        let now = Date()
        pendingRequests = pendingRequests.filter { _, request in
            now.timeIntervalSince(request.createdAt) < expirationInterval
        }
        savePendingRequests()
    }
}
```

---

### 4. 修改 WhispifyApp.swift

在 App 結構中處理 URL：

```swift
@main
struct WhispifyApp: App {
    @State private var dependencies = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencies, dependencies)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "whispify",
              url.host == "import" else { return }

        Task { @MainActor in
            await handleImportCallback(url: url)
        }
    }

    @MainActor
    private func handleImportCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        // 解析參數
        var requestIdString: String?
        var filePath: String?
        var title: String?
        var duration: TimeInterval?

        for item in queryItems {
            switch item.name {
            case "request_id":
                requestIdString = item.value
            case "file":
                filePath = item.value?.removingPercentEncoding
            case "title":
                title = item.value?.removingPercentEncoding
            case "duration":
                if let value = item.value, let seconds = Double(value) {
                    duration = seconds
                }
            default:
                break
            }
        }

        guard let filePath = filePath else {
            LoggerService.shared.error("回調缺少 file 參數")
            return
        }

        // 驗證檔案存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            LoggerService.shared.error("檔案不存在: \(filePath)")
            // TODO: 顯示錯誤提示
            return
        }

        // 查找暫存的設定
        guard let requestIdString = requestIdString,
              let requestId = UUID(uuidString: requestIdString),
              let pendingRequest = dependencies.tubifyIntegrationService.getPendingRequest(requestId: requestId) else {
            LoggerService.shared.error("找不到對應的請求設定: \(requestIdString ?? "nil")")
            // TODO: 降級處理或顯示錯誤
            return
        }

        // 組合最終 prompt
        let finalPrompt = pendingRequest.buildFinalPrompt(title: title)

        // 建立專案
        let projectName = title ?? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

        // 取得 ModelContext（需要從適當的地方取得）
        // 這裡假設有一個方法可以取得
        await createProject(
            name: projectName,
            filePath: filePath,
            duration: duration,
            request: pendingRequest,
            finalPrompt: finalPrompt
        )

        // 清理暫存
        dependencies.tubifyIntegrationService.removePendingRequest(requestId: requestId)

        // 將 App 帶到前景
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func createProject(
        name: String,
        filePath: String,
        duration: TimeInterval?,
        request: PendingDownloadRequest,
        finalPrompt: String
    ) async {
        // 這裡需要存取 SwiftData ModelContext
        // 實際實作時需要調整架構

        // 建立專案
        let project = TranscriptionProject(
            name: name,
            videoPath: filePath,
            language: request.language,
            selectedModelId: request.modelId,
            customPrompt: finalPrompt,
            enableAutoSegmentBreaks: request.enableAutoSegmentBreaks,
            thumbnailData: nil
        )

        if let duration = duration {
            project.videoDuration = duration
        }

        // 設定佇列順序並加入佇列
        // ... (需要 ModelContext)

        // 自動啟動轉錄佇列
        if !dependencies.transcriptionQueueService.isProcessing {
            dependencies.transcriptionQueueService.startQueue()
        }

        LoggerService.shared.info("已建立轉錄專案: \(name)")
    }
}
```

---

### 5. 新增 YouTubeDownloadSheet.swift

```swift
import SwiftUI
import SwiftData

/// YouTube 下載與轉錄設定對話框
struct YouTubeDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var urlText = ""
    @State private var selectedLanguage: TranscriptionLanguage = .english
    @State private var selectedModelId: UUID?
    @State private var customPrompt = ""
    @State private var appendTitleToPrompt = true
    @State private var enableAutoSegmentBreaks = true
    @State private var errorMessage: String?

    @Query(sort: \WhisperModel.sortOrder) private var models: [WhisperModel]

    private var availableModels: [WhisperModel] {
        models.filter { $0.isDownloaded }
    }

    private var isValidURL: Bool {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.contains("youtube.com") || text.contains("youtu.be")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題
            Text("從 YouTube 下載")
                .font(.headline)
                .padding()

            Divider()

            Form {
                // YouTube URL
                Section("YouTube 網址") {
                    TextField("https://www.youtube.com/watch?v=...", text: $urlText)
                        .textFieldStyle(.roundedBorder)

                    if !dependencies.tubifyIntegrationService.isTubifyInstalled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("請先安裝 Tubify")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                // 轉錄設定
                Section("轉錄設定") {
                    Picker("語言", selection: $selectedLanguage) {
                        ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }

                    Picker("模型", selection: $selectedModelId) {
                        Text("請選擇").tag(nil as UUID?)
                        ForEach(availableModels) { model in
                            Text(model.name).tag(model.id as UUID?)
                        }
                    }

                    if availableModels.isEmpty {
                        Text("尚無可用模型，請先下載模型")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                // 提示詞設定
                Section("提示詞設定") {
                    TextField("自訂提示詞（選填）", text: $customPrompt, axis: .vertical)
                        .lineLimit(2...4)

                    Toggle("附加影片標題到提示詞", isOn: $appendTitleToPrompt)

                    if appendTitleToPrompt {
                        Text("下載完成後，會自動將影片標題加入提示詞")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 進階設定
                Section("進階設定") {
                    Toggle("自動斷句", isOn: $enableAutoSegmentBreaks)
                }
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            // 按鈕
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("開始下載並轉錄") {
                    startDownload()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidURL || selectedModelId == nil || !dependencies.tubifyIntegrationService.isTubifyInstalled)
            }
            .padding()
        }
        .frame(width: 450, height: 520)
        .onAppear {
            if selectedModelId == nil {
                selectedModelId = availableModels.first?.id
            }
        }
    }

    private func startDownload() {
        guard let modelId = selectedModelId else { return }

        let request = PendingDownloadRequest(
            youtubeURL: urlText.trimmingCharacters(in: .whitespacesAndNewlines),
            language: selectedLanguage,
            modelId: modelId,
            customPrompt: customPrompt,
            appendTitleToPrompt: appendTitleToPrompt,
            enableAutoSegmentBreaks: enableAutoSegmentBreaks
        )

        dependencies.tubifyIntegrationService.startDownload(request: request)
        dismiss()
    }
}
```

---

### 6. 修改 ProjectListView.swift

在工具列新增按鈕：

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button("選擇檔案...") {
                showAddSheet = true
            }

            Divider()

            Button("從 YouTube 下載...") {
                showYouTubeSheet = true
            }
            .disabled(!dependencies.tubifyIntegrationService.isTubifyInstalled)

        } label: {
            Image(systemName: "plus")
        }
    }
}
.sheet(isPresented: $showYouTubeSheet) {
    YouTubeDownloadSheet()
}
```

新增狀態變數：

```swift
@State private var showYouTubeSheet = false
```

---

### 7. 修改 DependencyContainer.swift

註冊新服務：

```swift
@MainActor
@Observable
final class DependencyContainer {
    // ... 現有服務 ...

    var tubifyIntegrationService: TubifyIntegrationService

    init() {
        // ... 現有初始化 ...

        self.tubifyIntegrationService = TubifyIntegrationService()
    }
}
```

---

## UI 流程圖

```
┌─────────────────────────────────────────────────────────────────────┐
│                       ProjectListView                                │
│  ┌─────────────────┐                                                │
│  │  ＋ (Menu)      │                                                │
│  │  ├─ 選擇檔案... │ ← 現有功能                                      │
│  │  └─ 從 YouTube  │ ← 新增                                         │
│  └─────────────────┘                                                │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    YouTubeDownloadSheet                              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  YouTube 網址                                                │    │
│  │  [https://youtube.com/watch?v=xxx                        ]   │    │
│  │                                                              │    │
│  │  語言: [English ▼]                                           │    │
│  │  模型: [large-v3 ▼]                                          │    │
│  │                                                              │    │
│  │  自訂提示詞: [請注意專有名詞...                           ]   │    │
│  │  ☑ 附加影片標題到提示詞                                      │    │
│  │  ☑ 自動斷句                                                  │    │
│  │                                                              │    │
│  │  [取消]                       [開始下載並轉錄]                │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   │ 呼叫 tubify://download?...
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Tubify App                                   │
│              （使用者在這裡看到下載進度）                              │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   │ 回調 whispify://import?...
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Whispify                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  自動建立專案                                                 │    │
│  │  - 名稱: {影片標題}                                           │    │
│  │  - Prompt: {自訂} + {標題}（如果有勾選）                       │    │
│  │  - 時長: {duration}                                          │    │
│  │  - 自動加入轉錄佇列                                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 重新轉錄時的 Metadata 顯示

當專案已經有 `videoDuration` 時，重新轉錄的設定頁面應該顯示時長。

修改現有的轉錄設定 View（如 `QuickAddFileSheet` 或專案設定頁面）：

```swift
// 顯示時長（如果有）
if let duration = project.videoDuration {
    LabeledContent("時長") {
        Text(formatDuration(duration))
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, secs)
}
```

---

## 實作順序建議

1. **Phase 1 - 基礎設施**
   - [ ] 修改 `Info.plist` 新增 URL Scheme
   - [ ] 新增 `PendingDownloadRequest` 模型
   - [ ] 新增 `TubifyIntegrationService`
   - [ ] 修改 `DependencyContainer` 註冊服務

2. **Phase 2 - URL 處理**
   - [ ] 修改 `WhispifyApp` 處理回調
   - [ ] 實作 `handleImportCallback` 方法

3. **Phase 3 - UI**
   - [ ] 新增 `YouTubeDownloadSheet`
   - [ ] 修改 `ProjectListView` 新增按鈕

4. **Phase 4 - 測試**
   - [ ] 測試 Tubify 未安裝時的提示
   - [ ] 測試完整下載→轉錄流程
   - [ ] 測試 prompt 組合邏輯
   - [ ] 測試 App 重啟後回調處理

---

## 注意事項

1. **Tubify 需先完成修改**: Whispify 的整合依賴 Tubify 的 URL Scheme 支援。

2. **Sandbox 權限**: 確保 Whispify 可以存取 Tubify 的下載目錄（通常是 `~/Downloads`）。可能需要在 entitlements 中設定。

3. **ModelContext 存取**: `handleImportCallback` 需要存取 SwiftData 的 ModelContext。實際實作時可能需要調整架構，例如透過 Environment 或依賴注入。

4. **錯誤處理**: 需要處理各種邊界情況（檔案不存在、格式不支援、request_id 找不到等）。

5. **使用者體驗**: 考慮在等待 Tubify 下載時顯示狀態提示（例如在專案列表顯示「等待下載中」的項目）。
