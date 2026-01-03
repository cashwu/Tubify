import SwiftUI

@main
struct TubifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
}
