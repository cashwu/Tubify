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

    /// 同時是「沒有 cookies fallback 時，video-data 403 仍保留原地 backoff」的回歸測試。
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

        // video-data 403 多為缺少 GVS PO Token：重試同一條不帶 cookies 的指令不會成功，
        // 因此應立刻切換 cookies template，且切換前不做 backoff。
        let target403Scripted = ScriptedDownloadFlow([
            .failure(target403), .failure(target403), .success("/Downloads/po-token.mp4")
        ])
        var cookieProviderCalled = false
        var sleepSlices: [UInt64] = []
        let target403Output = try? await YTDLPService.shared.executeDownloadFlow(
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
            sleeper: { sleepSlices.append($0) },
            cancellationProbe: { false }
        )
        XCTAssertTrue(cookieProviderCalled)
        XCTAssertEqual(target403Output, "/Downloads/po-token.mp4")
        // 第一次 403 直接切 cookies（無 backoff），cookies template 內才保留 403 backoff retry。
        XCTAssertEqual(
            target403Scripted.templates,
            ["NO_COOKIES_TEMPLATE", "COOKIES_TEMPLATE", "COOKIES_TEMPLATE"]
        )
        XCTAssertEqual(sleepSlices.reduce(0, +), 2_000_000_000)

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

    /// Safari cookies 導出失敗（多半是缺少完整磁碟存取權限）時，provider 回傳 nil。
    /// 此時不得帶著仍含 `--cookies-from-browser` 的 template 重試——那會讓 yt-dlp 子進程掛起——
    /// 但也不能連帶失去對暫時性 403 的韌性，應退回原 template 補做 backoff。
    func testExecuteDownloadFlowFallsBackToBackoffWhenCookieExportFails() async throws {
        let target403 = YTDLPError.executionFailed("unable to download video data: HTTP Error 403: Forbidden")
        // 第 1 次是切換前的 attempt（無 backoff），第 2 次起才是退回原 template 的 backoff retry。
        let scripted = ScriptedDownloadFlow([
            .failure(target403), .failure(target403), .success("/Downloads/video.mp4")
        ])
        var cookieProviderCalled = false
        var sleepSlices: [UInt64] = []

        let outputPath = try await YTDLPService.shared.executeDownloadFlow(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=no-full-disk-access",
            firstTemplate: "NO_COOKIES_TEMPLATE",
            cookieTemplateProvider: {
                cookieProviderCalled = true
                return nil
            },
            outputDirectory: "/Downloads",
            subtitleSelection: nil,
            onProgress: { _ in },
            attemptExecutor: { template in try scripted.execute(template: template) },
            sleeper: { sleepSlices.append($0) },
            cancellationProbe: { false }
        )

        XCTAssertTrue(cookieProviderCalled)
        XCTAssertEqual(outputPath, "/Downloads/video.mp4")
        XCTAssertEqual(
            scripted.templates,
            ["NO_COOKIES_TEMPLATE", "NO_COOKIES_TEMPLATE", "NO_COOKIES_TEMPLATE"]
        )
        XCTAssertEqual(sleepSlices.reduce(0, +), 2_000_000_000)
    }

    /// 導出失敗且錯誤屬於「需要登入」時，重試同一條指令無益，應直接拋出。
    func testExecuteDownloadFlowThrowsLoginErrorWhenCookieExportFails() async {
        let loginMessage = "ERROR: Sign in to confirm you're not a bot"
        let scripted = ScriptedDownloadFlow([.failure(.executionFailed(loginMessage))])
        var sleepCalled = false

        do {
            _ = try await YTDLPService.shared.executeDownloadFlow(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=login-no-full-disk-access",
                firstTemplate: "NO_COOKIES_TEMPLATE",
                cookieTemplateProvider: { nil },
                outputDirectory: "/Downloads",
                subtitleSelection: nil,
                onProgress: { _ in },
                attemptExecutor: { template in try scripted.execute(template: template) },
                sleeper: { _ in sleepCalled = true },
                cancellationProbe: { false }
            )
            XCTFail("cookies 導出失敗的登入錯誤應直接拋出")
        } catch let error as YTDLPError {
            guard case .executionFailed(let message) = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
            XCTAssertEqual(message, loginMessage)
        } catch {
            XCTFail("錯誤類型不符：\(error)")
        }

        XCTAssertEqual(scripted.templates, ["NO_COOKIES_TEMPLATE"])
        XCTAssertFalse(sleepCalled)
    }

    /// `isDownloadVideoData403` 是 cookies fallback 的觸發訊號，與 backoff 訊號
    /// `isRetryableDownload403`（見 testIsRetryableDownload403OnlyMatchesTargetVideoDataError）
    /// 的關鍵差異是：yt-dlp 已自行放棄（"Giving up after"）時它仍為 true。
    func testDownloadVideoData403CoversGivingUpCase() {
        let givingUp = YTDLPError.executionFailed(
            "ERROR: unable to download video data: HTTP Error 403: Forbidden; Giving up after 10 retries"
        )
        XCTAssertTrue(YTDLPService.isDownloadVideoData403(givingUp))
        XCTAssertFalse(YTDLPService.isRetryableDownload403(givingUp))

        XCTAssertTrue(YTDLPService.isDownloadVideoData403(
            .executionFailed("ERROR: unable to download video data: HTTP Error 403: Forbidden")
        ))
        XCTAssertFalse(YTDLPService.isDownloadVideoData403(
            .executionFailed("ERROR: unable to download video data: HTTP Error 429: Too Many Requests")
        ))
        XCTAssertFalse(YTDLPService.isDownloadVideoData403(.cancelled))
    }

    func testEndedLiveErrorClassification() {
        let endedLiveError = "ERROR: [youtube] TR_NgGeXWGc: This live event has ended."
        let unavailableError = "ERROR: [youtube] abc123: Video unavailable"

        XCTAssertEqual(YTDLPErrorClassification.classify(endedLiveError), .endedLive)
        XCTAssertEqual(YTDLPErrorClassification.classify(unavailableError), .other)
    }

    // MARK: - 下載範本注入 extractor args

    /// argv 中等於 `--extractor-args` 的位置；用於同時斷言注入次數與其值。
    private func extractorArgsPositions(in arguments: [String]) -> [Int] {
        arguments.indices.filter { arguments[$0] == "--extractor-args" }
    }

    /// 選定音軌語言時，第一次 invocation 必須帶上共用常數指定的 player client。
    func testDownloadWithSelectedAudioLanguageInjectsExtractorArgs() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=extractor-args",
            commandTemplate: "NEW -f \"bv*+ba\" $youtubeUrl",
            outputDirectory: fixture.directory.path,
            audioSelection: AudioSelection(selectedLanguage: "ja"),
            onProgress: { _ in }
        )

        let arguments = try XCTUnwrap(fixture.arguments(at: 1))
        let positions = extractorArgsPositions(in: arguments)
        XCTAssertEqual(positions.count, 1)
        let flagIndex = try XCTUnwrap(positions.first)
        XCTAssertTrue(arguments.indices.contains(flagIndex + 1), "--extractor-args 後方缺少值")
        XCTAssertEqual(arguments[flagIndex + 1], YTDLPService.youtubePlayerClientArgumentValue)
    }

    /// 未選定語言時不得注入。兩個 case 缺一不可：`audioSelection` 為 nil 會在
    /// `if let audioSel` 就出局，走不到 `selectedLanguage` 的判定；持久化的舊任務可能帶著
    /// `selectedLanguage` 為 nil 的選擇復原，那條路徑只有第二個 case 走得到。
    func testDownloadWithoutSelectedAudioLanguageOmitsExtractorArgs() async throws {
        for audioSelection in [nil, AudioSelection(selectedLanguage: nil)] {
            let fixture = try makeYTDLPFixture()
            defer { try? FileManager.default.removeItem(at: fixture.directory) }

            let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
            _ = try await service.download(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=no-audio-selection",
                commandTemplate: "NEW -f \"bv*+ba\" $youtubeUrl",
                outputDirectory: fixture.directory.path,
                audioSelection: audioSelection,
                onProgress: { _ in }
            )

            let arguments = try XCTUnwrap(fixture.arguments(at: 1))
            XCTAssertFalse(
                arguments.contains(where: { $0 == "--extractor-args" || $0.hasPrefix("--extractor-args=") }),
                "audioSelection=\(String(describing: audioSelection)) 不應注入 extractor args"
            )
        }
    }

    /// 範本已自帶 `--extractor-args` 時不覆蓋也不重複注入。範本同時具備語言選擇與 `-f`，
    /// 確保測試走到的是「已含引數」的判定分支，而非在更早的條件就出局。
    func testDownloadDoesNotOverrideTemplateProvidedExtractorArgs() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=template-extractor-args",
            commandTemplate: "NEW -f \"bv*+ba\" --extractor-args \"youtube:player_client=web_embedded\" $youtubeUrl",
            outputDirectory: fixture.directory.path,
            audioSelection: AudioSelection(selectedLanguage: "ja"),
            onProgress: { _ in }
        )

        let arguments = try XCTUnwrap(fixture.arguments(at: 1))
        let positions = extractorArgsPositions(in: arguments)
        XCTAssertEqual(positions.count, 1)
        let flagIndex = try XCTUnwrap(positions.first)
        XCTAssertTrue(arguments.indices.contains(flagIndex + 1), "--extractor-args 後方缺少值")
        XCTAssertEqual(arguments[flagIndex + 1], "youtube:player_client=web_embedded")
    }

    /// 範本含 cookies 時，第一次 invocation 已移除 cookies 但仍帶 extractor args。
    /// 兩項合起來可鑑別「注入晚於 `firstTemplate` 計算」的錯誤實作：那種寫法下第 1 次
    /// invocation 不會帶有 extractor args。
    func testDownloadInjectsExtractorArgsBeforeCookiesAreStripped() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=cookies-then-extractor-args",
            commandTemplate: "NEW -f \"bv*+ba\" --cookies-from-browser safari $youtubeUrl",
            outputDirectory: fixture.directory.path,
            audioSelection: AudioSelection(selectedLanguage: "ja"),
            onProgress: { _ in }
        )

        let arguments = try XCTUnwrap(fixture.arguments(at: 1))
        XCTAssertTrue(arguments.contains("--extractor-args"))
        XCTAssertTrue(arguments.contains(YTDLPService.youtubePlayerClientArgumentValue))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
    }

    /// cookies 重試路徑把 provider 回傳的範本原樣送進 argv：兩次 invocation 都帶 extractor args，
    /// 且值中的 `,` 未被 `parseCommandArguments` 切斷。不傳 attemptExecutor，讓 fixture 實際執行。
    func testCookieRetryPreservesExtractorArgsInArgv() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let extractorArgs = "--extractor-args \"\(YTDLPService.youtubePlayerClientArgumentValue)\""
        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.executeDownloadFlow(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=cookie-retry-extractor-args",
            firstTemplate: "OLD -f \"bv*+ba[language=ja]\" \(extractorArgs) $youtubeUrl",
            cookieTemplateProvider: {
                "NEW -f \"bv*+ba[language=ja]\" --cookies-from-browser safari \(extractorArgs) $youtubeUrl"
            },
            outputDirectory: fixture.directory.path,
            subtitleSelection: nil,
            onProgress: { _ in }
        )

        XCTAssertEqual(fixture.invocationCount, 2)
        for index in 1...2 {
            let arguments = try XCTUnwrap(fixture.arguments(at: index))
            XCTAssertEqual(extractorArgsPositions(in: arguments).count, 1, "第 \(index) 次 invocation")
            XCTAssertTrue(
                arguments.contains(YTDLPService.youtubePlayerClientArgumentValue),
                "第 \(index) 次 invocation 的 extractor args 值被切斷"
            )
        }
        XCTAssertFalse(try XCTUnwrap(fixture.arguments(at: 1)).contains("--cookies-from-browser"))
        XCTAssertTrue(try XCTUnwrap(fixture.arguments(at: 2)).contains("--cookies-from-browser"))
    }

    /// 移除 cookies 參數的處理不得順帶移除已注入的 extractor args。
    func testRemoveSafariCookiesPreservesExtractorArgs() {
        let template = "yt-dlp -f \"bv*+ba[language=ja]\" --cookies-from-browser safari "
            + "--extractor-args \"\(YTDLPService.youtubePlayerClientArgumentValue)\" $youtubeUrl"

        let stripped = SafariCookiesService.shared.removeSafariCookies(template)

        XCTAssertTrue(stripped.contains("--extractor-args"))
        XCTAssertTrue(stripped.contains(YTDLPService.youtubePlayerClientArgumentValue))
        XCTAssertFalse(stripped.contains("--cookies-from-browser"))
    }

    // MARK: - format 語言限制

    /// 以 fixture 執行一次帶語言選擇的下載，回傳 argv 中 `-f` 之後緊接的元素。
    private func recordedFormatValue(
        template: String,
        language: String,
        marker: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> String {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=\(marker)",
            commandTemplate: template,
            outputDirectory: fixture.directory.path,
            audioSelection: AudioSelection(selectedLanguage: language),
            onProgress: { _ in }
        )

        let arguments = try XCTUnwrap(fixture.arguments(at: 1), file: file, line: line)
        let formatIndex = try XCTUnwrap(arguments.firstIndex(of: "-f"), file: file, line: line)
        XCTAssertTrue(arguments.indices.contains(formatIndex + 1), "-f 後方缺少值", file: file, line: line)
        return arguments[formatIndex + 1]
    }

    /// 預設範本的每一個 alternative 都帶上語言限制，且尾端不再附加未受限的原始字串。
    func testDefaultFormatTemplateConstrainsEveryAlternative() async throws {
        let formatValue = try await recordedFormatValue(
            template: "NEW -f \"bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b\" $youtubeUrl",
            language: "ja",
            marker: "default-format"
        )

        XCTAssertEqual(formatValue, "bv*[ext=mp4]+ba[ext=m4a][language=ja]/bv*+ba[language=ja]/b[language=ja]")
    }

    /// 語言限制落在 alternative 的最後一個 `+` 組成部分。
    func testLanguageConstraintLandsOnLastPlusPart() async throws {
        let formatValue = try await recordedFormatValue(
            template: "NEW -f \"bv+ba\" $youtubeUrl",
            language: "ja",
            marker: "last-plus-part"
        )

        XCTAssertEqual(formatValue, "bv+ba[language=ja]")
    }

    /// 中括號內的 `/` 不參與切分。以完整字串相等為斷言：「alternative 數量不變」這類計數
    /// 斷言在 bracket-aware 與 naive 兩種實作下都會成立，沒有鑑別力。
    func testSeparatorsInsideBracketsAreNotSplitPoints() async throws {
        let formatValue = try await recordedFormatValue(
            template: "NEW -f \"ba[format_note*=A/B]+bv\" $youtubeUrl",
            language: "ja",
            marker: "bracketed-separator"
        )

        XCTAssertEqual(formatValue, "ba[format_note*=A/B]+bv[language=ja]")
    }

    /// `,` 分隔的獨立下載群組各自受限；不納入切分層級時，`,` 之前的群組會完全沒有語言限制。
    func testCommaSeparatedGroupsAreEachConstrained() async throws {
        let formatValue = try await recordedFormatValue(
            template: "NEW -f \"bv+ba,b\" $youtubeUrl",
            language: "ja",
            marker: "comma-groups"
        )

        XCTAssertEqual(formatValue, "bv+ba[language=ja],b[language=ja]")
    }

    /// 範本不含 `-f` 與 `--format` 時補上受限的預設 format。
    func testTemplateWithoutFormatArgumentGetsConstrainedDefault() async throws {
        let formatValue = try await recordedFormatValue(
            template: "NEW $youtubeUrl",
            language: "ja",
            marker: "no-format-argument"
        )

        XCTAssertEqual(formatValue, "bv*+ba[language=ja]/b[language=ja]")
    }

    /// 取不到選定語言時以失敗結束：format 不可用的訊息不觸發任何重試，
    /// invocation 恰為 1 次，錯誤沿既有 `YTDLPError.executionFailed` 路徑呈現。
    func testUnavailableFormatFailsWithoutAnyRetry() async throws {
        let formatUnavailableMessage = "ERROR: [youtube] video: Requested format is not available. "
            + "Use --list-formats for a list of available formats"

        XCTAssertFalse(YTDLPService.shouldRetryWithCookies(.executionFailed(formatUnavailableMessage)))

        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.download(
                taskId: UUID(),
                url: "https://youtube.com/watch?v=format-unavailable",
                commandTemplate: "FORMAT_UNAVAILABLE -f \"bv*+ba\" --cookies-from-browser safari $youtubeUrl",
                outputDirectory: fixture.directory.path,
                audioSelection: AudioSelection(selectedLanguage: "ja"),
                onProgress: { _ in }
            )
            XCTFail("選定語言的 format 不可用時應以失敗結束")
        } catch let error as YTDLPError {
            guard case .executionFailed(let message) = error else {
                return XCTFail("錯誤類型不符：\(error)")
            }
            XCTAssertTrue(
                message.contains("Requested format is not available"),
                "錯誤訊息未帶上 yt-dlp 的原始訊息：\(message)"
            )
        }

        XCTAssertEqual(fixture.invocationCount, 1)
    }

    // MARK: - 登入訊號分類測試（indicatesLoginRequired(message:)）

    /// 字串入口對既有訊號清單中的代表性訊息（私人影片、會員限定、年齡限制、bot 驗證）
    /// 判定為需登入。
    func testIndicatesLoginRequiredForKnownLoginMessages() {
        let loginMessages = [
            "ERROR: [youtube] abc123: Private video. Sign in if you've been granted access to this video",
            "ERROR: [youtube] abc123: Join this channel to get access to members-only content like this video",
            "ERROR: [youtube] abc123: This video is age-restricted and only available on YouTube. For more information, see https://support.google.com/youtube/answer/2802167",
            "ERROR: [youtube] abc123: Sign in to confirm you're not a bot. Use --cookies-from-browser or --cookies for the authentication."
        ]
        for message in loginMessages {
            XCTAssertTrue(
                YTDLPService.indicatesLoginRequired(message: message),
                "應判定為需登入：\(message)"
            )
        }
    }

    /// 一般失敗訊息與無法解碼 stderr 時的 `未知錯誤` fallback 字串不得判定為需登入。
    func testIndicatesLoginRequiredIsFalseForNonLoginMessages() {
        let nonLoginMessages = [
            "ERROR: Unable to download webpage: The read operation timed out",
            "ERROR: [youtube] abc123: Video unavailable",
            "未知錯誤"
        ]
        for message in nonLoginMessages {
            XCTAssertFalse(
                YTDLPService.indicatesLoginRequired(message: message),
                "不應判定為需登入：\(message)"
            )
        }
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



    // MARK: - 清理的 seam 測試（失敗處置與刪除原語）

    /// 以 `attemptExecutor` 驅動 `executeDownloadFlow`，回傳 output path 與觀察到的清理結果。
    private func runCleanupFlow(
        outputDirectory: String,
        attempt: @escaping (String) async throws -> String
    ) async throws -> (path: String, outcome: CleanupOutcome?) {
        var observed: CleanupOutcome?
        let path = try await YTDLPService.shared.executeDownloadFlow(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=cleanup-seam",
            firstTemplate: "yt-dlp $youtubeUrl",
            cookieTemplateProvider: nil,
            outputDirectory: outputDirectory,
            subtitleSelection: nil,
            onProgress: { _ in },
            attemptExecutor: attempt,
            cleanupObserver: { observed = $0 }
        )
        return (path, observed)
    }

    private func makeCleanupSeamDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tubify-CleanupSeam-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 建立一個滿足除了受測條件以外全部條件的候選檔，其 mtime 早於最終輸出檔。
    @discardableResult
    private func makeCandidate(_ directory: URL, _ name: String, mtime: Date) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try "partial".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    private func makeFinalOutput(_ directory: URL, _ name: String, mtime: Date) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try "final".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: url.path)
        return url
    }

    func testCleanupAbandonsWhenFinalPathParentDiffersFromOutputDirectory() async throws {
        let outputDirectory = try makeCleanupSeamDirectory()
        let elsewhere = try makeCleanupSeamDirectory()
        defer {
            try? FileManager.default.removeItem(at: outputDirectory)
            try? FileManager.default.removeItem(at: elsewhere)
        }

        let past = Date(timeIntervalSince1970: 1_000_000)
        // outputDirectory 必須實際存在且快照可取得，否則會先命中 .snapshotUnavailable
        let finalOutput = try makeFinalOutput(elsewhere, "video.mp4", mtime: past.addingTimeInterval(60))

        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            return finalOutput.path
        }

        XCTAssertEqual(result.outcome, .abandoned(.outputDirectoryMismatch))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent("video.f401.mp4.part").path
        ))
    }

    func testCleanupAbandonsWhenFinalOutputIsMissing() async throws {
        let outputDirectory = try makeCleanupSeamDirectory()
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let past = Date(timeIntervalSince1970: 1_000_000)
        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            // 區辨性候選檔：若沒有 finalPathUnavailable 這道 guard 就會被刪除
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            // 刻意不建立所回傳的 final path
            return outputDirectory.appendingPathComponent("video.mp4").path
        }

        XCTAssertEqual(result.outcome, .abandoned(.finalPathUnavailable))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent("video.f401.mp4.part").path
        ))
    }

    func testCleanupAbandonsWhenSnapshotIsUnavailable() async throws {
        let parent = try makeCleanupSeamDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        // 取得快照時 outputDirectory 尚不存在
        let outputDirectory = parent.appendingPathComponent("late", isDirectory: true)

        let past = Date(timeIntervalSince1970: 1_000_000)
        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            let final = try self.makeFinalOutput(
                outputDirectory, "video.mp4", mtime: past.addingTimeInterval(60)
            )
            return final.path
        }

        XCTAssertEqual(result.outcome, .abandoned(.snapshotUnavailable))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent("video.f401.mp4.part").path
        ))
    }

    func testCleanupAbandonsWhenDirectoryEnumerationFails() async throws {
        let outputDirectory = try makeCleanupSeamDirectory()
        // 還原必須以 defer 註冊：中途拋錯時未還原的 0o333 目錄會擋下遞迴刪除
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: outputDirectory.path
            )
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let past = Date(timeIntervalSince1970: 1_000_000)
        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            let final = try self.makeFinalOutput(
                outputDirectory, "video.mp4", mtime: past.addingTimeInterval(60)
            )
            // 0o333 使 contentsOfDirectory 失敗，但 fileExists、mtime 讀取與 unlink 仍可行。
            // 不可用 0o111——那會讓 unlink 也失敗，測試就無法區辨「放棄了」與「想刪但刪不掉」。
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o333], ofItemAtPath: outputDirectory.path
            )
            return final.path
        }

        XCTAssertEqual(result.outcome, .abandoned(.directoryEnumerationFailed))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: outputDirectory.path
        )
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent("video.f401.mp4.part").path
        ))
    }

    func testCleanupContinuesAfterUnlinkFailure() async throws {
        let outputDirectory = try makeCleanupSeamDirectory()
        let locked = outputDirectory.appendingPathComponent("video.f401.mp4.part")
        defer {
            _ = try? Process.run(
                URL(fileURLWithPath: "/usr/bin/chflags"), arguments: ["nouchg", locked.path]
            ).waitUntilExit()
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let past = Date(timeIntervalSince1970: 1_000_000)
        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            // 刻意以非字典序建立三個候選檔。實作把列舉結果收成 Set 後才迭代，而 Swift 的
            // Set 迭代順序由 per-process 隨機 hash seed 決定；兩個元素只有 2 種排列，
            // 約半數執行會恰好命中排序後的順序而漏掉迴歸，三個元素把漏檢率降到 1/6。
            try self.makeCandidate(outputDirectory, "video.f251.webm.part", mtime: past)
            try self.makeCandidate(outputDirectory, "video.f603.mp4.part", mtime: past)
            try self.makeCandidate(outputDirectory, "video.f140.m4a.part", mtime: past)
            let final = try self.makeFinalOutput(
                outputDirectory, "video.mp4", mtime: past.addingTimeInterval(60)
            )
            // immutable flag 使 unlink 以 EPERM 失敗。不可改用 chmod：macOS 的 unlink
            // 取決於父目錄寫入權限，唯讀檔案仍會被成功刪除。
            let chflags = try Process.run(
                URL(fileURLWithPath: "/usr/bin/chflags"), arguments: ["uchg", locked.path]
            )
            chflags.waitUntilExit()
            return final.path
        }

        XCTAssertEqual(
            result.outcome,
            .completed(
                deleted: ["video.f140.m4a.part", "video.f251.webm.part", "video.f603.mp4.part"],
                failed: ["video.f401.mp4.part"]
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: locked.path))
        for deleted in ["video.f251.webm.part", "video.f603.mp4.part", "video.f140.m4a.part"] {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: outputDirectory.appendingPathComponent(deleted).path
            ))
        }
    }

    func testCleanupContinuesAfterAttributeReadFailure() async throws {
        let outputDirectory = try makeCleanupSeamDirectory()
        let denied = outputDirectory.appendingPathComponent("video.f401.mp4.part")
        defer {
            _ = try? Process.run(
                URL(fileURLWithPath: "/bin/chmod"), arguments: ["-N", denied.path]
            ).waitUntilExit()
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let past = Date(timeIntervalSince1970: 1_000_000)
        let result = try await runCleanupFlow(outputDirectory: outputDirectory.path) { _ in
            try self.makeCandidate(outputDirectory, "video.f401.mp4.part", mtime: past)
            try self.makeCandidate(outputDirectory, "video.f251.webm.part", mtime: past)
            let final = try self.makeFinalOutput(
                outputDirectory, "video.mp4", mtime: past.addingTimeInterval(60)
            )
            // ACL deny readattr 使該候選檔仍出現在列舉結果中，但屬性讀取整批失敗
            let acl = try Process.run(
                URL(fileURLWithPath: "/bin/chmod"),
                arguments: ["+a", "\(NSUserName()) deny readattr", denied.path]
            )
            acl.waitUntilExit()
            return final.path
        }

        XCTAssertEqual(
            result.outcome,
            .completed(deleted: ["video.f251.webm.part"], failed: ["video.f401.mp4.part"])
        )
        // 不能用 fileExists 斷言：deny readattr 同樣會讓它失敗。改以目錄列舉觀察該檔仍在。
        let remaining = try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path)
        XCTAssertTrue(remaining.contains("video.f401.mp4.part"))
        XCTAssertFalse(remaining.contains("video.f251.webm.part"))
    }

    func testExistingSeamTestsProduceNoFilesystemSideEffects() async throws {
        // 既有 seam 測試一律傳入不存在的輸出目錄，清理必須對它們完全無副作用。
        // 使用帶 UUID 的路徑而非字面 /Downloads，避免依賴「該機器上此目錄不存在」的環境前提。
        let absent = "/Downloads-\(UUID().uuidString)"
        let result = try await runCleanupFlow(outputDirectory: absent) { _ in
            "\(absent)/video.mp4"
        }

        XCTAssertEqual(result.path, "\(absent)/video.mp4")
        XCTAssertEqual(result.outcome, .abandoned(.snapshotUnavailable))
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(absent)/video.mp4"))
    }

    func testUnlinkRefusesDirectoryAndDoesNotFollowSymlink() throws {
        let directory = try makeCleanupSeamDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 刪除原語測試：不經過候選條件序列。目錄的 isRegularFile 為 false，走完整清理流程
        // 一定會在型別檢查就被濾掉，unlink 根本不會被呼叫。
        let candidateDirectory = directory.appendingPathComponent("video.f401.mp4.part")
        try FileManager.default.createDirectory(at: candidateDirectory, withIntermediateDirectories: true)
        let inner = candidateDirectory.appendingPathComponent("user-data.txt")
        try "precious".write(to: inner, atomically: true, encoding: .utf8)

        XCTAssertEqual(unlink(candidateDirectory.path), -1)
        XCTAssertEqual(errno, EPERM)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidateDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inner.path))

        // 空目錄是區分 unlink 與 rmdir／remove(3) 的關鍵反例：後兩者同樣不遞迴，卻會刪掉空目錄
        let emptyDirectory = directory.appendingPathComponent("video.f405.mp4.part")
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        XCTAssertEqual(unlink(emptyDirectory.path), -1)
        XCTAssertEqual(errno, EPERM)
        XCTAssertTrue(FileManager.default.fileExists(atPath: emptyDirectory.path))

        let target = directory.appendingPathComponent("real-target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let targetInner = target.appendingPathComponent("kept.txt")
        try "kept".write(to: targetInner, atomically: true, encoding: .utf8)
        let link = directory.appendingPathComponent("video.f402.mp4.part")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)

        XCTAssertEqual(unlink(link.path), 0)
        XCTAssertNil(try? FileManager.default.attributesOfItem(atPath: link.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetInner.path))
    }

    // MARK: - 孤兒中間檔清理（cleanup-orphaned-part-files）

    /// cleanup fixture 的項目宣告。`stamp` 為 `touch -t` 格式的時間戳。
    private enum CleanupItem {
        case file(String, stamp: String)
        case directory(String, inner: String, stamp: String)
        case symlink(String, target: String, stamp: String)
        case final(String, stamp: String)

        var specLine: String {
            switch self {
            case let .file(name, stamp):
                return "file|\(name)|\(stamp)|"
            case let .directory(name, inner, stamp):
                return "dir|\(name)|\(stamp)|\(inner)"
            case let .symlink(name, target, stamp):
                return "symlink|\(name)|\(stamp)|\(target)"
            case let .final(name, stamp):
                return "final|\(name)|\(stamp)|"
            }
        }
    }

    /// 早於最終輸出檔的時間戳，供候選項目使用。
    private static let cleanupEarlyStamp = "202001010000"
    /// 最終輸出檔的時間戳，明確晚於 `cleanupEarlyStamp`。
    private static let cleanupFinalStamp = "202001020000"

    private func writeCleanupSpec(_ fixture: YTDLPFixture, _ items: [CleanupItem]) throws {
        let contents = items.map(\.specLine).joined(separator: "\n") + "\n"
        try contents.write(to: fixture.cleanupSpec, atomically: true, encoding: .utf8)
    }

    /// 以 fixture 的「多 attempt 成功」case 跑完整的 production download 流程。
    private func runCleanupDownload(
        _ fixture: YTDLPFixture,
        marker: String = "CLEANUP_MULTI"
    ) async throws -> String {
        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        return try await service.download(
            taskId: UUID(),
            url: "https://youtube.com/watch?v=cleanup",
            commandTemplate: "\(marker) $youtubeUrl",
            outputDirectory: fixture.directory.path,
            onProgress: { _ in }
        )
    }

    private func fixtureFileExists(_ fixture: YTDLPFixture, _ name: String) -> Bool {
        FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent(name).path)
    }

    /// symbolic link 自身是否存在。`fileExists` 會 follow link，dangling link 會回傳 false。
    private func fixtureSymlinkExists(_ fixture: YTDLPFixture, _ name: String) -> Bool {
        let path = fixture.directory.appendingPathComponent(name).path
        return (try? FileManager.default.attributesOfItem(atPath: path)) != nil
    }

    private func didProduceOutputFile(marker: String) async throws -> Bool {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try writeCleanupSpec(fixture, [.final("video.mp4", stamp: Self.cleanupFinalStamp)])

        let service = YTDLPService(ytdlpPathProvider: { fixture.executable.path })
        let taskId = UUID()
        _ = try await service.download(
            taskId: taskId,
            url: "https://youtube.com/watch?v=ownership",
            commandTemplate: "\(marker) $youtubeUrl",
            outputDirectory: fixture.directory.path,
            onProgress: { _ in }
        )
        return await service.didProduceOutputFile(taskId: taskId)
    }

    func testDidProduceOutputFileIsTrueWhenYTDLPReportsRealDownload() async throws {
        let produced = try await didProduceOutputFile(marker: "CLEANUP_MULTI REPORT_REAL_DOWNLOAD")
        XCTAssertTrue(produced)
    }

    func testDidProduceOutputFileIsFalseWhenYTDLPReusesExistingFile() async throws {
        // 同名檔已存在時 yt-dlp 回報 REAL_DOWNLOAD:False，該檔不一定屬於此任務
        let produced = try await didProduceOutputFile(marker: "CLEANUP_MULTI")
        XCTAssertFalse(produced)
    }

    func testCleanupRemovesPartFileLeftByEarlierAttempt() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        // 主幹取自 spec scenario 的 ##### Example:，也是本 change 的動機案例
        let stem = "火箭降落的全过程，拍到了！"
        try writeCleanupSpec(fixture, [
            .file("\(stem).f401.mp4.part", stamp: Self.cleanupEarlyStamp),
            .final("\(stem).mp4", stamp: Self.cleanupFinalStamp)
        ])

        let outputPath = try await runCleanupDownload(fixture)

        XCTAssertEqual(
            URL(fileURLWithPath: outputPath).resolvingSymlinksInPath().path,
            fixture.directory.appendingPathComponent("\(stem).mp4").resolvingSymlinksInPath().path
        )
        XCTAssertFalse(fixtureFileExists(fixture, "\(stem).f401.mp4.part"))
        XCTAssertTrue(fixtureFileExists(fixture, "\(stem).mp4"))
    }

    func testCleanupRemovesYtdlAndFragmentCompanions() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .file("video.f401.mp4.part", stamp: Self.cleanupEarlyStamp),
            .file("video.f401.mp4.ytdl", stamp: Self.cleanupEarlyStamp),
            .file("video.f251.webm.part-Frag12", stamp: Self.cleanupEarlyStamp),
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertFalse(fixtureFileExists(fixture, "video.f401.mp4.part"))
        XCTAssertFalse(fixtureFileExists(fixture, "video.f401.mp4.ytdl"))
        XCTAssertFalse(fixtureFileExists(fixture, "video.f251.webm.part-Frag12"))
    }

    func testCleanupKeepsFinalOutputAndSubtitleFile() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .file("video.zh-TW.srt", stamp: Self.cleanupEarlyStamp),
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertTrue(fixtureFileExists(fixture, "video.mp4"))
        XCTAssertTrue(fixtureFileExists(fixture, "video.zh-TW.srt"))
    }

    func testCleanupKeepsPartFileOfDifferentStem() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .file("other.f401.mp4.part", stamp: Self.cleanupEarlyStamp),
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertTrue(fixtureFileExists(fixture, "other.f401.mp4.part"))
    }

    func testCleanupKeepsPartFileWhoseStemIsDottedPrefixExtension() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .file("Lecture 1.5.f401.mp4.part", stamp: Self.cleanupEarlyStamp),
            .final("Lecture 1.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertTrue(fixtureFileExists(fixture, "Lecture 1.5.f401.mp4.part"))
        XCTAssertTrue(fixtureFileExists(fixture, "Lecture 1.mp4"))
    }

    func testCleanupKeepsPartFilePresentBeforeDownloadStarted() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        // 下載開始前就存在，因此會落入目錄快照。mtime 必須明確設早於最終輸出檔——
        // 否則寫入當下的真實時間會晚於 fixture 的 2020 年最終檔，該檔會被 mtime 條件攔下，
        // 快照條件就永遠不會是唯一的攔截點，測試也就驗不到它。
        let preexisting = fixture.directory.appendingPathComponent("video.mp4.part")
        try "stale".write(to: preexisting, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000_000)],
            ofItemAtPath: preexisting.path
        )

        try writeCleanupSpec(fixture, [
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertTrue(fixtureFileExists(fixture, "video.mp4.part"))
    }

    func testCleanupKeepsCandidateWhoseMtimeIsNotEarlierThanFinalOutput() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            // 候選檔 mtime 晚於最終輸出檔
            .file("video.f401.mp4.part", stamp: "202001030000"),
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        XCTAssertTrue(fixtureFileExists(fixture, "video.f401.mp4.part"))
    }

    func testCleanupKeepsEverythingWhenDownloadFails() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .file("video.f401.mp4.part", stamp: Self.cleanupEarlyStamp)
        ])

        do {
            _ = try await runCleanupDownload(fixture, marker: "CLEANUP_FAIL")
            XCTFail("預期下載失敗")
        } catch let error as YTDLPError {
            guard case .executionFailed = error else {
                return XCTFail("預期 executionFailed，實際為 \(error)")
            }
        }

        XCTAssertTrue(fixtureFileExists(fixture, "video.f401.mp4.part"))
        // 單次 attempt 即結束，未套用 2/5/10 秒 backoff
        let invocations = try String(contentsOf: fixture.log, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(invocations.filter { $0.contains("CLEANUP_FAIL") }.count, 1)
    }

    func testCleanupKeepsDirectoryAndSymlinkMatchingCandidateShape() async throws {
        let fixture = try makeYTDLPFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try writeCleanupSpec(fixture, [
            .directory("video.f401.mp4.part", inner: "user-data.txt", stamp: Self.cleanupEarlyStamp),
            .symlink("video.f402.mp4.part", target: "video.mp4", stamp: Self.cleanupEarlyStamp),
            .final("video.mp4", stamp: Self.cleanupFinalStamp)
        ])

        _ = try await runCleanupDownload(fixture)

        // 目錄兩項斷言的實際保護來源是 unlink 對目錄的 EPERM（見 testUnlinkRefusesDirectory…），
        // 型別檢查的鑑別力由下方的 symlink 斷言承擔——symlink 若未被型別檢查排除就會被 unlink 刪掉。
        XCTAssertTrue(fixtureFileExists(fixture, "video.f401.mp4.part"))
        XCTAssertTrue(fixtureFileExists(fixture, "video.f401.mp4.part/user-data.txt"))
        XCTAssertTrue(fixtureSymlinkExists(fixture, "video.f402.mp4.part"))
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
        /// 清理測試用的項目清單。每行格式為 `kind|relativePath|touchStamp|extra`，以 `|` 分隔
        /// 是因為候選檔名含有空格（例如 `Lecture 1.5.f401.mp4.part`）。
        /// kind 為 `file`／`dir`／`symlink`／`final`；`dir` 的 extra 是內層檔名，`symlink` 的 extra 是 target。
        let cleanupSpec: URL

        /// 目前為止發生的 invocation 次數。
        var invocationCount: Int {
            let counter = directory.appendingPathComponent("invocation-count")
            guard let text = try? String(contentsOf: counter, encoding: .utf8) else { return 0 }
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        /// 第 `index` 次（1-based）invocation 的完整引數；該次呼叫未發生時回傳 nil。
        func arguments(at index: Int) -> [String]? {
            let file = directory.appendingPathComponent("invocation-\(index).args")
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            // 每個引數各佔一行並帶結尾換行，split 後的最後一個空片段須捨去
            var lines = text.components(separatedBy: "\n")
            if lines.last == "" { lines.removeLast() }
            return lines
        }
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
        let cleanupSpec = directory.appendingPathComponent("cleanup-spec.txt")
        let script = """
        #!/bin/sh
        log=\(shellQuote(log.path))
        pid=\(shellQuote(pid.path))
        cleanupspec=\(shellQuote(cleanupSpec.path))
        allargs="$*"
        dir=\(shellQuote(directory.path))
        echo "$*" >> "$log"
        echo "$$" > "$pid"

        # 逐次獨立記錄 argv：`echo "$*"` 無法區分 token 邊界，帶空白或逗號的引數需要逐行記錄
        counter="$dir/invocation-count"
        n=$(cat "$counter" 2>/dev/null || echo 0)
        n=$((n + 1))
        printf '%s\\n' "$n" > "$counter"
        argsfile="$dir/invocation-$n.args"
        : > "$argsfile"
        for arg in "$@"; do
          printf '%s\\n' "$arg" >> "$argsfile"
        done

        # 依 cleanup-spec.txt 在目前工作目錄（即 outputDirectory）建立項目。
        # 這些項目必須在 invocation 期間建立，若由測試在呼叫 download 之前建立，
        # 會落入清理的目錄快照而被提前排除，測試就走不到後續條件。
        build_cleanup_items() {
          want=$1
          [ -f "$cleanupspec" ] || return 0
          while IFS='|' read -r kind rel stamp extra; do
            [ -z "$kind" ] && continue
            [ "$kind" = "$want" ] || continue
            case "$kind" in
              file)
                : > "$rel"
                touch -t "$stamp" "$rel"
                ;;
              dir)
                mkdir -p "$rel"
                : > "$rel/$extra"
                # 內層檔案的建立會更新目錄 mtime，因此 touch 必須排在其後
                touch -t "$stamp" "$rel"
                ;;
              symlink)
                ln -s "$extra" "$rel"
                # -h 才是設定連結自身的 mtime；不帶 -h 會 follow 到 target
                touch -h -t "$stamp" "$rel"
                ;;
            esac
          done < "$cleanupspec"
        }

        emit_final() {
          [ -f "$cleanupspec" ] || return 0
          while IFS='|' read -r kind rel stamp extra; do
            [ "$kind" = "final" ] || continue
            : > "$rel"
            touch -t "$stamp" "$rel"
            printf 'FINAL_PATH:%s\\n' "$PWD/$rel"
            case "$allargs" in
              *REPORT_REAL_DOWNLOAD*) printf 'REAL_DOWNLOAD:True\\n' ;;
              *) printf 'REAL_DOWNLOAD:False\\n' ;;
            esac
            return 0
          done < "$cleanupspec"
        }

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
          *CLEANUP_MULTI*)
            if [ "$(grep -c 'CLEANUP_MULTI' "$log" 2>/dev/null || true)" -eq 1 ]; then
              build_cleanup_items file
              build_cleanup_items dir
              build_cleanup_items symlink
              printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2
              exit 1
            fi
            emit_final
            ;;
          *CLEANUP_FAIL*)
            build_cleanup_items file
            printf '[download] Giving up after 10 retries\\n' >&2
            printf 'ERROR: unable to download video data: HTTP Error 403: Forbidden\\n' >&2
            exit 1
            ;;
          *FORMAT_UNAVAILABLE*)
            printf 'ERROR: [youtube] video: Requested format is not available. Use --list-formats for a list of available formats\\n' >&2
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
            writerPID: writerPID,
            cleanupSpec: cleanupSpec
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
