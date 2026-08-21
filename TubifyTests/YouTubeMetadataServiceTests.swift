import XCTest
@testable import Tubify

/// YouTubeMetadataService 測試
final class YouTubeMetadataServiceTests: XCTestCase {

    // MARK: - 播放清單檢測測試

    func testIsPlaylistWithListParameter() {
        XCTAssertTrue(YouTubeMetadataService.isPlaylistSync(url: "https://www.youtube.com/watch?v=abc&list=PLxyz123"))
    }

    func testIsPlaylistWithPlaylistPath() {
        XCTAssertTrue(YouTubeMetadataService.isPlaylistSync(url: "https://www.youtube.com/playlist?list=PLxyz123"))
    }

    func testIsNotPlaylistForSingleVideo() {
        XCTAssertFalse(YouTubeMetadataService.isPlaylistSync(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testIsNotPlaylistForShortURL() {
        XCTAssertFalse(YouTubeMetadataService.isPlaylistSync(url: "https://youtu.be/dQw4w9WgXcQ"))
    }

    func testIsNotPlaylistForShorts() {
        XCTAssertFalse(YouTubeMetadataService.isPlaylistSync(url: "https://www.youtube.com/shorts/abc123"))
    }

    // MARK: - Video ID 提取測試

    func testExtractVideoIdFromStandardURL() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(videoId, "dQw4w9WgXcQ")
    }

    func testExtractVideoIdFromShortURL() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(videoId, "dQw4w9WgXcQ")
    }

    func testExtractVideoIdFromURLWithTimestamp() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120")
        XCTAssertEqual(videoId, "dQw4w9WgXcQ")
    }

    func testExtractVideoIdFromURLWithPlaylist() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxyz")
        XCTAssertEqual(videoId, "dQw4w9WgXcQ")
    }

    func testExtractVideoIdFromEmbedURL() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/embed/dQw4w9WgXcQ")
        XCTAssertEqual(videoId, "dQw4w9WgXcQ")
    }

    func testExtractVideoIdWithHyphen() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/watch?v=abc-123_xyz")
        XCTAssertEqual(videoId, "abc-123_xyz")
    }

    func testExtractVideoIdReturnsNilForInvalidURL() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.google.com")
        XCTAssertNil(videoId)
    }

    func testExtractVideoIdReturnsNilForPlaylistOnly() {
        let videoId = YouTubeMetadataService.extractVideoIdSync(from: "https://www.youtube.com/playlist?list=PLxyz123")
        XCTAssertNil(videoId)
    }

    // MARK: - Cookies 參數提取測試

    func testExtractCookiesFromBrowserArgument() async {
        let service = YouTubeMetadataService.shared
        let args = await service.extractCookiesArguments(from: "yt-dlp --cookies-from-browser safari \"$youtubeUrl\"")
        XCTAssertTrue(args.contains("--cookies-from-browser"))
        XCTAssertTrue(args.contains("safari"))
    }

    func testExtractCookiesFromBrowserWithEquals() async {
        let service = YouTubeMetadataService.shared
        let args = await service.extractCookiesArguments(from: "yt-dlp --cookies-from-browser=chrome \"$youtubeUrl\"")
        XCTAssertTrue(args.contains("--cookies-from-browser=chrome"))
    }

    func testExtractCookiesFileArgument() async {
        let service = YouTubeMetadataService.shared
        let args = await service.extractCookiesArguments(from: "yt-dlp --cookies /path/to/cookies.txt \"$youtubeUrl\"")
        XCTAssertTrue(args.contains("--cookies"))
        XCTAssertTrue(args.contains("/path/to/cookies.txt"))
    }

    func testExtractCookiesFileWithEquals() async {
        let service = YouTubeMetadataService.shared
        let args = await service.extractCookiesArguments(from: "yt-dlp --cookies=/path/to/cookies.txt \"$youtubeUrl\"")
        XCTAssertTrue(args.contains("--cookies=/path/to/cookies.txt"))
    }

    func testNoCookiesArgumentsWhenNotPresent() async {
        let service = YouTubeMetadataService.shared
        let args = await service.extractCookiesArguments(from: "yt-dlp -S ext:mp4 \"$youtubeUrl\"")
        XCTAssertTrue(args.isEmpty)
    }

    // MARK: - VideoInfo 解碼測試

    func testVideoInfoDecoding() throws {
        let json = """
        {
            "id": "dQw4w9WgXcQ",
            "title": "Rick Astley - Never Gonna Give You Up",
            "thumbnail": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
            "duration": 213,
            "uploader": "Rick Astley",
            "webpage_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let videoInfo = try decoder.decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.id, "dQw4w9WgXcQ")
        XCTAssertEqual(videoInfo.title, "Rick Astley - Never Gonna Give You Up")
        XCTAssertEqual(videoInfo.thumbnail, "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
        XCTAssertEqual(videoInfo.duration, 213)
        XCTAssertEqual(videoInfo.uploader, "Rick Astley")
        XCTAssertEqual(videoInfo.url, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testVideoInfoDecodingWithMissingOptionalFields() throws {
        let json = """
        {
            "id": "abc123",
            "title": "Test Video",
            "webpage_url": "https://www.youtube.com/watch?v=abc123"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let videoInfo = try decoder.decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.id, "abc123")
        XCTAssertEqual(videoInfo.title, "Test Video")
        XCTAssertNil(videoInfo.thumbnail)
        XCTAssertNil(videoInfo.duration)
        XCTAssertNil(videoInfo.uploader)
        XCTAssertNil(videoInfo.liveStatus)
        XCTAssertNil(videoInfo.releaseTimestamp)
    }

    func testVideoInfoDecodingWithLiveStatus() throws {
        let json = """
        {
            "id": "eMAm_gY0eaw",
            "title": "首播串流測試影片",
            "thumbnail": "https://i.ytimg.com/vi/eMAm_gY0eaw/maxresdefault.jpg",
            "duration": 1456,
            "uploader": "Test Channel",
            "webpage_url": "https://www.youtube.com/watch?v=eMAm_gY0eaw",
            "live_status": "is_live",
            "release_timestamp": 1767789011
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let videoInfo = try decoder.decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.id, "eMAm_gY0eaw")
        XCTAssertEqual(videoInfo.title, "首播串流測試影片")
        XCTAssertEqual(videoInfo.duration, 1456)
        XCTAssertEqual(videoInfo.liveStatus, "is_live")
        XCTAssertEqual(videoInfo.releaseTimestamp, 1767789011)
    }

    func testVideoInfoDecodingWithWasLiveStatus() throws {
        let json = """
        {
            "id": "abc123",
            "title": "已結束的直播",
            "webpage_url": "https://www.youtube.com/watch?v=abc123",
            "live_status": "was_live"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let videoInfo = try decoder.decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.liveStatus, "was_live")
        XCTAssertNil(videoInfo.releaseTimestamp)
    }

    func testVideoInfoDecodingWithNotLiveStatus() throws {
        let json = """
        {
            "id": "abc123",
            "title": "普通影片",
            "webpage_url": "https://www.youtube.com/watch?v=abc123",
            "live_status": "not_live"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let videoInfo = try decoder.decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.liveStatus, "not_live")
    }

    func testVideoInfoDecodesRawFormats() throws {
        let json = """
        {
            "id": "TR_NgGeXWGc",
            "title": "Post Live Replay",
            "webpage_url": "https://www.youtube.com/watch?v=TR_NgGeXWGc",
            "live_status": "post_live",
            "formats": [
                {"format_id": "137", "vcodec": "avc1.640028", "acodec": "none", "protocol": "https", "ext": "mp4"},
                {"format_id": "140", "vcodec": "none", "acodec": "mp4a.40.2", "protocol": "https", "ext": "m4a"}
            ]
        }
        """.data(using: .utf8)!

        let videoInfo = try JSONDecoder().decode(VideoInfo.self, from: json)

        XCTAssertEqual(videoInfo.formats?.map(\.formatID), ["137", "140"])
        XCTAssertTrue(videoInfo.hasUsableMediaFormats)
    }

    func testUsableMediaFormatsPredicateExcludesIncompleteEntries() {
        let excludedCases: [[YTDLPFormat]] = [
            [YTDLPFormat(formatID: "137", vcodec: "avc1.640028", acodec: "none", protocolName: "https", ext: "mp4")],
            [YTDLPFormat(formatID: "140", vcodec: "none", acodec: "mp4a.40.2", protocolName: "https", ext: "m4a")],
            [YTDLPFormat(formatID: "sb0", vcodec: "none", acodec: "none", protocolName: "mhtml", ext: "mhtml")],
            [YTDLPFormat(formatID: "thumb", vcodec: "none", acodec: "none", protocolName: "https", ext: "jpg")],
            [YTDLPFormat(formatID: "meta", vcodec: nil, acodec: nil, protocolName: nil, ext: nil)],
            [YTDLPFormat(formatID: "manifest", vcodec: "none", acodec: "none", protocolName: "m3u8_native", ext: "mp4")],
            [YTDLPFormat(formatID: "bad-video", vcodec: "avc1.640028", acodec: nil, protocolName: "https", ext: "mp4")],
            [YTDLPFormat(formatID: "bad-audio", vcodec: nil, acodec: "mp4a.40.2", protocolName: "https", ext: "m4a")],
            [YTDLPFormat(formatID: "empty", vcodec: "none", acodec: "none", protocolName: "https", ext: "mp4")]
        ]

        for formats in excludedCases {
            XCTAssertFalse(YTDLPFormat.hasUsableMediaFormats(formats), "Excluded formats should not be treated as downloadable: \(formats)")
        }
    }

    // MARK: - PlaylistInfo 解碼測試

    func testPlaylistInfoDecoding() throws {
        let json = """
        {
            "id": "PLxyz123",
            "title": "My Playlist",
            "entries": [
                {"id": "video1", "title": "First Video", "url": "https://www.youtube.com/watch?v=video1"},
                {"id": "video2", "title": "Second Video", "url": null}
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let playlistInfo = try decoder.decode(PlaylistInfo.self, from: json)

        XCTAssertEqual(playlistInfo.id, "PLxyz123")
        XCTAssertEqual(playlistInfo.title, "My Playlist")
        XCTAssertEqual(playlistInfo.entries?.count, 2)
        XCTAssertEqual(playlistInfo.entries?[0].id, "video1")
        XCTAssertEqual(playlistInfo.entries?[0].title, "First Video")
        XCTAssertEqual(playlistInfo.entries?[1].url, nil)
    }

    func testPlaylistInfoDecodingWithNoEntries() throws {
        let json = """
        {
            "id": "PLxyz123",
            "title": "Empty Playlist",
            "entries": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let playlistInfo = try decoder.decode(PlaylistInfo.self, from: json)

        XCTAssertEqual(playlistInfo.id, "PLxyz123")
        XCTAssertNil(playlistInfo.entries)
    }

    // MARK: - yt-dlp 路徑注入接縫測試

    /// provider 指向 fixture 執行檔時，`fetchMediaOptions` 必須實際呼叫該 fixture。
    /// 以 fixture 留下的 invocation 記錄為據，而非比對實例身分。
    func testFetchMediaOptionsUsesInjectedYTDLPPath() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.fetchMediaOptions(url: "https://www.youtube.com/watch?v=abc123", cookiesArguments: [])

        XCTAssertEqual(fixture.invocationCount, 1)
        let arguments = try XCTUnwrap(fixture.arguments(at: 1))
        XCTAssertTrue(arguments.contains("https://www.youtube.com/watch?v=abc123"))
    }

    /// provider 指向不存在的路徑時，`fetchMediaOptions` 必須拋出 `MetadataError`。
    /// cookies 參數刻意傳非空值：`process.run()` 失敗屬與 exit code 無關的失敗出口，
    /// 即使有 cookies 可用也不得進入重試判定，否則無法與「因為沒有 cookies 所以不重試」區分。
    func testFetchMediaOptionsThrowsWhenInjectedPathIsMissing() async throws {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tubify-missing-ytdlp-\(UUID().uuidString)").path
        let service = YouTubeMetadataService(ytdlpPathProvider: { missingPath })

        do {
            _ = try await service.fetchMediaOptions(
                url: Self.mediaOptionsURL,
                cookiesArguments: Self.cookiesArguments
            )
            XCTFail("指向不存在的 yt-dlp 路徑時應拋出 MetadataError")
        } catch is MetadataError {
            // 預期路徑
        }
    }

    // MARK: - 媒體選項兩階段 cookies 策略測試

    private static let mediaOptionsURL = "https://www.youtube.com/watch?v=abc123"
    private static let cookiesArguments = ["--cookies-from-browser", "safari"]
    private static let baseArguments = ["-J", "--skip-download", "--no-playlist"]

    /// 有可用 cookies 時，第一次 invocation 的引數仍不得含 cookies 參數。
    func testFirstMediaOptionsInvocationOmitsCookies() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.setCall(1, exitCode: 0)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        _ = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertEqual(fixture.arguments(at: 1), Self.baseArguments + [Self.mediaOptionsURL])
    }

    /// 第一次成功即回傳其解析結果，且不做第二次 invocation。
    func testSuccessfulFirstMediaOptionsInvocationIsNotRetried() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let json = """
        {
            "subtitles": {"zh": [{"ext": "vtt"}]},
            "formats": [
                {"format_id": "137", "vcodec": "avc1.640028", "acodec": "none", "protocol": "https", "ext": "mp4"}
            ]
        }
        """
        try fixture.setCall(1, exitCode: 0, stdout: json)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        let options = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertEqual(options.subtitles.map(\.languageCode), ["zh"])
        XCTAssertEqual(options.formats.map(\.formatID), ["137"])
        XCTAssertEqual(fixture.invocationCount, 1)
    }

    /// 解析結果為空同樣不觸發重試：空結果與「這支影片本來就沒有字幕」在 JSON 上無法區分。
    func testEmptyButSuccessfulMediaOptionsResultIsNotRetried() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.setCall(1, exitCode: 0, stdout: #"{"subtitles": {}, "formats": []}"#)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        let options = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertTrue(options.subtitles.isEmpty)
        XCTAssertTrue(options.formats.isEmpty)
        XCTAssertEqual(fixture.invocationCount, 1)
    }

    /// 需登入訊號且有 cookies 時重試一次，第二次引數為第一次加上 cookies，並以第二次結果為準。
    func testLoginRequiredFailureRetriesWithCookies() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.setCall(
            1,
            exitCode: 1,
            stdout: "",
            stderr: "ERROR: [youtube] abc123: Private video. Sign in if you've been granted access to this video"
        )
        try fixture.setCall(2, exitCode: 0, stdout: #"{"subtitles": {"zh": [{"ext": "vtt"}]}}"#)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        let options = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertEqual(fixture.invocationCount, 2)
        XCTAssertEqual(
            fixture.arguments(at: 2),
            Self.baseArguments + Self.cookiesArguments + [Self.mediaOptionsURL]
        )
        XCTAssertEqual(options.subtitles.map(\.languageCode), ["zh"])
    }

    /// 兩次皆失敗時以第二次的訊息回報，且不做第三次 invocation。
    func testBothMediaOptionsInvocationsFailingReportsSecondMessage() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let firstMessage = "ERROR: [youtube] abc123: Private video. Sign in if you've been granted access to this video"
        let secondMessage = "ERROR: [youtube] abc123: Sign in to confirm you're not a bot. Retry with cookies failed."
        try fixture.setCall(1, exitCode: 1, stdout: "", stderr: firstMessage)
        try fixture.setCall(2, exitCode: 1, stdout: "", stderr: secondMessage)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.fetchMediaOptions(
                url: Self.mediaOptionsURL,
                cookiesArguments: Self.cookiesArguments
            )
            XCTFail("兩次 invocation 皆失敗時應拋出 MetadataError.fetchFailed")
        } catch MetadataError.fetchFailed(let message) {
            XCTAssertEqual(message, secondMessage)
        }

        XCTAssertEqual(fixture.invocationCount, 2)
    }

    /// 非需登入訊號不重試，並以第一次的訊息回報。video-data 403 屬於下載路徑專有訊號，
    /// 媒體選項查詢帶 --skip-download，不得因它重試。
    func testNonLoginFailureIsNotRetried() async throws {
        let nonLoginMessages = [
            "ERROR: unable to download video data: HTTP Error 403: Forbidden",
            "ERROR: [youtube] abc123: Video unavailable",
            "ERROR: Unable to download webpage: The read operation timed out"
        ]

        for message in nonLoginMessages {
            let fixture = try makeMetadataFixture()
            defer { try? FileManager.default.removeItem(at: fixture.directory) }
            try fixture.setCall(1, exitCode: 1, stdout: "", stderr: message)

            let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
            do {
                _ = try await service.fetchMediaOptions(
                    url: Self.mediaOptionsURL,
                    cookiesArguments: Self.cookiesArguments
                )
                XCTFail("非需登入訊號應直接拋出：\(message)")
            } catch MetadataError.fetchFailed(let thrown) {
                XCTAssertEqual(thrown, message, "應以第一次的 stderr 回報：\(message)")
            }

            XCTAssertEqual(fixture.invocationCount, 1, "非需登入訊號不得重試：\(message)")
        }
    }

    /// 沒有可用 cookies 時，即使訊息屬於需登入訊號也不重試。
    func testLoginRequiredFailureIsNotRetriedWithoutCookies() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let message = "ERROR: [youtube] abc123: Join this channel to get access to members-only content like this video"
        try fixture.setCall(1, exitCode: 1, stdout: "", stderr: message)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.fetchMediaOptions(url: Self.mediaOptionsURL, cookiesArguments: [])
            XCTFail("沒有可用 cookies 時應直接拋出")
        } catch MetadataError.fetchFailed(let thrown) {
            XCTAssertEqual(thrown, message)
        }

        XCTAssertEqual(fixture.invocationCount, 1)
    }

    /// 非 0 exit code 但 stderr 為空時不重試，且訊息為空字串——空 Data 會解碼成空字串，
    /// 既有的 `未知錯誤` fallback 只在解碼失敗時套用，本變更不改此行為。
    func testEmptyStderrFailureIsNotRetriedAndReportsEmptyMessage() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.setCall(1, exitCode: 1, stdout: "", stderr: "")

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.fetchMediaOptions(
                url: Self.mediaOptionsURL,
                cookiesArguments: Self.cookiesArguments
            )
            XCTFail("非 0 exit code 應拋出 MetadataError.fetchFailed")
        } catch MetadataError.fetchFailed(let thrown) {
            XCTAssertEqual(thrown, "")
        }

        XCTAssertEqual(fixture.invocationCount, 1)
    }

    // MARK: - post_live／is_upcoming 解析迴歸測試

    /// 改寫後的 `fetchMediaOptions` 仍須正確回傳 `post_live` 影片的 liveStatus 與 formats，
    /// 且 `hasUsableMediaFormats` 對同一組 formats 的判定與既有測試一致。
    func testPostLiveMediaOptionsStillParseLiveStatusAndFormats() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let json = """
        {
            "live_status": "post_live",
            "release_timestamp": 1767789011,
            "formats": [
                {"format_id": "137", "vcodec": "avc1.640028", "acodec": "none", "protocol": "https", "ext": "mp4"},
                {"format_id": "140", "vcodec": "none", "acodec": "mp4a.40.2", "protocol": "https", "ext": "m4a"}
            ]
        }
        """
        try fixture.setCall(1, exitCode: 0, stdout: json)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        let options = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertEqual(options.liveStatus, "post_live")
        XCTAssertEqual(options.releaseTimestamp, 1767789011)
        XCTAssertEqual(options.formats.map(\.formatID), ["137", "140"])
        XCTAssertTrue(YTDLPFormat.hasUsableMediaFormats(options.formats))
    }

    /// 播放清單的 `.scheduled` 判定只依賴 `fetchMediaOptions` 回傳的 liveStatus 與
    /// releaseTimestamp，兩者在改寫後仍須正確回傳。
    func testUpcomingMediaOptionsStillParseLiveStatusAndReleaseTimestamp() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let json = """
        {
            "live_status": "is_upcoming",
            "release_timestamp": 1767789011,
            "formats": []
        }
        """
        try fixture.setCall(1, exitCode: 0, stdout: json)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        let options = try await service.fetchMediaOptions(
            url: Self.mediaOptionsURL,
            cookiesArguments: Self.cookiesArguments
        )

        XCTAssertEqual(options.liveStatus, "is_upcoming")
        XCTAssertEqual(options.releaseTimestamp, 1767789011)
    }

    /// 非登入類失敗改以不帶 cookies 的第一次 stderr 為準後，該訊息仍須能被
    /// `YTDLPErrorClassification.classify` 判為 `.endedLive`，使
    /// `handlePostLiveFormatLookupError` 的既有分支判定不受本變更影響。
    func testEndedLiveFailureMessageStillClassifiesAsEndedLive() async throws {
        let fixture = try makeMetadataFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let message = "ERROR: [youtube] TR_NgGeXWGc: This live event has ended."
        try fixture.setCall(1, exitCode: 1, stdout: "", stderr: message)

        let service = YouTubeMetadataService(ytdlpPathProvider: { fixture.executable.path })
        do {
            _ = try await service.fetchMediaOptions(
                url: Self.mediaOptionsURL,
                cookiesArguments: Self.cookiesArguments
            )
            XCTFail("已結束的直播應拋出 MetadataError.fetchFailed")
        } catch let error as MetadataError {
            guard case .fetchFailed(let thrown) = error else {
                return XCTFail("應為 MetadataError.fetchFailed，實際為 \(error)")
            }
            XCTAssertEqual(YTDLPErrorClassification.classify(thrown), .endedLive)
            // handlePostLiveFormatLookupError 分類的是 localizedDescription，須一併成立
            XCTAssertEqual(YTDLPErrorClassification.classify(error.localizedDescription), .endedLive)
        }

        XCTAssertEqual(fixture.invocationCount, 1)
    }

    // MARK: - 縮圖 URL 生成測試

    func testGetThumbnailURL() async {
        let service = YouTubeMetadataService.shared
        let thumbnailURL = await service.getThumbnailURL(videoId: "dQw4w9WgXcQ")
        XCTAssertEqual(thumbnailURL, "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg")
    }

    // MARK: - yt-dlp fixture 輔助

    /// 記錄每次 invocation 完整引數的假 yt-dlp 執行檔。
    private struct MetadataFixture {
        let directory: URL
        let executable: URL

        /// 目前為止發生的 invocation 次數。
        var invocationCount: Int {
            let counter = directory.appendingPathComponent("invocation-count")
            guard let text = try? String(contentsOf: counter, encoding: .utf8) else { return 0 }
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        /// 指定第 `index` 次（1-based）invocation 的結束碼與輸出。未指定的次數
        /// 沿用預設值：exit code 0、stdout 為空 JSON、stderr 為空。
        func setCall(_ index: Int, exitCode: Int32, stdout: String = "{}", stderr: String = "") throws {
            try String(exitCode).write(
                to: directory.appendingPathComponent("call-\(index).exit"),
                atomically: true,
                encoding: .utf8
            )
            try stdout.write(
                to: directory.appendingPathComponent("call-\(index).stdout"),
                atomically: true,
                encoding: .utf8
            )
            try stderr.write(
                to: directory.appendingPathComponent("call-\(index).stderr"),
                atomically: true,
                encoding: .utf8
            )
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

    /// 建立假 yt-dlp 執行檔：逐次記錄引數，預設以 exit code 0 回傳空 JSON。
    private func makeMetadataFixture() throws -> MetadataFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tubify-MetadataFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let executable = directory.appendingPathComponent("yt-dlp-fixture")
        let script = """
        #!/bin/sh
        dir=\(shellQuote(directory.path))
        counter="$dir/invocation-count"
        n=$(cat "$counter" 2>/dev/null || echo 0)
        n=$((n + 1))
        printf '%s\\n' "$n" > "$counter"

        args="$dir/invocation-$n.args"
        : > "$args"
        for arg in "$@"; do
          printf '%s\\n' "$arg" >> "$args"
        done

        if [ -f "$dir/call-$n.stdout" ]; then
          cat "$dir/call-$n.stdout"
        else
          printf '{}'
        fi
        if [ -f "$dir/call-$n.stderr" ]; then
          cat "$dir/call-$n.stderr" >&2
        fi
        exit "$(cat "$dir/call-$n.exit" 2>/dev/null || printf 0)"
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        return MetadataFixture(directory: directory, executable: executable)
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
