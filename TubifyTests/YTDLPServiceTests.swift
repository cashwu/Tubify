import XCTest
@testable import Tubify

/// YTDLPService 測試
final class YTDLPServiceTests: XCTestCase {

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

    // MARK: - DownloadResultHolder 測試

    func testDownloadResultHolderSetOutputPath() {
        let holder = DownloadResultHolder()
        XCTAssertNil(holder.outputPath)

        holder.setOutputPath("/path/to/video.mp4")
        XCTAssertEqual(holder.outputPath, "/path/to/video.mp4")
    }

    func testDownloadResultHolderSetError() {
        let holder = DownloadResultHolder()
        XCTAssertNil(holder.lastError)

        holder.setError("ERROR: Video unavailable")
        XCTAssertEqual(holder.lastError, "ERROR: Video unavailable")
    }

    func testDownloadResultHolderThreadSafety() {
        let holder = DownloadResultHolder()
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                holder.setOutputPath("/path/\(i)")
                _ = holder.outputPath
                holder.setError("Error \(i)")
                _ = holder.lastError
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
}
