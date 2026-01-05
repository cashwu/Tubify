import Foundation

/// 持久化服務
class PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default
    private let appSupportDirectory: URL
    private let tasksFileURL: URL

    private init() {
        // 建立 Application Support 目錄
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDirectory = appSupport.appendingPathComponent("Tubify")
        tasksFileURL = appSupportDirectory.appendingPathComponent("tasks.json")

        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: appSupportDirectory.path) {
            do {
                try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
                TubifyLogger.persistence.info("建立 Application Support 目錄: \(self.appSupportDirectory.path)")
            } catch {
                TubifyLogger.persistence.error("無法建立 Application Support 目錄: \(error.localizedDescription)")
            }
        }
    }

    /// 儲存下載任務
    func saveTasks(_ tasks: [DownloadTask]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(tasks)
            try data.write(to: tasksFileURL)

            TubifyLogger.persistence.info("已儲存 \(tasks.count) 個任務")
        } catch {
            TubifyLogger.persistence.error("儲存任務失敗: \(error.localizedDescription)")
        }
    }

    /// 載入下載任務
    func loadTasks() -> [DownloadTask] {
        guard fileManager.fileExists(atPath: tasksFileURL.path) else {
            TubifyLogger.persistence.info("沒有已儲存的任務")
            return []
        }

        do {
            let data = try Data(contentsOf: tasksFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let tasks = try decoder.decode([DownloadTask].self, from: data)

            // 重置下載中的任務為等待中
            for task in tasks {
                if task.status == .downloading || task.status == .fetchingInfo {
                    task.status = .pending
                    task.progress = 0
                }
            }

            TubifyLogger.persistence.info("已載入 \(tasks.count) 個任務")
            return tasks
        } catch {
            TubifyLogger.persistence.error("載入任務失敗: \(error.localizedDescription)")
            return []
        }
    }

    /// 清除所有已儲存的任務
    func clearTasks() {
        do {
            if fileManager.fileExists(atPath: tasksFileURL.path) {
                try fileManager.removeItem(at: tasksFileURL)
                TubifyLogger.persistence.info("已清除所有已儲存的任務")
            }
        } catch {
            TubifyLogger.persistence.error("清除任務失敗: \(error.localizedDescription)")
        }
    }
}
