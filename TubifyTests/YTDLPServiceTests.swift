import XCTest
@testable import Tubify

/// YTDLPService 測試
final class YTDLPServiceTests: XCTestCase {

    private final class ScriptedDownloadFlow {
        var results: [Result<String, YTDLPError>]
        var templates: [String] = []

        init(_ results: [Result<String, YTDLPError>]) {
            self.results = results
        }

        func execute(template: String) throws -> String {
            templates.append(template)
            guard !results.isEmpty else {
                throw YTDLPError.executionFailed("script exhausted")
            }
            return try results.removeFirst().get()
        }
    }

    // MARK: - 進度解析測試

    func testParseProgressFromStandardOutput() {
        let progress = parseProgress(from: "[download]  45.2% of 100.00MiB at 5.00MiB/s ETA 00:11")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 0.452, accuracy: 0.001)
    }

    func testParseProgressFromOutputWithoutDecimal() {
        let progress = parseProgress(from: "[download]  50% of 100.00MiB at 5.00MiB/s ETA 00:10")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 0.5, accuracy: 0.001)
    }

    func testParseProgressAt100Percent() {
        let progress = parseProgress(from: "[download] 100% of 100.00MiB in 00:20")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 1.0, accuracy: 0.001)
    }

    func testParseProgressAtZeroPercent() {
        let progress = parseProgress(from: "[download]   0.0% of 100.00MiB at Unknown speed ETA Unknown")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 0.0, accuracy: 0.001)
    }

    func testParseProgressFromSmallPercentage() {
        let progress = parseProgress(from: "[download]   1.5% of 50.00MiB at 2.00MiB/s ETA 00:24")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 0.015, accuracy: 0.001)
    }

    func testParseProgressReturnsNilForNonProgressLine() {
        let progress = parseProgress(from: "[info] Downloading 1 format(s)")
        XCTAssertNil(progress)
    }

    func testParseProgressReturnsNilForDestinationLine() {
        let progress = parseProgress(from: "[download] Destination: /path/to/video.mp4")
        XCTAssertNil(progress)
    }

    func testParseProgressReturnsNilForMergerLine() {
        let progress = parseProgress(from: "[Merger] Merging formats into \"video.mp4\"")
        XCTAssertNil(progress)
    }

    func testParseProgressReturnsNilForEmptyString() {
        let progress = parseProgress(from: "")
        XCTAssertNil(progress)
    }

    func testParseProgressReturnsNilForErrorLine() {
        let progress = parseProgress(from: "ERROR: Video unavailable")
        XCTAssertNil(progress)
    }

    // MARK: - 命令參數解析測試

    func testParseSimpleCommand() {
        let args = parseCommandArguments("yt-dlp -S ext:mp4 https://youtube.com/watch?v=abc")
        XCTAssertEqual(args, ["-S", "ext:mp4", "https://youtube.com/watch?v=abc"])
    }

    func testParseCommandWithDoubleQuotes() {
        let args = parseCommandArguments("yt-dlp -o \"%(title)s.%(ext)s\" https://youtube.com/watch?v=abc")
        XCTAssertEqual(args, ["-o", "%(title)s.%(ext)s", "https://youtube.com/watch?v=abc"])
    }

    func testParseCommandWithSingleQuotes() {
        let args = parseCommandArguments("yt-dlp -o '%(title)s.%(ext)s' https://youtube.com/watch?v=abc")
        XCTAssertEqual(args, ["-o", "%(title)s.%(ext)s", "https://youtube.com/watch?v=abc"])
    }

    func testParseCommandWithMultipleArgs() {
        let args = parseCommandArguments("yt-dlp -S ext:mp4 --cookies-from-browser safari -o output.mp4 url")
        XCTAssertEqual(args, ["-S", "ext:mp4", "--cookies-from-browser", "safari", "-o", "output.mp4", "url"])
    }

    func testParseCommandWithQuotedSpaces() {
        let args = parseCommandArguments("yt-dlp -o \"/path/with spaces/output.mp4\" url")
        XCTAssertEqual(args, ["-o", "/path/with spaces/output.mp4", "url"])
    }

    func testParseCommandRemovesYtdlp() {
        let args = parseCommandArguments("yt-dlp -S ext:mp4 url")
        XCTAssertFalse(args.contains("yt-dlp"))
    }

    func testParseCommandRemovesFullPath() {
        let args = parseCommandArguments("/opt/homebrew/bin/yt-dlp -S ext:mp4 url")
        XCTAssertFalse(args.contains { $0.contains("yt-dlp") })
    }

    // MARK: - 輸出路徑解析測試

    func testExtractOutputPathFromDestinationLine() {
        let line = "[download] Destination: /Users/test/Downloads/video.mp4"
        let path = extractOutputPath(from: line)
        XCTAssertEqual(path, "/Users/test/Downloads/video.mp4")
    }

    func testExtractOutputPathFromMergerLine() {
        let line = "[Merger] Merging formats into \"/Users/test/Downloads/video.mp4\""
        let path = extractMergerOutputPath(from: line)
        XCTAssertEqual(path, "/Users/test/Downloads/video.mp4")
    }

    func testExtractOutputPathWithSpecialCharacters() {
        let line = "[download] Destination: /Users/test/Downloads/Video - Title (2024) [1080p].mp4"
        let path = extractOutputPath(from: line)
        XCTAssertEqual(path, "/Users/test/Downloads/Video - Title (2024) [1080p].mp4")
    }

    // MARK: - YTDLPError 測試

    func testYTDLPErrorNotFoundDescription() {
        let error = YTDLPError.notFound
        XCTAssertEqual(error.errorDescription, "找不到 yt-dlp。請確保已安裝 yt-dlp (brew install yt-dlp)")
    }

    func testYTDLPErrorExecutionFailedDescription() {
        let error = YTDLPError.executionFailed("Connection timeout")
        XCTAssertTrue(error.errorDescription?.contains("Connection timeout") ?? false)
    }

    func testYTDLPErrorCancelledDescription() {
        let error = YTDLPError.cancelled
        XCTAssertEqual(error.errorDescription, "下載已取消")
    }

    func testIsRetryableDownload403OnlyMatchesTargetVideoDataError() {
        let retryable = YTDLPError.executionFailed(
            "ERROR: unable to download video data: HTTP Error 403: Forbidden"
        )
        XCTAssertTrue(YTDLPService.isRetryableDownload403(retryable))

        let nonRetryableExecutionErrors = [
            "ERROR: Unable to download webpage: HTTP Error 403: Forbidden",
            "ERROR: Unable to download subtitle: HTTP Error 403: Forbidden",
            "ERROR: fragment downloader: HTTP Error 403: Forbidden",
            "ERROR: Giving up after 10 retries: HTTP Error 403: Forbidden",
            "ERROR: unable to download video data: HTTP Error 403: Forbidden; Giving up after 10 retries",
            "ERROR: unable to download video data: HTTP Error 429: Too Many Requests",
            "ERROR: unable to download video data: HTTP Error 500: Internal Server Error",
            "ERROR: Sign in to confirm you're not a bot"
        ]
        for message in nonRetryableExecutionErrors {
            XCTAssertFalse(
                YTDLPService.isRetryableDownload403(.executionFailed(message)),
                "不應重試：\(message)"
            )
        }

        XCTAssertFalse(YTDLPService.isRetryableDownload403(.notFound))
        XCTAssertFalse(YTDLPService.isRetryableDownload403(.parseError("bad output")))
        XCTAssertFalse(YTDLPService.isRetryableDownload403(.cancelled))
    }

    func testProductionDownloadCancellationTerminatesFixtureProcessWithoutCookiesFallback() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let taskId = UUID()
        let downloadTask = Task { () -> String in
            do {
                _ = try await service.download(
                    taskId: taskId,
                    url: "https://youtube.com/watch?v=active-cancellation",
                    commandTemplate: "ACTIVE --cookies-from-browser safari $youtubeUrl",
                    outputDirectory: fixture.directory.path,
                    onProgress: { _ in }
                )
                return "success"
            } catch let error as YTDLPError {
                return error.errorDescription ?? "unknown"
            } catch {
                return String(describing: error)
            }
        }

        let activeMarkerFound = await waitForFile(fixture.activeMarker)
        XCTAssertTrue(activeMarkerFound)
        await service.cancel(taskId: taskId)

        let cancellationResult = await downloadTask.value
        XCTAssertEqual(cancellationResult, YTDLPError.cancelled.errorDescription)
        let activePID = try String(contentsOf: fixture.pid, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let processExited = await waitForProcessExit(activePID)
        XCTAssertTrue(processExited)
        let invocationLog = try String(contentsOf: fixture.log, encoding: .utf8)
        XCTAssertEqual(invocationLog.components(separatedBy: "\n").filter { $0.contains("ACTIVE") }.count, 1)
        XCTAssertFalse(invocationLog.contains("--cookies-from-browser"))
    }

    func testProductionDownloadDrainsStderrAfterProcessTerminationAndRetries() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let outputPath = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=drain-403",
            commandTemplate: "DRAIN_403 $youtubeUrl",
            outputDirectory: fixture.directory.path,
            onProgress: { _ in }
        )

        XCTAssertEqual(
            URL(fileURLWithPath: outputPath).resolvingSymlinksInPath().path,
            fixture.newOutput.resolvingSymlinksInPath().path
        )
        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("DRAIN_403") }.count, 2)
    }

    func testProductionDownloadDrainsStderrAfterStdoutConsumesSharedDeadline() async throws {
        let fixture = try makeYTDLPFixture()
        defer {
            terminateProcess(at: fixture.writerPID)
            try? FileManager.default.removeItem(at: fixture.directory)
        }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let outputPath = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=stdout-starvation-403",
            commandTemplate: "STARVING_STDOUT_403 $youtubeUrl",
            outputDirectory: fixture.directory.path,
            onProgress: { _ in }
        )

        XCTAssertEqual(
            URL(fileURLWithPath: outputPath).resolvingSymlinksInPath().path,
            fixture.newOutput.resolvingSymlinksInPath().path
        )
        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("STARVING_STDOUT_403") }.count, 2)

        let writerPID = try String(contentsOf: fixture.writerPID, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let writerExited = await waitForProcessExit(writerPID)
        XCTAssertTrue(writerExited)
    }

    func testProductionDownloadHandlesStdoutEOFWhileStderrWriterIsIdle() async throws {
        let fixture = try makeYTDLPFixture()
        defer {
            terminateProcess(at: fixture.writerPID)
            try? FileManager.default.removeItem(at: fixture.directory)
        }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let outputPath = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=stdout-eof-idle-stderr-403",
            commandTemplate: "STDOUT_EOF_IDLE_STDERR_403 $youtubeUrl",
            outputDirectory: fixture.directory.path,
            onProgress: { _ in }
        )

        XCTAssertEqual(
            URL(fileURLWithPath: outputPath).resolvingSymlinksInPath().path,
            fixture.newOutput.resolvingSymlinksInPath().path
        )
        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("STDOUT_EOF_IDLE_STDERR_403") }.count, 2)

        let writerPID = try String(contentsOf: fixture.writerPID, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let writerExited = await waitForProcessExit(writerPID)
        XCTAssertTrue(writerExited)
    }

    func testProductionDownloadDoesNotRetryMultilineGivingUpAfterContext() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.download(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=multiline-403",
                commandTemplate: "MULTILINE_403 $youtubeUrl",
                outputDirectory: fixture.directory.path,
                onProgress: { _ in }
            )
            XCTFail("包含 Giving up after context 的多行 stderr 不應重試")
        } catch let error as YTDLPError {
            guard case .executionFailed(let message) = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
            XCTAssertTrue(message.contains("Giving up after"))
            XCTAssertTrue(message.contains("unable to download video data: HTTP Error 403: Forbidden"))
        }

        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("MULTILINE_403") }.count, 1)
    }

    func testProductionDownloadBoundsStderrDrainWhenWriterNeverCloses() async throws {
        let fixture = try makeYTDLPFixture()
        defer {
            terminateProcess(at: fixture.writerPID)
            try? FileManager.default.removeItem(at: fixture.directory)
        }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let startedAt = Date()
        do {
            _ = try await service.download(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=hanging-writer",
                commandTemplate: "HANG_WRITER $youtubeUrl",
                outputDirectory: fixture.directory.path,
                onProgress: { _ in }
            )
            XCTFail("writer 未關閉時仍應回報下載錯誤")
        } catch let error as YTDLPError {
            guard case .executionFailed = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 5)
        let writerPID = try String(contentsOf: fixture.writerPID, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let writerExited = await waitForProcessExit(writerPID)
        XCTAssertTrue(writerExited)
        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("HANG_WRITER") }.count, 1)
    }

    func testOverlappingOperationsStopStaleRetryBeforeStartingAnotherProcess() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let taskId = UUID()
        let oldTask = Task { () -> String in
            do {
                _ = try await service.download(
                    taskId: taskId,
                    url: "https://youtube.com/watch?v=old-operation",
                    commandTemplate: "OLD $youtubeUrl",
                    outputDirectory: fixture.directory.path,
                    onProgress: { _ in }
                )
                return "success"
            } catch let error as YTDLPError {
                return error.errorDescription ?? "unknown"
            } catch {
                return String(describing: error)
            }
        }

        let oldMarkerFound = await waitForFile(fixture.oldMarker)
        XCTAssertTrue(oldMarkerFound)
        let newTask = Task { () -> String in
            do {
                return try await service.download(
                    taskId: taskId,
                    url: "https://youtube.com/watch?v=new-operation",
                    commandTemplate: "NEW $youtubeUrl",
                    outputDirectory: fixture.directory.path,
                    onProgress: { _ in }
                )
            } catch let error as YTDLPError {
                return error.errorDescription ?? "unknown"
            } catch {
                return String(describing: error)
            }
        }

        let newResult = await newTask.value
        let oldResult = await oldTask.value
        XCTAssertEqual(
            URL(fileURLWithPath: newResult).resolvingSymlinksInPath().path,
            fixture.newOutput.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(oldResult, YTDLPError.cancelled.errorDescription)

        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        XCTAssertEqual(invocations.filter { $0.contains("OLD") }.count, 1)
        XCTAssertEqual(invocations.filter { $0.contains("NEW") }.count, 1)
    }

    func testExecuteDownloadFlowRetriesTarget403ThenSucceeds() async throws {
        let taskId = UUID()
        let scripted = ScriptedDownloadFlow([
            .failure(.executionFailed("unable to download video data: HTTP Error 403: Forbidden")),
            .success("/Downloads/video.mp4")
        ])
        var sleepSlices: [UInt64] = []

        let outputPath = try await YTDLPService.shared.executeDownloadFlow(
            taskId: taskId,
            url: "https://youtube.com/watch?v=target-403",
            firstTemplate: "FIRST_TEMPLATE",
            cookieTemplateProvider: nil,
            outputDirectory: "/Downloads",
            subtitleSelection: nil,
            onProgress: { _ in },
            attemptExecutor: { template in try scripted.execute(template: template) },
            sleeper: { sleepSlices.append($0) },
            cancellationProbe: { false }
        )

        XCTAssertEqual(outputPath, "/Downloads/video.mp4")
        XCTAssertEqual(scripted.templates, ["FIRST_TEMPLATE", "FIRST_TEMPLATE"])
        XCTAssertEqual(sleepSlices.reduce(0, +), 2_000_000_000)
        XCTAssertTrue(sleepSlices.allSatisfy { $0 <= 100_000_000 })
    }

    func testExecuteDownloadFlowChecksCancellationAfterSuccessfulAttempt() async {
        var cancellationObserved = false

        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=success-cancellation-race",
                firstTemplate: "FIRST_TEMPLATE",
                cookieTemplateProvider: nil,
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { _ in
                    cancellationObserved = true
                    return "/Downloads/video.mp4"
                },
                sleeper: { _ in },
                cancellationProbe: { cancellationObserved }
            )
            XCTFail("成功 attempt 後仍應觀察取消")
        } catch let error as YTDLPError {
            guard case .cancelled = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
        } catch {
            XCTFail("錯誤類型不符：\(error)")
        }
    }

    func testExecuteDownloadFlowRetriesThreeTimesWithExactDelaysAndSucceeds() async throws {
        let scripted = ScriptedDownloadFlow([
            .failure(.executionFailed("unable to download video data: HTTP Error 403: Forbidden")),
            .failure(.executionFailed("unable to download video data: HTTP Error 403: Forbidden")),
            .failure(.executionFailed("unable to download video data: HTTP Error 403: Forbidden")),
            .success("/Downloads/video.mp4")
        ])
        var sleepSlices: [UInt64] = []

        let outputPath = try await YTDLPService.shared.executeDownloadFlow(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=target-403",
            firstTemplate: "FIRST_TEMPLATE",
            cookieTemplateProvider: nil,
            outputDirectory: "/Downloads",
            subtitleSelection: nil,
            onProgress: { _ in },
            attemptExecutor: { template in try scripted.execute(template: template) },
            sleeper: { sleepSlices.append($0) },
            cancellationProbe: { false }
        )

        XCTAssertEqual(outputPath, "/Downloads/video.mp4")
        XCTAssertEqual(scripted.templates.count, 4)
        XCTAssertEqual(sleepSlices.count, 170)
        XCTAssertEqual(sleepSlices.prefix(20).reduce(0, +), 2_000_000_000)
        XCTAssertEqual(sleepSlices.dropFirst(20).prefix(50).reduce(0, +), 5_000_000_000)
        XCTAssertEqual(sleepSlices.dropFirst(70).reduce(0, +), 10_000_000_000)
        XCTAssertTrue(sleepSlices.allSatisfy { $0 <= 100_000_000 })
    }

    func testExecuteDownloadFlowThrowsLast403AfterFourAttempts() async {
        let finalMessage = "attempt 4: unable to download video data: HTTP Error 403: Forbidden"
        let scripted = ScriptedDownloadFlow([
            .failure(.executionFailed("attempt 1: unable to download video data: HTTP Error 403: Forbidden")),
            .failure(.executionFailed("attempt 2: unable to download video data: HTTP Error 403: Forbidden")),
            .failure(.executionFailed("attempt 3: unable to download video data: HTTP Error 403: Forbidden")),
            .failure(.executionFailed(finalMessage))
        ])

        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=target-403",
                firstTemplate: "FIRST_TEMPLATE",
                cookieTemplateProvider: nil,
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { template in try scripted.execute(template: template) },
                sleeper: { _ in },
                cancellationProbe: { false }
            )
            XCTFail("應在 4 次 target 403 後拋出最後錯誤")
        } catch let error as YTDLPError {
            guard case .executionFailed(let message) = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
            XCTAssertEqual(message, finalMessage)
        } catch {
            XCTFail("錯誤類型不符：\(error)")
        }

        XCTAssertEqual(scripted.templates.count, 4)
    }

    func testExecuteDownloadFlowDoesNotRetryNonTargetErrors() async {
        let messages = [
            "Unable to download webpage: HTTP Error 403: Forbidden",
            "Unable to download subtitle: HTTP Error 403: Forbidden",
            "fragment downloader: HTTP Error 403: Forbidden",
            "Giving up after 10 retries: HTTP Error 403: Forbidden",
            "unable to download video data: HTTP Error 429: Too Many Requests",
            "unable to download video data: HTTP Error 503: Service Unavailable",
            "Sign in to confirm you're not a bot"
        ]

        for message in messages {
            let scripted = ScriptedDownloadFlow([.failure(.executionFailed(message))])
            var sleepCalled = false

            do {
                _ = try await YTDLPService.shared.executeDownloadFlow(
                    taskId: UUID(),
                    url: "https://youtube.com/watch?v=non-target",
                    firstTemplate: "FIRST_TEMPLATE",
                    cookieTemplateProvider: nil,
                    outputDirectory: "/Downloads",
                    subtitleSelection: nil,
                    onProgress: { _ in },
                    attemptExecutor: { template in try scripted.execute(template: template) },
                    sleeper: { _ in sleepCalled = true },
                    cancellationProbe: { false }
                )
                XCTFail("應立即拋出錯誤：\(message)")
            } catch let error as YTDLPError {
                guard case .executionFailed(let actualMessage) = error else {
                    return XCTFail("錯誤類型不符：\(error)")
                }
                XCTAssertEqual(actualMessage, message)
            } catch {
                XCTFail("錯誤類型不符：\(error)")
            }

            XCTAssertEqual(scripted.templates.count, 1)
            XCTAssertFalse(sleepCalled)
        }
    }

    func testExecuteDownloadFlowPreservesCookiesAndCancellationContracts() async {
        let target403 = YTDLPError.executionFailed(
            "unable to download video data: HTTP Error 403: Forbidden"
        )

        let target403Scripted = ScriptedDownloadFlow([
            .failure(target403), .failure(target403), .failure(target403), .failure(target403)
        ])
        var cookieProviderCalled = false
        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=403",
                firstTemplate: "NO_COOKIES_TEMPLATE",
                cookieTemplateProvider: {
                    cookieProviderCalled = true
                    return "COOKIES_TEMPLATE"
                },
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { template in try target403Scripted.execute(template: template) },
                sleeper: { _ in },
                cancellationProbe: { false }
            )
            XCTFail("應拋出 target 403")
        } catch {
            XCTAssertFalse(cookieProviderCalled)
        }
        XCTAssertEqual(
            target403Scripted.templates,
            ["NO_COOKIES_TEMPLATE", "NO_COOKIES_TEMPLATE", "NO_COOKIES_TEMPLATE", "NO_COOKIES_TEMPLATE"]
        )

        let loginScripted = ScriptedDownloadFlow([
            .failure(.executionFailed("Sign in to confirm you're not a bot")),
            .success("/Downloads/private.mp4")
        ])
        let loginOutput = try? await YTDLPService.shared.executeDownloadFlow(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=login",
            firstTemplate: "NO_COOKIES_TEMPLATE",
            cookieTemplateProvider: { "COOKIES_TEMPLATE" },
            outputDirectory: "/Downloads",
            subtitleSelection: nil,
            onProgress: { _ in },
            attemptExecutor: { template in try loginScripted.execute(template: template) },
            sleeper: { _ in },
            cancellationProbe: { false }
        )
        XCTAssertEqual(loginOutput, "/Downloads/private.mp4")
        XCTAssertEqual(loginScripted.templates, ["NO_COOKIES_TEMPLATE", "COOKIES_TEMPLATE"])

        let activeCancellationScripted = ScriptedDownloadFlow([.failure(.cancelled)])
        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=cancelled",
                firstTemplate: "FIRST_TEMPLATE",
                cookieTemplateProvider: { "COOKIES_TEMPLATE" },
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { template in try activeCancellationScripted.execute(template: template) },
                sleeper: { _ in },
                cancellationProbe: { false }
            )
            XCTFail("應拋出取消")
        } catch let error as YTDLPError {
            guard case .cancelled = error else { return XCTFail("錯誤類型不符：\(error)") }
        } catch {
            XCTFail("錯誤類型不符：\(error)")
        }
        XCTAssertEqual(activeCancellationScripted.templates.count, 1)

        let backoffCancellationScripted = ScriptedDownloadFlow([.failure(target403)])
        var cancelledDuringBackoff = false
        var observedSlices: [UInt64] = []
        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=backoff-cancelled",
                firstTemplate: "FIRST_TEMPLATE",
                cookieTemplateProvider: nil,
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { template in try backoffCancellationScripted.execute(template: template) },
                sleeper: { slice in
                    observedSlices.append(slice)
                    cancelledDuringBackoff = true
                },
                cancellationProbe: { cancelledDuringBackoff }
            )
            XCTFail("應在第一個 backoff slice 後拋出取消")
        } catch let error as YTDLPError {
            guard case .cancelled = error else { return XCTFail("錯誤類型不符：\(error)") }
        } catch {
            XCTFail("錯誤類型不符：\(error)")
        }
        XCTAssertEqual(backoffCancellationScripted.templates.count, 1)
        XCTAssertEqual(observedSlices, [100_000_000])
    }

    func testEndedLiveErrorClassification() {
        let endedLiveError = "ERROR: [youtube] TR_NgGeXWGc: This live event has ended."
        let unavailableError = "ERROR: [youtube] abc123: Video unavailable"

        XCTAssertEqual(YTDLPErrorClassification.classify(endedLiveError), .endedLive)
        XCTAssertEqual(YTDLPErrorClassification.classify(unavailableError), .other)
    }

    // MARK: - 帶 cookies 重試判斷測試（shouldRetryWithCookies）

    /// 迴歸測試：Instagram「empty media response / 需登入 / 改用 cookies」錯誤
    /// 必須觸發帶 cookies 重試。先前因訊號清單未涵蓋此訊息，導致非 YouTube
    /// 需登入內容第一次（不帶 cookies）失敗後不重試，直接報錯。
    func testShouldRetryWithCookiesForInstagramEmptyMediaResponse() {
        let igError = YTDLPError.executionFailed(
            "ERROR: [Instagram] DaILLiOzKyk: Instagram sent an empty media response. " +
            "Check if this post is accessible in your browser without being logged-in. " +
            "If it is not, then use --cookies-from-browser or --cookies for the authentication."
        )
        XCTAssertTrue(YTDLPService.shouldRetryWithCookies(igError))
    }

    /// 既有的 YouTube 需登入訊號仍應觸發重試（避免迴歸）。
    func testShouldRetryWithCookiesForKnownLoginSignals() {
        let signals = [
            "ERROR: Private video. Sign in if you've been granted access to this video",
            "ERROR: This video is age-restricted and only available on YouTube",
            "ERROR: Join this channel to get access to members-only content",
            "ERROR: Sign in to confirm you're not a bot"
        ]
        for message in signals {
            XCTAssertTrue(
                YTDLPService.shouldRetryWithCookies(.executionFailed(message)),
                "應觸發帶 cookies 重試：\(message)"
            )
        }
    }

    /// 公開影片的其他錯誤不應觸發帶 cookies 重試（避免把公開影片推回會觸發 403 的帶 cookies 路徑）。
    func testShouldNotRetryWithCookiesForPublicVideoErrors() {
        let nonLoginErrors = [
            "ERROR: [youtube] abc123: Video unavailable",
            "ERROR: Unable to download webpage: HTTP Error 404: Not Found",
            "ERROR: Unsupported URL: https://www.threads.com/@user/post/abc/media"
        ]
        for message in nonLoginErrors {
            XCTAssertFalse(
                YTDLPService.shouldRetryWithCookies(.executionFailed(message)),
                "不應觸發帶 cookies 重試：\(message)"
            )
        }
    }

    /// 非 executionFailed 的錯誤一律不重試。
    func testShouldNotRetryWithCookiesForNonExecutionErrors() {
        XCTAssertFalse(YTDLPService.shouldRetryWithCookies(.notFound))
        XCTAssertFalse(YTDLPService.shouldRetryWithCookies(.cancelled))
        XCTAssertFalse(YTDLPService.shouldRetryWithCookies(.parseError("bad output")))
    }

    // MARK: - DownloadResultHolder 測試

    func testDownloadResultHolderSetOutputPath() {
        let holder = DownloadResultHolder()
        XCTAssertNil(holder.outputPath)

        holder.setOutputPath("/path/to/video.mp4")
        XCTAssertEqual(holder.outputPath, "/path/to/video.mp4")
    }

    func testDownloadResultHolderErrorContext() {
        let holder = DownloadResultHolder()
        XCTAssertNil(holder.errorContext)

        holder.appendError("ERROR: Video unavailable")
        XCTAssertEqual(holder.errorContext, "ERROR: Video unavailable")
    }

    func testDownloadResultHolderThreadSafety() {
        let holder = DownloadResultHolder()
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                holder.setOutputPath("/path/\(i)")
                _ = holder.outputPath
                holder.appendError("Error \(i)")
                _ = holder.errorContext
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - 輔助方法（複製 YTDLPService 的邏輯以供測試）

    private func parseProgress(from line: String) -> Double? {
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

    private func extractOutputPath(from line: String) -> String {
        return line.replacingOccurrences(of: "[download] Destination: ", with: "")
    }

    private func extractMergerOutputPath(from line: String) -> String {
        return line.replacingOccurrences(of: "[Merger] Merging formats into \"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    // MARK: - 字幕檔過濾測試

    /// 模擬 YTDLPService 中過濾字幕檔的邏輯
    private func filterMediaFiles(from paths: [String]) -> [String] {
        let subtitleExtensions: Set<String> = ["srt", "vtt", "ass", "ssa", "sub", "sbv", "ttml"]
        return paths.filter { path in
            let ext = (path as NSString).pathExtension.lowercased()
            return !subtitleExtensions.contains(ext)
        }
    }

    func testFilterMediaFilesExcludesSrtSubtitles() {
        let files = [
            "/Downloads/video.f137.mp4",
            "/Downloads/video.f140.m4a",
            "/Downloads/video.zh-TW.srt",
            "/Downloads/video.zh-Hans.srt"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 2)
        XCTAssertTrue(mediaFiles.contains("/Downloads/video.f137.mp4"))
        XCTAssertTrue(mediaFiles.contains("/Downloads/video.f140.m4a"))
    }

    func testFilterMediaFilesExcludesVttSubtitles() {
        let files = [
            "/Downloads/video.mp4",
            "/Downloads/video.en.vtt",
            "/Downloads/video.ja.vtt"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 1)
        XCTAssertEqual(mediaFiles.first, "/Downloads/video.mp4")
    }

    func testFilterMediaFilesExcludesAssSubtitles() {
        let files = [
            "/Downloads/video.mkv",
            "/Downloads/video.ass"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 1)
        XCTAssertEqual(mediaFiles.first, "/Downloads/video.mkv")
    }

    func testFilterMediaFilesKeepsOnlyMediaWhenOnlySubtitlesExist() {
        let files = [
            "/Downloads/video.zh-TW.srt",
            "/Downloads/video.zh-Hans.srt",
            "/Downloads/video.en.vtt"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 0)
    }

    func testFilterMediaFilesKeepsAllMediaFiles() {
        let files = [
            "/Downloads/video.mp4",
            "/Downloads/audio.m4a",
            "/Downloads/video.webm"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 3)
    }

    func testFilterMediaFilesHandlesEmptyArray() {
        let files: [String] = []
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 0)
    }

    func testFilterMediaFilesIsCaseInsensitive() {
        let files = [
            "/Downloads/video.mp4",
            "/Downloads/video.SRT",
            "/Downloads/video.Vtt"
        ]
        let mediaFiles = filterMediaFiles(from: files)
        XCTAssertEqual(mediaFiles.count, 1)
        XCTAssertEqual(mediaFiles.first, "/Downloads/video.mp4")
    }

    /// 測試合併檢測邏輯：多個字幕檔不應觸發合併失敗
    func testMergeDetectionWithMultipleSubtitlesOnly() {
        // 模擬情境：合併成功後，只剩下字幕檔
        let existingFiles = [
            "/Downloads/video.zh-TW.srt",
            "/Downloads/video.zh-Hans.srt"
        ]
        let mediaFiles = filterMediaFiles(from: existingFiles)
        // 應該不會觸發合併失敗（mediaFiles.count <= 1）
        XCTAssertFalse(mediaFiles.count > 1, "多個字幕檔不應觸發合併失敗檢測")
    }

    /// 測試合併檢測邏輯：字幕檔 + 單一合併後媒體檔不應觸發錯誤
    func testMergeDetectionWithSubtitlesAndMergedMedia() {
        // 模擬情境：合併成功，有字幕檔和最終的 mp4
        let existingFiles = [
            "/Downloads/video.zh-TW.srt",
            "/Downloads/video.zh-Hans.srt",
            "/Downloads/video.mp4"
        ]
        let mediaFiles = filterMediaFiles(from: existingFiles)
        // 只有 1 個媒體檔，不應觸發合併失敗
        XCTAssertEqual(mediaFiles.count, 1, "合併成功後應只有一個媒體檔")
        XCTAssertFalse(mediaFiles.count > 1, "字幕檔 + 單一媒體檔不應觸發合併失敗檢測")
    }

    /// 測試合併檢測邏輯：多個媒體檔應觸發合併失敗
    func testMergeDetectionWithMultipleMediaFiles() {
        // 模擬情境：合併失敗，視頻和音頻檔都還在
        let existingFiles = [
            "/Downloads/video.f137.mp4",
            "/Downloads/video.f140.m4a"
        ]
        let mediaFiles = filterMediaFiles(from: existingFiles)
        // 有 2 個媒體檔，應觸發合併失敗
        XCTAssertTrue(mediaFiles.count > 1, "多個媒體檔應觸發合併失敗檢測")
    }

    /// 測試合併檢測邏輯：字幕檔 + 多個媒體檔應觸發合併失敗
    func testMergeDetectionWithSubtitlesAndMultipleMediaFiles() {
        // 模擬情境：合併失敗，有字幕檔，但視頻和音頻都還在
        let existingFiles = [
            "/Downloads/video.zh-TW.srt",
            "/Downloads/video.f137.mp4",
            "/Downloads/video.f140.m4a"
        ]
        let mediaFiles = filterMediaFiles(from: existingFiles)
        // 有 2 個媒體檔，應觸發合併失敗
        XCTAssertTrue(mediaFiles.count > 1, "字幕檔 + 多個媒體檔應觸發合併失敗檢測")
    }

    // MARK: - stderr 行緩衝測試（LineBuffer）

    /// 迴歸測試：yt-dlp 的錯誤訊息被 pipe chunk 邊界切斷時，不可遺失內容。
    /// 實際案例中 "ERROR: [download] Got error: ... Giving up after 10 retries"
    /// 被切成 "ERROR:" 與 "[download] Got error: ..." 兩段，前者被當成錯誤存下，
    /// 後者因不含大寫 ERROR 被丟棄，UI 與 log 只剩無意義的 "ERROR:"。
    func testLineBufferReassemblesLineSplitAcrossChunks() {
        let buffer = LineBuffer()

        XCTAssertEqual(buffer.feed(Data("ERROR: ".utf8)), [], "沒有換行時不應輸出任何行")
        XCTAssertEqual(
            buffer.feed(Data("[download] Got error: 912 bytes read, 10354660 more expected.\n".utf8)),
            ["ERROR: [download] Got error: 912 bytes read, 10354660 more expected."],
            "跨 chunk 的行應被組回完整一行"
        )
    }

    func testLineBufferSplitsOnCarriageReturnForProgressUpdates() {
        let buffer = LineBuffer()
        let lines = buffer.feed(Data("[download]  10.0% of 1.00MiB\r[download]  20.0% of 1.00MiB\r".utf8))

        XCTAssertEqual(lines, ["[download]  10.0% of 1.00MiB", "[download]  20.0% of 1.00MiB"])
    }

    func testLineBufferHoldsIncompleteTailUntilTerminated() {
        let buffer = LineBuffer()

        XCTAssertEqual(buffer.feed(Data("first\nsecond".utf8)), ["first"], "未結束的 second 應留在緩衝區")
        XCTAssertEqual(buffer.feed(Data(" half\n".utf8)), ["second half"])
    }

    func testLineBufferFlushReturnsRemainderWithoutTrailingNewline() {
        let buffer = LineBuffer()

        _ = buffer.feed(Data("done\nERROR: no newline at end".utf8))
        XCTAssertEqual(buffer.flush(), "ERROR: no newline at end")
        XCTAssertNil(buffer.flush(), "flush 後緩衝區應清空")
    }

    /// 迴歸測試：中文標題的影片，多位元組字元可能被切在 chunk 邊界。
    /// 若在 String 層緩衝，半段位元組會讓 String(data:encoding:.utf8) 回傳 nil，
    /// 整個 chunk 連同檔案路徑一起被丟棄。改在 Data 層緩衝可避免。
    func testLineBufferHandlesMultibyteCharacterSplitAcrossChunks() {
        let buffer = LineBuffer()
        let line = "[download] Destination: /Downloads/中文標題.mp4\n"
        let bytes = Array(line.utf8)

        // 切在「中」這個字（3 bytes）的正中間
        let splitIndex = Array("[download] Destination: /Downloads/中".utf8).count - 1
        XCTAssertEqual(buffer.feed(Data(bytes[..<splitIndex])), [], "不完整的位元組序列不應輸出")
        XCTAssertEqual(
            buffer.feed(Data(bytes[splitIndex...])),
            ["[download] Destination: /Downloads/中文標題.mp4"],
            "跨 chunk 的多位元組字元應被正確還原"
        )
    }

    // MARK: - 錯誤行判斷測試（isErrorLine）

    /// 只有前綴沒有內容的 "ERROR:" 不具診斷價值，不應蓋掉後續有意義的訊息。
    func testIsErrorLineRejectsBareErrorPrefix() {
        XCTAssertFalse(YTDLPService.isErrorLine("ERROR:"))
        XCTAssertFalse(YTDLPService.isErrorLine("ERROR:   "))
        XCTAssertFalse(YTDLPService.isErrorLine(""))
    }

    func testIsErrorLineAcceptsErrorWithContent() {
        XCTAssertTrue(YTDLPService.isErrorLine("ERROR: [youtube] abc123: Video unavailable"))
    }

    /// 下載器自身的失敗訊息不含大寫 ERROR，卻常是唯一說明原因的一行。
    func testIsErrorLineAcceptsDownloaderFailureWithoutErrorPrefix() {
        XCTAssertTrue(
            YTDLPService.isErrorLine("[download] Got error: 912 bytes read, 10354660 more expected.")
        )
        XCTAssertTrue(
            YTDLPService.isErrorLine("[download] Giving up after 10 retries")
        )
    }

    func testIsErrorLineIgnoresNormalOutput() {
        XCTAssertFalse(YTDLPService.isErrorLine("[download]  45.2% of 100.00MiB at 5.00MiB/s"))
        XCTAssertFalse(YTDLPService.isErrorLine("[download] Destination: /Downloads/video.mp4"))
    }

    private struct YTDLPFixture {
        let directory: URL
        let executable: URL
        let log: URL
        let pid: URL
        let activeMarker: URL
        let oldMarker: URL
        let newOutput: URL
        let writerPID: URL
    }

    private func makeYTDLPFixture() throws -> YTDLPFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tubify-YTDLPFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let executable = directory.appendingPathComponent("yt-dlp-fixture")
        let log = directory.appendingPathComponent("invocations.log")
        let pid = directory.appendingPathComponent("process.pid")
        let activeMarker = directory.appendingPathComponent("active.marker")
        let oldMarker = directory.appendingPathComponent("old.marker")
        let newOutput = directory.appendingPathComponent("new.mp4")
        let writerPID = directory.appendingPathComponent("writer.pid")
        let script = """
        #!/bin/sh
        log=\(shellQuote(log.path))
        pid=\(shellQuote(pid.path))
        echo "$*" >> "$log"
        echo "$$" > "$pid"
        case "$*" in
          *ACTIVE*)
            touch \(shellQuote(activeMarker.path))
            exec /usr/bin/tail -f /dev/null
            ;;
          *OLD*)
            touch \(shellQuote(oldMarker.path))
            echo 'ERROR: unable to download video data: HTTP Error 403: Forbidden' >&2
            sleep 0.2
            exit 1
            ;;
          *DRAIN_403*)
            if [ "$(grep -c 'DRAIN_403' "$log" 2>/dev/null || true)" -eq 1 ]; then
              (sleep 0.05; printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2) &
              exit 1
            fi
            touch \(shellQuote(newOutput.path))
            printf 'FINAL_PATH:%s\\n' \(shellQuote(newOutput.path))
            ;;
          *STARVING_STDOUT_403*)
            if [ "$(grep -c 'STARVING_STDOUT_403' "$log" 2>/dev/null || true)" -eq 1 ]; then
              (
                i=0
                while [ "$i" -lt 512 ]; do
                  printf 'background stderr output\\n' >&2
                  i=$((i + 1))
                done
                sleep 0.05
                printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2 || exit
              ) &
              (
                while true; do
                  printf 'background stdout output\\n' || exit
                  sleep 0.01
                done
              ) &
              echo "$!" > \(shellQuote(writerPID.path))
              exit 1
            fi
            touch \(shellQuote(newOutput.path))
            printf 'FINAL_PATH:%s\\n' \(shellQuote(newOutput.path))
            ;;
          *STDOUT_EOF_IDLE_STDERR_403*)
            if [ "$(grep -c 'STDOUT_EOF_IDLE_STDERR_403' "$log" 2>/dev/null || true)" -eq 1 ]; then
              (
                exec 1>/dev/null
                sleep 0.2
                printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2
                sleep 0.1
              ) &
              echo "$!" > \(shellQuote(writerPID.path))
              exit 1
            fi
            touch \(shellQuote(newOutput.path))
            printf 'FINAL_PATH:%s\\n' \(shellQuote(newOutput.path))
            ;;
          *MULTILINE_403*)
            printf '[download] Giving up after 10 retries\\n' >&2
            printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2
            sleep 0.2
            exit 1
            ;;
          *HANG_WRITER*)
            (
              while true; do
                printf 'background writer output\\n' >&2 || exit
                sleep 0.01
              done
            ) &
            echo "$!" > \(shellQuote(writerPID.path))
            exit 1
            ;;
          *NEW*)
            touch \(shellQuote(newOutput.path))
            printf 'FINAL_PATH:%s\\n' \(shellQuote(newOutput.path))
            ;;
        esac
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        return YTDLPFixture(
            directory: directory,
            executable: executable,
            log: log,
            pid: pid,
            activeMarker: activeMarker,
            oldMarker: oldMarker,
            newOutput: newOutput,
            writerPID: writerPID
        )
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func waitForFile(_ url: URL) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    private func terminateProcess(at pidFile: URL) {
        guard let pid = try? String(contentsOf: pidFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !pid.isEmpty else {
            return
        }

        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/kill")
        probe.arguments = ["-0", pid]
        try? probe.run()
        probe.waitUntilExit()
        guard probe.terminationStatus == 0 else { return }

        let terminate = Process()
        terminate.executableURL = URL(fileURLWithPath: "/bin/kill")
        terminate.arguments = ["-TERM", pid]
        try? terminate.run()
        terminate.waitUntilExit()

        let stillRunning = Process()
        stillRunning.executableURL = URL(fileURLWithPath: "/bin/kill")
        stillRunning.arguments = ["-0", pid]
        try? stillRunning.run()
        stillRunning.waitUntilExit()
        guard stillRunning.terminationStatus == 0 else { return }

        let forceTerminate = Process()
        forceTerminate.executableURL = URL(fileURLWithPath: "/bin/kill")
        forceTerminate.arguments = ["-KILL", pid]
        try? forceTerminate.run()
        forceTerminate.waitUntilExit()
    }

    private func waitForProcessExit(_ pid: String) async -> Bool {
        guard !pid.isEmpty else { return false }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let probe = Process()
            probe.executableURL = URL(fileURLWithPath: "/bin/kill")
            probe.arguments = ["-0", pid]
            do {
                try probe.run()
                probe.waitUntilExit()
                if probe.terminationStatus != 0 {
                    return true
                }
            } catch {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}
