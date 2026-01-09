import Foundation
import os.log

/// Tubify 專用日誌記錄器
enum TubifyLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tubify"

    /// 一般日誌
    static let general = Logger(subsystem: subsystem, category: "general")

    /// 下載相關日誌
    static let download = Logger(subsystem: subsystem, category: "download")

    /// yt-dlp 相關日誌
    static let ytdlp = Logger(subsystem: subsystem, category: "ytdlp")

    /// 持久化相關日誌
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// UI 相關日誌
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Cookies 相關日誌
    static let cookies = Logger(subsystem: subsystem, category: "cookies")
}

/// 日誌檔案管理
class LogFileManager {
    static let shared = LogFileManager()

    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private let lock = NSLock()

    private init() {
        // 建立日誌目錄 ~/Library/Logs/Tubify/
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        logDirectory = libraryURL.appendingPathComponent("Logs/Tubify")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        createLogDirectoryIfNeeded()
    }

    private func createLogDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: logDirectory.path) {
            do {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
                TubifyLogger.general.info("建立日誌目錄: \(self.logDirectory.path)")
            } catch {
                TubifyLogger.general.error("無法建立日誌目錄: \(error.localizedDescription)")
            }
        }
    }

    /// 目前的日誌檔案路徑
    var currentLogFileURL: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "tubify-\(dateFormatter.string(from: Date())).log"
        return logDirectory.appendingPathComponent(fileName)
    }

    /// 寫入日誌到檔案
    func writeToFile(_ message: String, level: String = "INFO") {
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level)] \(message)\n"

        let fileURL = currentLogFileURL

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try logLine.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            TubifyLogger.general.error("無法寫入日誌檔案: \(error.localizedDescription)")
        }
    }

    /// 記錄下載開始
    func logDownloadStart(url: String, taskId: UUID) {
        let message = "下載開始 - TaskID: \(taskId.uuidString), URL: \(url)"
        writeToFile(message)
        TubifyLogger.download.info("\(message)")
    }

    /// 記錄下載完成
    func logDownloadComplete(taskId: UUID, outputPath: String) {
        let message = "下載完成 - TaskID: \(taskId.uuidString), Output: \(outputPath)"
        writeToFile(message)
        TubifyLogger.download.info("\(message)")
    }

    /// 記錄下載錯誤
    func logDownloadError(taskId: UUID, error: String) {
        let message = "下載錯誤 - TaskID: \(taskId.uuidString), Error: \(error)"
        writeToFile(message, level: "ERROR")
        TubifyLogger.download.error("\(message)")
    }

    /// 記錄 yt-dlp 輸出
    func logYTDLPOutput(taskId: UUID, output: String) {
        let message = "yt-dlp - TaskID: \(taskId.uuidString), Output: \(output)"
        writeToFile(message, level: "DEBUG")
        TubifyLogger.ytdlp.debug("\(message)")
    }

    /// 清理舊日誌（保留最近 7 天）
    func cleanOldLogs(daysToKeep: Int = 7) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -daysToKeep, to: Date())!

        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])

            for fileURL in logFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    TubifyLogger.general.info("已刪除舊日誌: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            TubifyLogger.general.error("清理舊日誌時發生錯誤: \(error.localizedDescription)")
        }
    }
}
