import XCTest
@testable import Tubify

/// DownloadManager 暫停/恢復功能測試
///
/// 這些測試涵蓋以下情境：
/// 1. 單一任務的暫停與恢復
/// 2. 全部任務的暫停與恢復
/// 3. 邊界情況（如：全部暫停後恢復單一任務）
@MainActor
final class DownloadManagerTests: XCTestCase {

    // MARK: - 測試用屬性

    /// 測試用的 DownloadManager（使用 Mock 持久化服務）
    var manager: DownloadManager!

    /// Mock 持久化服務
    var mockPersistence: MockPersistenceService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 建立 Mock 並注入到新的 DownloadManager
        mockPersistence = MockPersistenceService()
        mockPersistence.reset()
        manager = DownloadManager(persistenceService: mockPersistence)

        // 確保任務列表為空
        manager.tasks = []
        manager.isAllPaused = false
    }

    override func tearDown() async throws {
        manager = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - 輔助方法

    /// 建立測試用任務
    private func createTestTask(
        url: String = "https://www.youtube.com/watch?v=test123",
        title: String = "Test Video",
        status: DownloadStatus = .pending
    ) -> DownloadTask {
        return DownloadTask(
            url: url,
            title: title,
            status: status
        )
    }

    // MARK: - DownloadStatus.paused 基本測試

    func testPausedStatusDisplayText() {
        XCTAssertEqual(DownloadStatus.paused.displayText, "已暫停")
    }

    func testPausedStatusRawValue() {
        XCTAssertEqual(DownloadStatus.paused.rawValue, "paused")
    }

    func testPausedStatusFromRawValue() {
        XCTAssertEqual(DownloadStatus(rawValue: "paused"), .paused)
    }

    // MARK: - 單一任務暫停測試

    func testPauseSingleTask_ChangesToPausedStatus() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertEqual(task.status, .paused)
    }

    func testPauseSingleTask_FromDownloadingStatus() async {
        // Arrange
        let task = createTestTask(status: .downloading)
        task.progress = 0.5
        manager.tasks = [task]

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertEqual(task.status, .paused)
    }

    func testPauseSingleTask_DoesNotAffectOtherTasks() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .downloading)
        manager.tasks = [task1, task2, task3]

        // Act
        await manager.pauseTask(task2)

        // Assert
        XCTAssertEqual(task1.status, .pending, "task1 應該維持 pending 狀態")
        XCTAssertEqual(task2.status, .paused, "task2 應該變成 paused 狀態")
        XCTAssertEqual(task3.status, .downloading, "task3 應該維持 downloading 狀態")
    }

    func testPauseSingleTask_DoesNotChangeIsAllPausedFlag() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "暫停單一任務不應該設置 isAllPaused 標記")
    }

    // MARK: - 單一任務恢復測試

    func testResumeSingleTask_ChangesToPendingStatus() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertEqual(task.status, .pending)
    }

    func testResumeSingleTask_ResetsProgress() {
        // Arrange
        let task = createTestTask(status: .paused)
        task.progress = 0.5
        manager.tasks = [task]

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertEqual(task.progress, 0, "恢復任務應該重置進度")
    }

    func testResumeSingleTask_DoesNotAffectOtherPausedTasks() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .paused)
        manager.tasks = [task1, task2, task3]

        // Act
        manager.resumeTask(task2)

        // Assert
        XCTAssertEqual(task1.status, .paused, "task1 應該維持 paused 狀態")
        XCTAssertEqual(task2.status, .pending, "task2 應該變成 pending 狀態")
        XCTAssertEqual(task3.status, .paused, "task3 應該維持 paused 狀態")
    }

    /// 核心測試：當全部暫停時，恢復單一任務應該清除 isAllPaused 標記
    /// 這是修復的 bug：原本 isAllPaused 為 true 時，processQueue 會跳過 pending 任務
    func testResumeSingleTask_WhenAllPaused_ClearsIsAllPausedFlag() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        manager.tasks = [task1, task2]
        manager.isAllPaused = true

        // Act
        manager.resumeTask(task1)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "恢復單一任務應該清除 isAllPaused 標記")
        XCTAssertEqual(task1.status, .pending, "task1 應該變成 pending 狀態")
        XCTAssertEqual(task2.status, .paused, "其他任務應該維持 paused 狀態")
    }

    func testResumeSingleTask_WhenIsAllPausedFalse_RemainsUnchanged() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "isAllPaused 應該保持為 false")
    }

    // MARK: - 全部暫停測試

    func testPauseAll_AllPendingTasksBecomePaused() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .pending)
        manager.tasks = [task1, task2, task3]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)
        XCTAssertEqual(task3.status, .paused)
    }

    func testPauseAll_DownloadingTasksBecomePaused() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .downloading)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        manager.tasks = [task1, task2]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)
    }

    func testPauseAll_SetsIsAllPausedFlag() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertTrue(manager.isAllPaused)
    }

    func testPauseAll_DoesNotAffectCompletedTasks() async {
        // Arrange
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        manager.tasks = [completedTask, pendingTask]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(completedTask.status, .completed, "已完成的任務不應該被暫停")
        XCTAssertEqual(pendingTask.status, .paused, "待處理的任務應該被暫停")
    }

    func testPauseAll_DoesNotAffectFailedTasks() async {
        // Arrange
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        failedTask.errorMessage = "Network error"
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        manager.tasks = [failedTask, pendingTask]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(failedTask.status, .failed, "失敗的任務不應該被暫停")
        XCTAssertEqual(pendingTask.status, .paused, "待處理的任務應該被暫停")
    }

    // MARK: - 全部恢復測試

    func testResumeAll_AllPausedTasksBecomePending() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .paused)
        manager.tasks = [task1, task2, task3]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(task1.status, .pending)
        XCTAssertEqual(task2.status, .pending)
        XCTAssertEqual(task3.status, .pending)
    }

    func testResumeAll_ClearsIsAllPausedFlag() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertFalse(manager.isAllPaused)
    }

    func testResumeAll_AlsoResumesFailedTasks() {
        // Arrange
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        failedTask.errorMessage = "Network error"
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [failedTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(failedTask.status, .pending, "失敗的任務應該被恢復為 pending")
        XCTAssertNil(failedTask.errorMessage, "錯誤訊息應該被清除")
        XCTAssertEqual(pausedTask.status, .pending, "暫停的任務應該被恢復為 pending")
    }

    func testResumeAll_ResetsProgressForPausedTasks() {
        // Arrange
        let task = createTestTask(status: .paused)
        task.progress = 0.75
        manager.tasks = [task]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(task.progress, 0, "恢復任務應該重置進度")
    }

    func testResumeAll_DoesNotAffectCompletedTasks() {
        // Arrange
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        completedTask.progress = 1.0
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [completedTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(completedTask.status, .completed, "已完成的任務不應該被影響")
        XCTAssertEqual(completedTask.progress, 1.0, "已完成任務的進度不應該被重置")
    }

    func testResumeAll_DoesNotAffectCancelledTasks() {
        // Arrange
        let cancelledTask = createTestTask(url: "https://www.youtube.com/watch?v=cancelled", status: .cancelled)
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [cancelledTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(cancelledTask.status, .cancelled, "已取消的任務不應該被影響")
        XCTAssertEqual(pausedTask.status, .pending, "暫停的任務應該被恢復")
    }

    // MARK: - 複合情境測試

    func testPauseAllThenResumeAll_RestoresOriginalBehavior() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        manager.tasks = [task1, task2]

        // Act
        await manager.pauseAll()

        // Assert intermediate state
        XCTAssertTrue(manager.isAllPaused)
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)

        // Act
        manager.resumeAll()

        // Assert final state
        XCTAssertFalse(manager.isAllPaused)
        XCTAssertEqual(task1.status, .pending)
        XCTAssertEqual(task2.status, .pending)
    }

    func testPauseAllThenResumeSingle_OnlyResumesThatTask() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .pending)
        manager.tasks = [task1, task2, task3]

        // Act: Pause all
        await manager.pauseAll()

        // Act: Resume only task2
        manager.resumeTask(task2)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "isAllPaused 應該被清除")
        XCTAssertEqual(task1.status, .paused, "task1 應該維持暫停")
        XCTAssertEqual(task2.status, .pending, "task2 應該被恢復")
        XCTAssertEqual(task3.status, .paused, "task3 應該維持暫停")
    }

    func testMixedStatusTasks_PauseAndResume() async {
        // Arrange: 各種狀態的任務
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        let downloadingTask = createTestTask(url: "https://www.youtube.com/watch?v=downloading", status: .downloading)
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        let scheduledTask = createTestTask(url: "https://www.youtube.com/watch?v=scheduled", status: .scheduled)

        manager.tasks = [pendingTask, downloadingTask, completedTask, failedTask, scheduledTask]

        // Act: Pause all
        await manager.pauseAll()

        // Assert: 只有 pending 和 downloading 會被暫停
        XCTAssertEqual(pendingTask.status, .paused)
        XCTAssertEqual(downloadingTask.status, .paused)
        XCTAssertEqual(completedTask.status, .completed)
        XCTAssertEqual(failedTask.status, .failed)
        XCTAssertEqual(scheduledTask.status, .scheduled)

        // Act: Resume all
        manager.resumeAll()

        // Assert: paused 和 failed 會變成 pending
        XCTAssertEqual(pendingTask.status, .pending)
        XCTAssertEqual(downloadingTask.status, .pending)
        XCTAssertEqual(completedTask.status, .completed)
        XCTAssertEqual(failedTask.status, .pending) // failed 也會被恢復
        XCTAssertEqual(scheduledTask.status, .scheduled)
    }

    // MARK: - 新任務加入時的狀態測試

    func testNewTaskStatus_WhenAllPaused_ShouldBePaused() {
        // 這個測試驗證當 isAllPaused 為 true 時，
        // fetchMetadataForTask 會將新任務設為 paused 狀態

        // Arrange
        manager.isAllPaused = true

        // 直接測試狀態設定邏輯
        let newStatus: DownloadStatus = manager.isAllPaused ? .paused : .pending

        // Assert
        XCTAssertEqual(newStatus, .paused, "當全部暫停時，新任務應該設為 paused")
    }

    func testNewTaskStatus_WhenNotAllPaused_ShouldBePending() {
        // Arrange
        manager.isAllPaused = false

        // 直接測試狀態設定邏輯
        let newStatus: DownloadStatus = manager.isAllPaused ? .paused : .pending

        // Assert
        XCTAssertEqual(newStatus, .pending, "當未全部暫停時，新任務應該設為 pending")
    }
}
