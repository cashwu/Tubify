import Foundation

/// 線程安全的下載結果容器
final class DownloadResultHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var _outputPath: String?
    private var _lastError: String?
    private var _downloadedFiles: [String] = []

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

    var downloadedFiles: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _downloadedFiles
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

    func addDownloadedFile(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        _downloadedFiles.append(path)
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
        subtitleSelection: SubtitleSelection? = nil,
        audioSelection: AudioSelection? = nil,
        onProgress: @escaping ProgressCallback
    ) async throws -> String {
        guard let ytdlpPath = await findYTDLPPath() else {
            throw YTDLPError.notFound
        }

        // 如果指令包含 --cookies-from-browser safari，使用 SafariCookiesService 轉換
        // 這是因為 yt-dlp 子進程沒有完整磁碟存取權限，但 Tubify 有
        var processedTemplate = commandTemplate

        // 如果有選擇特定音軌語言，修改 format 字串
        if let audioSel = audioSelection, let lang = audioSel.selectedLanguage {
            processedTemplate = injectAudioLanguage(into: processedTemplate, language: lang)
            TubifyLogger.ytdlp.info("選擇音軌語言: \(lang)")
        }

        if SafariCookiesService.shared.commandNeedsSafariCookies(processedTemplate) {
            TubifyLogger.cookies.info("偵測到 Safari cookies 參數，轉換為 cookies 文件")
            processedTemplate = SafariCookiesService.shared.transformCommand(processedTemplate)
        }

        // 解析命令模板
        let command = processedTemplate.replacingOccurrences(of: "$youtubeUrl", with: url)
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

        // 加入 --print 參數，讓 yt-dlp 在下載完成後輸出最終檔案路徑
        // 使用特殊前綴以便識別
        finalArguments.append("--print")
        finalArguments.append("after_move:FINAL_PATH:%(filepath)s")

        // 加入字幕下載參數（如果有選擇字幕）
        if let selection = subtitleSelection, !selection.selectedLanguages.isEmpty {
            finalArguments.append("--write-sub")
            finalArguments.append("--sub-lang")
            finalArguments.append(selection.selectedLanguages.joined(separator: ","))
            finalArguments.append("--sub-format")
            finalArguments.append("srt")
            TubifyLogger.ytdlp.info("下載字幕: \(selection.selectedLanguages.joined(separator: ", "))")
        }

        LogFileManager.shared.logDownloadStart(url: url, taskId: taskId)
        TubifyLogger.ytdlp.info("開始下載: \(url)")
        TubifyLogger.ytdlp.debug("命令: \(ytdlpPath) \(finalArguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        process.arguments = finalArguments
        process.currentDirectoryURL = URL(fileURLWithPath: outputDirectory)

        // 設定環境變數，確保子進程可以找到 ffmpeg 等工具
        // macOS app 從 Finder 啟動時不會繼承 shell 的 PATH
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        if let existingPath = environment["PATH"] {
            environment["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        } else {
            environment["PATH"] = additionalPaths.joined(separator: ":") + ":/usr/bin:/bin"
        }
        process.environment = environment

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

                // 解析進度（不寫入日誌）
                if let progress = self?.parseProgress(from: line) {
                    Task { @MainActor in
                        onProgress(progress)
                    }
                    continue
                }

                // 非進度訊息寫入日誌
                LogFileManager.shared.logYTDLPOutput(taskId: taskId, output: line)

                // 解析輸出檔案路徑
                // 優先使用 --print 輸出的 FINAL_PATH（最可靠）
                if line.hasPrefix("FINAL_PATH:") {
                    let path = String(line.dropFirst("FINAL_PATH:".count))
                    TubifyLogger.ytdlp.info("從 --print 取得最終路徑: \(path)")
                    resultHolder.setOutputPath(path)
                } else if line.contains("[download] Destination:") {
                    let path = line.replacingOccurrences(of: "[download] Destination: ", with: "")
                    resultHolder.addDownloadedFile(path)
                    // 只有在還沒有設定 outputPath 時才設定（FINAL_PATH 優先）
                    if resultHolder.outputPath == nil {
                        resultHolder.setOutputPath(path)
                    }
                } else if line.contains("[Merger] Merging formats into") {
                    let path = line.replacingOccurrences(of: "[Merger] Merging formats into \"", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                    // 只有在還沒有設定 outputPath 時才設定（FINAL_PATH 優先）
                    if resultHolder.outputPath == nil {
                        resultHolder.setOutputPath(path)
                    }
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

        // 使用非阻塞方式等待進程完成，以允許並行下載
        let terminationStatus = await withCheckedContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
        }

        // 清理
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        runningProcesses.removeValue(forKey: taskId)

        // 檢查結果
        if terminationStatus != 0 {
            let errorMessage = resultHolder.lastError ?? "未知錯誤 (退出碼: \(terminationStatus))"
            LogFileManager.shared.logDownloadError(taskId: taskId, error: errorMessage)
            throw YTDLPError.executionFailed(errorMessage)
        }

        // 檢查是否有未合併的分離檔案（音視頻分離但合併失敗）
        // yt-dlp 合併成功後會自動刪除分離檔案，所以我們檢查這些檔案是否仍存在
        let downloadedFiles = resultHolder.downloadedFiles
        // 字幕檔不需要合併，應排除在檢查之外
        let subtitleExtensions: Set<String> = ["srt", "vtt", "ass", "ssa", "sub", "sbv", "ttml"]
        let existingMediaFiles = downloadedFiles.filter { path in
            let ext = (path as NSString).pathExtension.lowercased()
            return !subtitleExtensions.contains(ext) && FileManager.default.fileExists(atPath: path)
        }
        // 如果下載了多個媒體檔案且都還存在，表示合併失敗
        // 正常情況：純音訊下載只有 1 個檔案，合併成功後分離檔案會被刪除也只剩 1 個
        if existingMediaFiles.count > 1 {
            // 合併失敗，清理所有分離檔案
            TubifyLogger.ytdlp.error("偵測到未合併的音視頻檔案，清理分離檔案: \(existingMediaFiles)")
            for file in existingMediaFiles {
                try? FileManager.default.removeItem(atPath: file)
            }
            let errorMessage = "音視頻合併失敗，請確認 ffmpeg 已正確安裝（brew install ffmpeg）"
            LogFileManager.shared.logDownloadError(taskId: taskId, error: errorMessage)
            throw YTDLPError.executionFailed(errorMessage)
        }

        if let finalPath = resultHolder.outputPath {
            // 驗證檔案存在
            if FileManager.default.fileExists(atPath: finalPath) {
                LogFileManager.shared.logDownloadComplete(taskId: taskId, outputPath: finalPath)
                return finalPath
            } else {
                TubifyLogger.ytdlp.warning("輸出路徑不存在，嘗試尋找替代檔案: \(finalPath)")
            }
        }

        // Fallback: 如果 --print 和解析都失敗，嘗試用 title 模式尋找
        // 這是最後的手段，只找最近 60 秒內修改的檔案
        let dirURL = URL(fileURLWithPath: outputDirectory)
        let now = Date()
        let recentThreshold: TimeInterval = 60  // 只找最近 60 秒內的檔案

        if let files = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            // 只找最近修改的媒體檔案（排除 .part 和字幕檔）
            let mediaExtensions: Set<String> = ["mp4", "mkv", "webm", "m4a", "mp3", "mov"]
            let recentMediaFile = files
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return mediaExtensions.contains(ext)
                }
                .compactMap { url -> (URL, Date)? in
                    guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                          now.timeIntervalSince(date) < recentThreshold else {
                        return nil
                    }
                    return (url, date)
                }
                .sorted { $0.1 > $1.1 }
                .first?.0

            if let file = recentMediaFile {
                let path = file.path
                TubifyLogger.ytdlp.warning("使用 fallback 找到檔案: \(path)")
                LogFileManager.shared.logDownloadComplete(taskId: taskId, outputPath: path)
                return path
            }
        }

        throw YTDLPError.parseError("無法確定輸出檔案路徑。請確認下載是否成功完成。")
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

    /// 將音軌語言選擇注入到 format 字串中
    /// 例如: "-f bv+ba" -> "-f bv+ba[language=ja]/bv+ba"
    nonisolated private func injectAudioLanguage(into template: String, language: String) -> String {
        // 尋找 -f 或 --format 參數及其值
        // 常見格式:
        // -f "bv[ext=mp4]+ba[ext=m4a]"
        // -f bv+ba
        // --format "bestvideo+bestaudio"

        var result = template

        // 用正則表達式找到 -f 或 --format 參數
        let patterns = [
            #"(-f\s+)"([^"]+)""#,           // -f "..."
            #"(-f\s+)'([^']+)'"#,           // -f '...'
            #"(--format\s+)"([^"]+)""#,     // --format "..."
            #"(--format\s+)'([^']+)'"#,     // --format '...'
            #"(-f\s+)(\S+)"#,               // -f value (無引號)
            #"(--format\s+)(\S+)"#          // --format value (無引號)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)) {

                let prefixRange = Range(match.range(at: 1), in: result)!
                let formatRange = Range(match.range(at: 2), in: result)!
                let prefix = String(result[prefixRange])
                let formatValue = String(result[formatRange])

                // 修改 format 值，加入語言選擇
                let modifiedFormat = injectLanguageIntoFormat(formatValue, language: language)

                // 重建字串
                let fullMatchRange = Range(match.range, in: result)!
                let quoteChar = pattern.contains("\"") ? "\"" : (pattern.contains("'") ? "'" : "")
                let replacement = "\(prefix)\(quoteChar)\(modifiedFormat)\(quoteChar)"
                result = result.replacingCharacters(in: fullMatchRange, with: replacement)

                TubifyLogger.ytdlp.debug("修改 format: \(formatValue) -> \(modifiedFormat)")
                break
            }
        }

        return result
    }

    /// 在 format 字串中注入語言選擇
    /// 例如: "bv+ba[ext=m4a]" -> "bv+ba[ext=m4a][language=ja]/bv+ba[ext=m4a]"
    nonisolated private func injectLanguageIntoFormat(_ format: String, language: String) -> String {
        // 找到音訊部分（ba, bestaudio 等）
        // 常見模式: bv+ba, bestvideo+bestaudio, bv[...]+ba[...]

        // 策略：在音訊格式選擇器後加入 [language=XX]，並加入 fallback
        // 例如: bv+ba[ext=m4a] -> bv+ba[ext=m4a][language=ja]/bv+ba[ext=m4a]

        let audioPatterns = [
            #"(ba\[[^\]]*\])"#,          // ba[...]
            #"(bestaudio\[[^\]]*\])"#,   // bestaudio[...]
            #"(ba)(?![a-z\[])"#,         // ba (不帶其他字符)
            #"(bestaudio)(?![a-z\[])"#   // bestaudio (不帶其他字符)
        ]

        var modifiedFormat = format

        for pattern in audioPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: modifiedFormat, range: NSRange(modifiedFormat.startIndex..., in: modifiedFormat)) {

                let audioRange = Range(match.range(at: 1), in: modifiedFormat)!
                let audioSelector = String(modifiedFormat[audioRange])

                // 新的音訊選擇器：加入語言過濾，並保留 fallback
                let newAudioSelector = "\(audioSelector)[language=\(language)]"

                // 加入 fallback：原始格式（如果沒有該語言的音軌就用預設）
                let formatWithFallback = modifiedFormat.replacingCharacters(in: audioRange, with: newAudioSelector)
                    + "/" + format

                modifiedFormat = formatWithFallback
                break
            }
        }

        return modifiedFormat
    }
}
