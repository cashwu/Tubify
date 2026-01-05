import Foundation
@testable import Tubify

/// 測試用的 Mock 持久化服務 - 將資料存在記憶體中
class MockPersistenceService: PersistenceServiceProtocol {

    /// Mock 儲存的任務
    var savedTasks: [DownloadTask] = []

    /// 追蹤方法呼叫
    var saveTasksCalled = false
    var loadTasksCalled = false
    var clearTasksCalled = false

    /// 重置 Mock 狀態
    func reset() {
        savedTasks = []
        saveTasksCalled = false
        loadTasksCalled = false
        clearTasksCalled = false
    }

    func saveTasks(_ tasks: [DownloadTask]) {
        saveTasksCalled = true
        savedTasks = tasks
    }

    func loadTasks() -> [DownloadTask] {
        loadTasksCalled = true
        return savedTasks
    }

    func clearTasks() {
        clearTasksCalled = true
        savedTasks = []
    }
}
