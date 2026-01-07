import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let externalDownloadRequest = Notification.Name("externalDownloadRequest")
}

@main
struct TubifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))  // 所有外部事件由現有窗口處理
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .appSettings) {
                Button("設定...") {
                    NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 請求通知權限
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }

        // 清理舊日誌
        LogFileManager.shared.cleanOldLogs()

        TubifyLogger.general.info("Tubify 已啟動")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 儲存任務
        Task { @MainActor in
            PersistenceService.shared.saveTasks(DownloadManager.shared.tasks)
        }

        TubifyLogger.general.info("Tubify 已關閉")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

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
            TubifyLogger.general.warning("未知的 URL action: \(url.host ?? "nil")")
        }
    }

    private func handleDownloadURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            TubifyLogger.general.error("無法解析 URL 參數")
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
            TubifyLogger.general.error("缺少必要的 url 參數")
            return
        }

        TubifyLogger.general.info("收到外部下載請求: \(videoURL), callback: \(callbackScheme ?? "無"), request_id: \(requestId ?? "無")")

        // 確保只使用現有窗口（避免 SwiftUI WindowGroup 創建新窗口）
        // 找到主窗口（ContentView 的窗口，排除 Settings 窗口）
        // 注意：最小化的視窗 isVisible = false，所以也要檢查 isMiniaturized
        let contentWindows = NSApplication.shared.windows.filter { window in
            // 排除 Settings 窗口和其他系統窗口
            (window.isVisible || window.isMiniaturized) && !window.title.contains("設定")
        }

        // 如果有多個窗口，關閉多餘的
        if contentWindows.count > 1 {
            for window in contentWindows.dropFirst() {
                window.close()
            }
        }

        // 將主窗口帶到前景（如果是最小化的，先還原）
        if let mainWindow = contentWindows.first {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
        }

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
}
