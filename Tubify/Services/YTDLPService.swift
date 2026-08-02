import Foundation
import Darwin

/// 線程安全的下載結果容器
final class DownloadResultHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var _outputPath: String?
    private var _errorLines: [String] = []
    private var _downloadedFiles: [String] = []

    var outputPath: String? {
        lock.lock()
        defer { lock.unlock() }
        return _outputPath
    }

    var errorContext: String? {
        lock.lock()
        defer { lock.unlock() }
        guard !_errorLines.isEmpty else { return nil }
        return _errorLines.joined(separator: "\n")
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

    func appendError(_ error: String) {
        lock.lock()
        defer { lock.unlock() }
        _errorLines.append(error)
    }

    func addDownloadedFile(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        _downloadedFiles.append(path)
    }
}

/// 將 pipe 讀到的資料切成完整的行。
///
/// `FileHandle.readabilityHandler` 每次拿到的是任意大小的 chunk，行尾可能落在 chunk 中間。
/// 若直接對 chunk 做 `components(separatedBy:)`，一行會被拆成兩段 —— yt-dlp 的
/// `ERROR: [download] Got error: ...` 就曾因此被切成 `ERROR:` 與 `[download] Got error: ...`，
/// 導致真正的錯誤原因被丟棄。此類別保留未完成的尾段，直到讀到換行才輸出。
///
/// yt-dlp 的進度更新以 `\r` 結尾、一般訊息以 `\n` 結尾，兩者都視為行分隔。
///
/// 緩衝刻意在 `Data`（而非 `String`）層進行：多位元組字元同樣可能被切在 chunk 邊界，
/// 此時對半段位元組做 `String(data:encoding:.utf8)` 會得到 nil，整個 chunk 被丟棄
/// —— 中文標題的影片首當其衝。累積原始位元組、湊齊整行後才解碼可避免此問題。
/// 以位元組切行是安全的：UTF-8 的續位元組一律 ≥ 0x80，不會與 `\n`/`\r` 混淆。
final class LineBuffer {
    private static let newline: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D

    private var pending = Data()
    private let lock = NSLock()

    /// 餵入一段資料，回傳其中所有「已完成」的行（不含空行）。
    func feed(_ chunk: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        pending.append(chunk)
        // 尾端若不是換行，最後一段是不完整的行，留待下次。
        guard let lastSeparator = pending.lastIndex(where: Self.isSeparator) else {
            return []
        }
        let complete = pending[..<lastSeparator]
        pending = Data(pending[pending.index(after: lastSeparator)...])
        return complete
            .split(whereSeparator: Self.isSeparator)
            .compactMap { String(data: Data($0), encoding: .utf8) }
    }

    /// 取出殘留的最後一段（process 結束時呼叫，避免漏掉沒有換行結尾的輸出）。
    func flush() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard !pending.isEmpty else { return nil }
        let remainder = String(data: pending, encoding: .utf8)
        pending = Data()
        return remainder
    }

    private static func isSeparator(_ byte: UInt8) -> Bool {
        byte == newline || byte == carriageReturn
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

enum YTDLPErrorClassification {
    case endedLive
    case other

    static func classify(_ message: String) -> YTDLPErrorClassification {
        if message.contains("This live event has ended.") {
            return .endedLive
        }
        return .other
    }
}

protocol YTDLPServiceProtocol {
    func download(
        taskId: UUID,
        url: String,
        commandTemplate: String,
        outputDirectory: String,
        subtitleSelection: SubtitleSelection?,
        audioSelection: AudioSelection?,
        onProgress: @escaping ProgressCallback
    ) async throws -> String

    func cancel(taskId: UUID) async
}

/// 下載進度回調
typealias ProgressCallback = (Double) -> Void
typealias DownloadOperationID = UUID

/// yt-dlp 服務
actor YTDLPService {
    static let shared = YTDLPService()
    private static let pipeDrainTimeout: TimeInterval = 1

    private let ytdlpPathProvider: (() async -> String?)?
    private var runningProcesses: [DownloadOperationID: Process] = [:]
    private var activeDownloadOperations: [UUID: DownloadOperationID] = [:]
    private var cancelledOperationIDs: Set<DownloadOperationID> = []

    init(ytdlpPathProvider: (() async -> String?)? = nil) {
        self.ytdlpPathProvider = ytdlpPathProvider
    }

    /// 尋找 yt-dlp 可執行檔路徑
    func findYTDLPPath() async -> String? {
        if let ytdlpPathProvider {
            return await ytdlpPathProvider()
        }

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
    ///
    /// 策略：先「不帶 cookies」下載——公開影片用此即可，且能避開帶 cookies 時
    /// YouTube 對串流網址的綁定驗證所造成的 HTTP 403。只有在失敗且錯誤顯示需要登入
    /// （會員 / 年齡限制 / 私人影片 / 機器人驗證）時，才自動帶 Safari cookies 重試。
    /// 整個流程全自動，使用者無需手動切換。
    ///
    /// 註：target 403 retry 對所有 command template 生效；只有原始 template 含
    /// `--cookies-from-browser safari` 時，明確登入錯誤才會啟用 Safari cookies fallback。
    func download(
        taskId: UUID,
        url: String,
        commandTemplate: String,
        outputDirectory: String,
        subtitleSelection: SubtitleSelection? = nil,
        audioSelection: AudioSelection? = nil,
        onProgress: @escaping ProgressCallback
    ) async throws -> String {
        let operationID = beginDownloadOperation(taskId: taskId)
        defer { finishDownloadOperation(taskId: taskId, operationID: operationID) }

        // 如果有選擇特定音軌語言，修改 format 字串
        var template = commandTemplate
        if let audioSel = audioSelection, let lang = audioSel.selectedLanguage {
            template = injectAudioLanguage(into: template, language: lang)
            TubifyLogger.ytdlp.info("選擇音軌語言: \(lang)")
        }

        let hasCookies = SafariCookiesService.shared.commandNeedsSafariCookies(template)

        // 第一次嘗試：移除 cookies 參數（避免帶 cookies 觸發 YouTube 403）
        let firstTemplate = hasCookies
            ? SafariCookiesService.shared.removeSafariCookies(template)
            : template

        return try await executeDownloadFlow(
            taskId: taskId,
            url: url,
            firstTemplate: firstTemplate,
            cookieTemplateProvider: hasCookies
                ? { SafariCookiesService.shared.transformCommand(template) }
                : nil,
            outputDirectory: outputDirectory,
            subtitleSelection: subtitleSelection,
            onProgress: onProgress,
            operationID: operationID
        )
    }

    /// 執行完整下載流程：target 403 在同一個 template 內重新啟動 process，明確登入錯誤才切換 cookies。
    func executeDownloadFlow(
        taskId: UUID,
        url: String,
        firstTemplate: String,
        cookieTemplateProvider: (() -> String)?,
        outputDirectory: String,
        subtitleSelection: SubtitleSelection?,
        onProgress: @escaping ProgressCallback,
        attemptExecutor: ((String) async throws -> String)? = nil,
        sleeper: ((UInt64) async throws -> Void)? = nil,
        cancellationProbe: (() -> Bool)? = nil,
        operationID: DownloadOperationID? = nil
    ) async throws -> String {
        let flowOperationID = operationID ?? UUID()
        let executeAttempt = attemptExecutor ?? { [self] processedTemplate in
            try await executeDownload(
                taskId: taskId,
                operationID: flowOperationID,
                url: url,
                processedTemplate: processedTemplate,
                outputDirectory: outputDirectory,
                subtitleSelection: subtitleSelection,
                onProgress: onProgress
            )
        }

        do {
            return try await executeWithTransient403Retries(
                taskId: taskId,
                operationID: flowOperationID,
                template: firstTemplate,
                executeAttempt: executeAttempt,
                sleeper: sleeper,
                cancellationProbe: cancellationProbe
            )
        } catch let error as YTDLPError {
            // 只有在模板原本帶 cookies、且錯誤顯示需要登入時，才帶 cookies 重試。
            guard let cookieTemplateProvider, Self.shouldRetryWithCookies(error) else {
                throw error
            }

            TubifyLogger.ytdlp.info("下載失敗（疑似需要登入），改用 Safari cookies 重試: \(url)")
            TubifyLogger.cookies.info("偵測到需登入內容，轉換 Safari cookies 文件後重試")
            return try await executeWithTransient403Retries(
                taskId: taskId,
                operationID: flowOperationID,
                template: cookieTemplateProvider(),
                executeAttempt: executeAttempt,
                sleeper: sleeper,
                cancellationProbe: cancellationProbe
            )
        }
    }

    /// 對單一 processed template 執行最多一次 initial attempt 與三次 target 403 retry。
    private func executeWithTransient403Retries(
        taskId: UUID,
        operationID: DownloadOperationID,
        template: String,
        executeAttempt: (String) async throws -> String,
        sleeper: ((UInt64) async throws -> Void)?,
        cancellationProbe: (() -> Bool)?
    ) async throws -> String {
        let retryDelays: [UInt64] = [2_000_000_000, 5_000_000_000, 10_000_000_000]
        let sleepSlice: (UInt64) async throws -> Void = sleeper ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }

        for attempt in 0...retryDelays.count {
            guard !isCancelled(taskId: taskId, operationID: operationID, cancellationProbe: cancellationProbe) else {
                throw YTDLPError.cancelled
            }

            do {
                let outputPath = try await executeAttempt(template)
                guard !isCancelled(taskId: taskId, operationID: operationID, cancellationProbe: cancellationProbe) else {
                    throw YTDLPError.cancelled
                }
                return outputPath
            } catch let error as YTDLPError {
                guard Self.isRetryableDownload403(error), attempt < retryDelays.count else {
                    throw error
                }

                let retryNumber = attempt + 1
                let delay = retryDelays[attempt]
                TubifyLogger.ytdlp.info(
                    "403 retry taskId=\(taskId.uuidString) retry=\(retryNumber)/\(retryDelays.count) delay=\(Double(delay) / 1_000_000_000) seconds"
                )
                try await waitForRetry(
                    taskId: taskId,
                    operationID: operationID,
                    delay: delay,
                    sleeper: sleepSlice,
                    cancellationProbe: cancellationProbe
                )
            }
        }

        throw YTDLPError.executionFailed("403 retry policy exhausted without an error")
    }

    /// 以不超過 100 ms 的 async slices 等待 retry，並在每個 slice 後觀察取消。
    private func waitForRetry(
        taskId: UUID,
        operationID: DownloadOperationID,
        delay: UInt64,
        sleeper: (UInt64) async throws -> Void,
        cancellationProbe: (() -> Bool)?
    ) async throws {
        let maxSlice: UInt64 = 100_000_000
        var remaining = delay

        while remaining > 0 {
            let slice = min(remaining, maxSlice)
            do {
                try await sleeper(slice)
            } catch {
                throw YTDLPError.cancelled
            }
            guard !isCancelled(taskId: taskId, operationID: operationID, cancellationProbe: cancellationProbe) else {
                throw YTDLPError.cancelled
            }
            remaining -= slice
        }
    }

    private func isCancelled(
        taskId: UUID,
        operationID: DownloadOperationID,
        cancellationProbe: (() -> Bool)?
    ) -> Bool {
        if let activeOperationID = activeDownloadOperations[taskId], activeOperationID != operationID {
            return true
        }
        return cancelledOperationIDs.contains(operationID) || (cancellationProbe?() ?? false)
    }

    private static func drainPipes(
        _ outputPipe: FileHandle,
        _ errorPipe: FileHandle,
        deadline: Date
    ) -> (output: Data, error: Data) {
        let fileDescriptors = [outputPipe.fileDescriptor, errorPipe.fileDescriptor]
        let originalFlags = fileDescriptors.map { fcntl($0, F_GETFL) }
        guard originalFlags.allSatisfy({ $0 >= 0 }) else {
            return (Data(), Data())
        }

        for (fileDescriptor, flags) in zip(fileDescriptors, originalFlags) {
            guard fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
                for (restoreDescriptor, restoreFlags) in zip(fileDescriptors, originalFlags) {
                    _ = fcntl(restoreDescriptor, F_SETFL, restoreFlags)
                }
                return (Data(), Data())
            }
        }
        defer {
            for (fileDescriptor, flags) in zip(fileDescriptors, originalFlags) {
                _ = fcntl(fileDescriptor, F_SETFL, flags)
            }
        }

        var data = [Data(), Data()]
        var open = [true, true]
        var nextIndex = 0
        var isInitialRead = true
        var buffer = [UInt8](repeating: 0, count: 8192)

        while isInitialRead || Date().timeIntervalSince(deadline) < 0 {
            var descriptors = fileDescriptors.enumerated().map { index, fileDescriptor in
                pollfd(
                    fd: open[index] ? fileDescriptor : -1,
                    events: Int16(POLLIN | POLLHUP | POLLERR),
                    revents: 0
                )
            }

            if !isInitialRead {
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { break }
                let timeoutMilliseconds = max(1, Int32((remaining * 1_000).rounded(.up)))
                let pollResult = descriptors.withUnsafeMutableBufferPointer {
                    Darwin.poll($0.baseAddress, nfds_t($0.count), timeoutMilliseconds)
                }
                if pollResult == 0 {
                    break
                }
                if pollResult < 0 && errno != EINTR {
                    break
                }
            }

            for offset in 0..<fileDescriptors.count {
                let index = (nextIndex + offset) % fileDescriptors.count
                guard open[index] else { continue }
                let events = descriptors[index].revents
                if events & Int16(POLLNVAL) != 0 {
                    open[index] = false
                    continue
                }
                guard isInitialRead || events & Int16(POLLIN | POLLHUP | POLLERR) != 0 else {
                    continue
                }

                let bytesRead = buffer.withUnsafeMutableBytes { bytes in
                    Darwin.read(fileDescriptors[index], bytes.baseAddress, bytes.count)
                }
                if bytesRead > 0 {
                    data[index].append(contentsOf: buffer[..<bytesRead])
                } else if bytesRead == 0 {
                    open[index] = false
                } else if errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK {
                    open[index] = false
                }
            }

            isInitialRead = false
            nextIndex = (nextIndex + 1) % fileDescriptors.count
            if !open.contains(true) { break }
        }

        return (data[0], data[1])
    }

    /// 判斷 stderr 的一行是否為值得保留的錯誤訊息。
    ///
    /// 除了 yt-dlp 的 `ERROR:` 前綴，也認得下載器自己的失敗訊息
    /// （如 `[download] Got error: ... Giving up after 10 retries`），這類訊息不含大寫 ERROR，
    /// 卻往往是唯一說明失敗原因的一行。
    ///
    /// 只有前綴而無內容的 `ERROR:` 會被忽略，避免它蓋掉後續有意義的訊息。
    static func isErrorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("ERROR:") {
            // "ERROR:" 後面沒有任何內容時不具診斷價值
            return !trimmed.dropFirst("ERROR:".count).trimmingCharacters(in: .whitespaces).isEmpty
        }
        if trimmed.contains("ERROR") { return true }

        let lowered = trimmed.lowercased()
        return lowered.contains("got error:") || lowered.contains("giving up after")
    }

    /// 判斷下載錯誤是否可能因「需要登入」而起，需帶 cookies 重試
    /// 公開影片不帶 cookies 即可成功，因此只在錯誤訊息含登入相關訊號時才重試
    static func shouldRetryWithCookies(_ error: YTDLPError) -> Bool {
        guard case .executionFailed(let message) = error else { return false }
        let lowered = message.lowercased()
        // 僅匹配明確的「需登入」訊號，避免如 "account" 之類過於寬鬆的字串
        // 誤判公開影片的其他錯誤，反而把它推回會觸發 403 的帶 cookies 路徑
        let loginSignals = [
            "sign in",
            "log in",
            "login required",
            "logged-in",
            "logged in",
            "members-only",
            "members only",
            "available to this channel's members",
            "join this channel",
            "private video",
            "this video is private",
            "age-restricted",
            "confirm your age",
            "confirm you're not a bot",
            // yt-dlp 在多數需登入的網站（Instagram 等）會建議改用 cookies；
            // 以此通用提示作為帶 cookies 重試的訊號。
            "use --cookies",
            "--cookies-from-browser",
            "empty media response"
        ]
        return loginSignals.contains { lowered.contains($0) }
    }

    /// 只匹配 yt-dlp 直接回報的 video-data HTTP 403。
    static func isRetryableDownload403(_ error: YTDLPError) -> Bool {
        guard case .executionFailed(let message) = error else { return false }
        return message.contains("unable to download video data: HTTP Error 403: Forbidden")
            && !message.contains("Giving up after")
    }

    /// 實際執行一次 yt-dlp 下載（template 已完成音軌與 cookies 處理）
    private func executeDownload(
        taskId: UUID,
        operationID: DownloadOperationID,
        url: String,
        processedTemplate: String,
        outputDirectory: String,
        subtitleSelection: SubtitleSelection?,
        onProgress: @escaping ProgressCallback
    ) async throws -> String {
        guard let ytdlpPath = await findYTDLPPath() else {
            throw YTDLPError.notFound
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

        // 強制啟用進度輸出（當 stdout 被 pipe 時，yt-dlp 預設會禁用進度）
        if !finalArguments.contains("--progress") && !finalArguments.contains("--no-progress") {
            finalArguments.append("--progress")
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
        LogFileManager.shared.logDownloadCommand(
            taskId: taskId,
            command: "\(ytdlpPath) \(finalArguments.joined(separator: " "))"
        )

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
        // 禁用 Python 輸出緩衝，確保 yt-dlp 的進度輸出能即時傳送
        // 當 stdout 被 pipe 時，Python 預設使用塊緩衝，導致進度無法即時更新
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 儲存 process 以便取消
        runningProcesses[operationID] = process

        // 使用線程安全的容器來儲存結果
        let resultHolder = DownloadResultHolder()

        let handleLine: (String, Bool) -> Void = { [weak self] line, isStderr in
            LogFileManager.shared.logYTDLPRawOutput(
                taskId: taskId,
                source: isStderr ? "stderr" : "stdout",
                output: line
            )

            // 先嘗試解析進度（yt-dlp 常把進度寫到 stderr）
            if let progress = self?.parseProgress(from: line) {
                // 記錄進度更新（用於診斷）
                if progress < 0.01 || progress > 0.99 || Int(progress * 100) % 25 == 0 {
                    TubifyLogger.ytdlp.info("進度更新: \(Int(progress * 100))%")
                }
                Task { @MainActor in
                    onProgress(progress)
                }
                return
            }

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

            if isStderr, Self.isErrorLine(line) {
                resultHolder.appendError(line)
            }
        }

        // 處理輸出（stdout / stderr）
        // 各自使用獨立的 LineBuffer，確保跨 chunk 的行不會被切斷。
        let pipeProcessingLock = NSLock()
        let outputBuffer = LineBuffer()
        let errorBuffer = LineBuffer()

        let processData: (Data, LineBuffer, Bool) -> Void = { data, buffer, isStderr in
            for line in buffer.feed(data) {
                handleLine(line, isStderr)
            }
        }

        // 直接把原始位元組交給 LineBuffer，由它湊齊整行後才解碼
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            pipeProcessingLock.lock()
            defer { pipeProcessingLock.unlock() }

            let data = handle.availableData
            guard !data.isEmpty else { return }
            processData(data, outputBuffer, false)
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            pipeProcessingLock.lock()
            defer { pipeProcessingLock.unlock() }

            let data = handle.availableData
            guard !data.isEmpty else { return }
            processData(data, errorBuffer, true)
        }

        do {
            // 在 process.run() 前再次檢查，避免取消後啟動新的 yt-dlp process。
            if isCancelled(taskId: taskId, operationID: operationID, cancellationProbe: nil) {
                throw YTDLPError.cancelled
            }
            try process.run()
        } catch {
            if error is YTDLPError {
                runningProcesses.removeValue(forKey: operationID)
                throw error
            }
            runningProcesses.removeValue(forKey: operationID)
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

        // handler 停止後先 bounded drain pipe，確保 terminationHandler 先執行時仍不會遺失尾端輸出，
        // 同時避免殘留 writer 讓 actor 無限等待 EOF。
        pipeProcessingLock.withLock {
            let drainDeadline = Date().addingTimeInterval(Self.pipeDrainTimeout)
            let remaining = Self.drainPipes(
                outputPipe.fileHandleForReading,
                errorPipe.fileHandleForReading,
                deadline: drainDeadline
            )
            processData(remaining.output, outputBuffer, false)
            processData(remaining.error, errorBuffer, true)

            // 補上沒有換行結尾的最後一行（yt-dlp 失敗時的 ERROR 常落在這裡）
            if let remainder = outputBuffer.flush() {
                handleLine(remainder, false)
            }
            if let remainder = errorBuffer.flush() {
                handleLine(remainder, true)
            }
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        runningProcesses.removeValue(forKey: operationID)

        // Process 結束後再次檢查，避免 stale operation 在成功結果路徑回傳。
        if isCancelled(taskId: taskId, operationID: operationID, cancellationProbe: nil) {
            throw YTDLPError.cancelled
        }

        // 檢查結果
        if terminationStatus != 0 {
            let errorMessage = resultHolder.errorContext ?? "未知錯誤 (退出碼: \(terminationStatus))"
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
        guard let operationID = activeDownloadOperations[taskId] else { return }
        cancelOperation(operationID)
        TubifyLogger.ytdlp.info("已取消下載: \(taskId.uuidString)")
    }

    private func beginDownloadOperation(taskId: UUID) -> DownloadOperationID {
        let operationID = UUID()
        if let previousOperationID = activeDownloadOperations[taskId] {
            cancelOperation(previousOperationID)
        }
        activeDownloadOperations[taskId] = operationID
        return operationID
    }

    private func cancelOperation(_ operationID: DownloadOperationID) {
        cancelledOperationIDs.insert(operationID)
        if let process = runningProcesses[operationID] {
            process.terminate()
            runningProcesses.removeValue(forKey: operationID)
        }
    }

    private func finishDownloadOperation(taskId: UUID, operationID: DownloadOperationID) {
        cancelledOperationIDs.remove(operationID)
        guard activeDownloadOperations[taskId] == operationID else { return }
        activeDownloadOperations.removeValue(forKey: taskId)
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

extension YTDLPService: YTDLPServiceProtocol {}
