import AppKit
import SwiftUI
import XCTest
@testable import Tubify

/// ContentView 測試
final class ContentViewTests: XCTestCase {

    // MARK: - Paste routing tests

    func testPasteRoutingConsumesCommandVInMainDownloadWindowWithoutTextResponder() {
        let shouldConsume = shouldConsumePasteEvent(
            isCommandV: true,
            windowIdentifier: mainDownloadWindowIdentifier,
            firstResponderIsTextInput: false
        )

        XCTAssertTrue(shouldConsume)
    }

    func testPasteRoutingPreservesCommandVForTextResponderInMainDownloadWindow() {
        let shouldConsume = shouldConsumePasteEvent(
            isCommandV: true,
            windowIdentifier: mainDownloadWindowIdentifier,
            firstResponderIsTextInput: true
        )

        XCTAssertFalse(shouldConsume)
    }

    func testPasteRoutingPreservesCommandVInSettingsWindowWithoutTextResponder() {
        let shouldConsume = shouldConsumePasteEvent(
            isCommandV: true,
            windowIdentifier: NSUserInterfaceItemIdentifier("Tubify.settings"),
            firstResponderIsTextInput: false
        )

        XCTAssertFalse(shouldConsume)
    }

    @MainActor
    func testPasteMonitorControllerInstallsAndUninstallsOnlyOncePerLifecycle() {
        var installCount = 0
        var removedTokens: [AnyObject] = []
        let token = NSObject()
        let controller = PasteMonitorController(
            addMonitor: { _, _ in
                installCount += 1
                return token
            },
            removeMonitor: { removedTokens.append($0 as AnyObject) }
        )

        controller.install { $0 }
        controller.install { $0 }

        XCTAssertEqual(installCount, 1)

        controller.uninstall()
        controller.uninstall()

        XCTAssertEqual(removedTokens.count, 1)
        XCTAssertTrue(removedTokens.first === token)

        controller.install { $0 }
        controller.install { $0 }

        XCTAssertEqual(installCount, 2)

        controller.uninstall()
        XCTAssertEqual(removedTokens.count, 2)
    }

    @MainActor
    func testMainWindowMarkerIsRestoredWhenWindowBecomesKeyAgain() async {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        defer { window.contentViewController = nil }
        window.contentViewController = NSHostingController(rootView: ContentView())
        window.contentView?.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(window.identifier, mainDownloadWindowIdentifier)

        window.identifier = NSUserInterfaceItemIdentifier("SwiftUI.restoredWindow")
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)

        XCTAssertEqual(window.identifier, mainDownloadWindowIdentifier)
    }

    // MARK: - buildTaskCountText 測試

    func testTaskCountTextWithEmptyTasks() {
        let result = ContentView.buildTaskCountText(from: [])
        XCTAssertEqual(result, "沒有下載任務")
    }

    func testTaskCountTextWithSingleTask() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .pending)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 等待中 1")
    }

    func testTaskCountTextWithDownloadingStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .downloading)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 下載中 1")
    }

    func testTaskCountTextWithLivestreamingStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .livestreaming)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 串流中 1")
    }

    func testTaskCountTextWithPostLiveStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .postLive)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 處理中 1")
    }

    func testDownloadItemViewPostLiveStatusTextAndRetryControl() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .postLive)

        XCTAssertEqual(DownloadItemView.statusText(for: task), "直播處理中 (請稍後重試)")
        XCTAssertTrue(DownloadItemView.showsRetryControl(for: task))
    }

    func testTaskCountTextWithScheduledStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .scheduled)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 首播 1")
    }

    func testTaskCountTextWithMixedStatuses() {
        let tasks = [
            DownloadTask(url: "https://www.youtube.com/watch?v=1", status: .downloading),
            DownloadTask(url: "https://www.youtube.com/watch?v=2", status: .pending),
            DownloadTask(url: "https://www.youtube.com/watch?v=3", status: .scheduled),
            DownloadTask(url: "https://www.youtube.com/watch?v=4", status: .livestreaming),
            DownloadTask(url: "https://www.youtube.com/watch?v=5", status: .postLive),
            DownloadTask(url: "https://www.youtube.com/watch?v=6", status: .completed)
        ]
        let result = ContentView.buildTaskCountText(from: tasks)
        XCTAssertEqual(result, "共 6 個 · 下載中 1 · 等待中 1 · 首播 1 · 串流中 1 · 處理中 1 · 已完成 1")
    }

    func testTaskCountTextWithMultipleSameStatus() {
        let tasks = [
            DownloadTask(url: "https://www.youtube.com/watch?v=1", status: .livestreaming),
            DownloadTask(url: "https://www.youtube.com/watch?v=2", status: .livestreaming),
            DownloadTask(url: "https://www.youtube.com/watch?v=3", status: .scheduled)
        ]
        let result = ContentView.buildTaskCountText(from: tasks)
        XCTAssertEqual(result, "共 3 個 · 首播 1 · 串流中 2")
    }

    func testTaskCountTextWithPausedStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .paused)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 暫停 1")
    }

    func testTaskCountTextWithCompletedStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123", status: .completed)
        let result = ContentView.buildTaskCountText(from: [task])
        XCTAssertEqual(result, "共 1 個 · 已完成 1")
    }
}
