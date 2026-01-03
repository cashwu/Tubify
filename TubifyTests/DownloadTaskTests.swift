import XCTest
@testable import Tubify

/// DownloadTask 模型測試
final class DownloadTaskTests: XCTestCase {

    // MARK: - 初始化測試

    func testDefaultInitialization() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")

        XCTAssertEqual(task.url, "https://www.youtube.com/watch?v=abc123")
        XCTAssertEqual(task.title, "載入中...")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.progress, 0.0)
        XCTAssertNil(task.thumbnailURL)
        XCTAssertNil(task.errorMessage)
        XCTAssertNil(task.outputPath)
        XCTAssertNil(task.completedAt)
        XCTAssertNotNil(task.createdAt)
    }

    func testCustomInitialization() {
        let customId = UUID()
        let customDate = Date(timeIntervalSince1970: 1000)

        let task = DownloadTask(
            id: customId,
            url: "https://youtu.be/xyz789",
            title: "Test Video",
            thumbnailURL: "https://i.ytimg.com/vi/xyz789/mqdefault.jpg",
            status: .downloading,
            progress: 0.5,
            errorMessage: nil,
            outputPath: nil,
            createdAt: customDate,
            completedAt: nil
        )

        XCTAssertEqual(task.id, customId)
        XCTAssertEqual(task.url, "https://youtu.be/xyz789")
        XCTAssertEqual(task.title, "Test Video")
        XCTAssertEqual(task.thumbnailURL, "https://i.ytimg.com/vi/xyz789/mqdefault.jpg")
        XCTAssertEqual(task.status, .downloading)
        XCTAssertEqual(task.progress, 0.5)
        XCTAssertEqual(task.createdAt, customDate)
    }

    // MARK: - 狀態測試

    func testStatusTransitions() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")

        XCTAssertEqual(task.status, .pending)

        task.status = .fetchingInfo
        XCTAssertEqual(task.status, .fetchingInfo)

        task.status = .downloading
        XCTAssertEqual(task.status, .downloading)

        task.status = .completed
        XCTAssertEqual(task.status, .completed)
    }

    func testFailedStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")
        task.status = .failed
        task.errorMessage = "Network error"

        XCTAssertEqual(task.status, .failed)
        XCTAssertEqual(task.errorMessage, "Network error")
    }

    func testCancelledStatus() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")
        task.status = .cancelled

        XCTAssertEqual(task.status, .cancelled)
    }

    // MARK: - DownloadStatus displayText 測試

    func testStatusDisplayText() {
        XCTAssertEqual(DownloadStatus.pending.displayText, "等待中")
        XCTAssertEqual(DownloadStatus.fetchingInfo.displayText, "獲取資訊中...")
        XCTAssertEqual(DownloadStatus.downloading.displayText, "下載中")
        XCTAssertEqual(DownloadStatus.completed.displayText, "完成")
        XCTAssertEqual(DownloadStatus.failed.displayText, "失敗")
        XCTAssertEqual(DownloadStatus.cancelled.displayText, "已取消")
    }

    // MARK: - 進度測試

    func testProgressUpdate() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")

        task.progress = 0.25
        XCTAssertEqual(task.progress, 0.25)

        task.progress = 0.75
        XCTAssertEqual(task.progress, 0.75)

        task.progress = 1.0
        XCTAssertEqual(task.progress, 1.0)
    }

    // MARK: - Codable 測試

    func testEncodingAndDecoding() throws {
        let originalTask = DownloadTask(
            url: "https://www.youtube.com/watch?v=abc123",
            title: "Test Video",
            thumbnailURL: "https://i.ytimg.com/vi/abc123/mqdefault.jpg",
            status: .completed,
            progress: 1.0,
            outputPath: "/path/to/video.mp4"
        )
        originalTask.completedAt = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalTask)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedTask = try decoder.decode(DownloadTask.self, from: data)

        XCTAssertEqual(decodedTask.id, originalTask.id)
        XCTAssertEqual(decodedTask.url, originalTask.url)
        XCTAssertEqual(decodedTask.title, originalTask.title)
        XCTAssertEqual(decodedTask.thumbnailURL, originalTask.thumbnailURL)
        XCTAssertEqual(decodedTask.status, originalTask.status)
        XCTAssertEqual(decodedTask.progress, originalTask.progress)
        XCTAssertEqual(decodedTask.outputPath, originalTask.outputPath)
    }

    func testDecodingFromJSON() throws {
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "title": "Rick Astley - Never Gonna Give You Up",
            "thumbnailURL": "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
            "status": "completed",
            "progress": 1.0,
            "outputPath": "/Users/test/Downloads/Rick Astley - Never Gonna Give You Up.mp4",
            "createdAt": "2024-01-15T10:30:00Z",
            "completedAt": "2024-01-15T10:35:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(DownloadTask.self, from: json)

        XCTAssertEqual(task.url, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(task.title, "Rick Astley - Never Gonna Give You Up")
        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(task.progress, 1.0)
        XCTAssertNotNil(task.outputPath)
        XCTAssertNotNil(task.completedAt)
    }

    func testEncodingWithNilOptionalFields() throws {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // 確認可選欄位為 null 或不存在
        XCTAssertNotNil(json["url"])
        XCTAssertNotNil(json["title"])
        XCTAssertNotNil(json["status"])
    }

    // MARK: - Equatable 測試

    func testEquality() {
        let id = UUID()
        let task1 = DownloadTask(id: id, url: "https://www.youtube.com/watch?v=abc123")
        let task2 = DownloadTask(id: id, url: "https://www.youtube.com/watch?v=different")

        // 相同 ID 的任務應該相等（即使其他屬性不同）
        XCTAssertEqual(task1, task2)
    }

    func testInequality() {
        let task1 = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")
        let task2 = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")

        // 不同 ID 的任務應該不相等（即使 URL 相同）
        XCTAssertNotEqual(task1, task2)
    }

    // MARK: - Hashable 測試

    func testHashable() {
        let id = UUID()
        let task1 = DownloadTask(id: id, url: "https://www.youtube.com/watch?v=abc123")
        let task2 = DownloadTask(id: id, url: "https://www.youtube.com/watch?v=different")

        var set = Set<DownloadTask>()
        set.insert(task1)
        set.insert(task2)

        // 相同 ID 的任務在 Set 中應該只有一個
        XCTAssertEqual(set.count, 1)
    }

    func testHashableWithDifferentIDs() {
        let task1 = DownloadTask(url: "https://www.youtube.com/watch?v=abc123")
        let task2 = DownloadTask(url: "https://www.youtube.com/watch?v=xyz789")

        var set = Set<DownloadTask>()
        set.insert(task1)
        set.insert(task2)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - DownloadStatus Codable 測試

    func testStatusRawValues() {
        XCTAssertEqual(DownloadStatus.pending.rawValue, "pending")
        XCTAssertEqual(DownloadStatus.fetchingInfo.rawValue, "fetchingInfo")
        XCTAssertEqual(DownloadStatus.downloading.rawValue, "downloading")
        XCTAssertEqual(DownloadStatus.completed.rawValue, "completed")
        XCTAssertEqual(DownloadStatus.failed.rawValue, "failed")
        XCTAssertEqual(DownloadStatus.cancelled.rawValue, "cancelled")
    }

    func testStatusFromRawValue() {
        XCTAssertEqual(DownloadStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(DownloadStatus(rawValue: "fetchingInfo"), .fetchingInfo)
        XCTAssertEqual(DownloadStatus(rawValue: "downloading"), .downloading)
        XCTAssertEqual(DownloadStatus(rawValue: "completed"), .completed)
        XCTAssertEqual(DownloadStatus(rawValue: "failed"), .failed)
        XCTAssertEqual(DownloadStatus(rawValue: "cancelled"), .cancelled)
        XCTAssertNil(DownloadStatus(rawValue: "invalid"))
    }
}
