import Foundation

/// 線程安全的下載結果容器
final class DownloadResultHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var _outputPath: String?
    private var _lastError: String?

    var outputPath: String? {
        lock.lock()
        defer { lock.unlock() }
        return _outputPath
    }

    var lastError: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastError
    }

    func setOutputPath(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        _outputPath = path
    }

    func setError(_ error: String) {
        lock.lock()
        defer { lock.unlock() }
        _lastError = error
    }
}

/// yt-dlp 服務錯誤類型
enum YTDLPError: Error, LocalizedError {
    case notFound
    case executionFailed(String)
    case parseError(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "找不到 yt-dlp。請確保已安裝 yt-dlp (brew install yt-dlp)"
        case .executionFailed(let message):
            return "執行 yt-dlp 失敗: \(message)"
        case .parseError(let message):
            return "解析輸出失敗: \(message)"
        case .cancelled:
            return "下載已取消"
        }
    }
}

/// 下載進度回調
typealias ProgressCallback = (Double) -> Void

/// yt-dlp 服務
actor YTDLPService {
    static let shared = YTDLPService()

    private var runningProcesses: [UUID: Process] = [:]

    private init() {}

    /// 尋找 yt-dlp 可執行檔路徑
    func findYTDLPPath() async -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/yt-dlp",      // Apple Silicon Homebrew
            "/usr/local/bin/yt-dlp",          // Intel Homebrew
            "/usr/bin/yt-dlp"                 // 系統安裝
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                TubifyLogger.ytdlp.info("找到 yt-dlp: \(path)")
                return path
            }
        }

        // 嘗試使用 which 指令
        if let whichPath = try? await executeCommand("/usr/bin/which", arguments: ["yt-dlp"]) {
            let trimmedPath = whichPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPath.isEmpty && FileManager.default.fileExists(atPath: trimmedPath) {
                TubifyLogger.ytdlp.info("透過 which 找到 yt-dlp: \(trimmedPath)")
                return trimmedPath
            }
        }

        TubifyLogger.ytdlp.error("找不到 yt-dlp")
        return nil
    }

    /// 執行指令並返回輸出
    private func executeCommand(_ command: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 下載影片
    func download(
        taskId: UUID,
        url: String,
        commandTemplate: String,
        outputDirectory: String,
        onProgress: @escaping ProgressCallback
    ) async throws -> String {
        guard let ytdlpPath = await findYTDLPPath() else {
            throw YTDLPError.notFound
        }

        // 解析命令模板
        let command = commandTemplate.replacingOccurrences(of: "$youtubeUrl", with: url)
        let arguments = parseCommandArguments(command)

        // 加入輸出路徑參數
        var finalArguments = arguments
        if !finalArguments.contains("-o") && !finalArguments.contains("--output") {
            finalArguments.append("-o")
            finalArguments.append("\(outputDirectory)/%(title)s.%(ext)s")
        }

        // 確保有 --newline 參數以便解析進度
        if !finalArguments.contains("--newline") {
            finalArguments.append("--newline")
        }

        LogFileManager.shared.logDownloadStart(url: url, taskId: taskId)
        TubifyLogger.ytdlp.info("開始下載: \(url)")
        TubifyLogger.ytdlp.debug("命令: \(ytdlpPath) \(finalArguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        process.arguments = finalArguments
        process.currentDirectoryURL = URL(fileURLWithPath: outputDirectory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 儲存 process 以便取消
        runningProcesses[taskId] = process

        // 使用線程安全的容器來儲存結果
        let resultHolder = DownloadResultHolder()

        // 處理輸出
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            for line in output.components(separatedBy: .newlines) {
                guard !line.isEmpty else { continue }

                LogFileManager.shared.logYTDLPOutput(taskId: taskId, output: line)

                // 解析進度
                if let progress = self?.parseProgress(from: line) {
                    Task { @MainActor in
                        onProgress(progress)
                    }
                }

                // 解析輸出檔案路徑
                if line.contains("[download] Destination:") {
                    let path = line.replacingOccurrences(of: "[download] Destination: ", with: "")
                    resultHolder.setOutputPath(path)
                } else if line.contains("[Merger] Merging formats into") {
                    let path = line.replacingOccurrences(of: "[Merger] Merging formats into \"", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                    resultHolder.setOutputPath(path)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                LogFileManager.shared.logYTDLPOutput(taskId: taskId, output: "[stderr] \(line)")
                if line.contains("ERROR") {
                    resultHolder.setError(line)
                }
            }
        }

        do {
            try process.run()
        } catch {
            runningProcesses.removeValue(forKey: taskId)
            throw YTDLPError.executionFailed(error.localizedDescription)
        }

        // 等待完成
        process.waitUntilExit()

        // 清理
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        runningProcesses.removeValue(forKey: taskId)

        // 檢查結果
        if process.terminationStatus != 0 {
            let errorMessage = resultHolder.lastError ?? "未知錯誤 (退出碼: \(process.terminationStatus))"
            LogFileManager.shared.logDownloadError(taskId: taskId, error: errorMessage)
            throw YTDLPError.executionFailed(errorMessage)
        }

        if let finalPath = resultHolder.outputPath {
            LogFileManager.shared.logDownloadComplete(taskId: taskId, outputPath: finalPath)
            return finalPath
        }

        // 嘗試從輸出目錄找最新的檔案
        let files = try? FileManager.default.contentsOfDirectory(atPath: outputDirectory)
        let latestFile = files?.sorted().last
        if let file = latestFile {
            return "\(outputDirectory)/\(file)"
        }
        throw YTDLPError.parseError("無法確定輸出檔案路徑")
    }

    /// 取消下載
    func cancel(taskId: UUID) {
        if let process = runningProcesses[taskId] {
            process.terminate()
            runningProcesses.removeValue(forKey: taskId)
            TubifyLogger.ytdlp.info("已取消下載: \(taskId.uuidString)")
        }
    }

    /// 解析命令參數
    private func parseCommandArguments(_ command: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in command {
            if char == "\"" || char == "'" {
                if inQuotes && char == quoteChar {
                    inQuotes = false
                } else if !inQuotes {
                    inQuotes = true
                    quoteChar = char
                } else {
                    current.append(char)
                }
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    arguments.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            arguments.append(current)
        }

        // 移除 yt-dlp 本身（如果存在）
        if let first = arguments.first, first.contains("yt-dlp") {
            arguments.removeFirst()
        }

        return arguments
    }

    /// 解析進度（nonisolated 因為不需要訪問 actor 狀態）
    nonisolated private func parseProgress(from line: String) -> Double? {
        // 格式: [download]  45.2% of 100.00MiB at 5.00MiB/s ETA 00:11
        let pattern = #"\[download\]\s+(\d+\.?\d*)%"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let percentString = String(line[range])
        guard let percent = Double(percentString) else { return nil }

        return percent / 100.0
    }
}
