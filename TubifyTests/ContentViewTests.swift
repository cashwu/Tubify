import XCTest
@testable import Tubify

/// ContentView 測試
final class ContentViewTests: XCTestCase {

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
