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

    // MARK: - 縮圖 URL 生成測試

    func testGetThumbnailURL() async {
        let service = YouTubeMetadataService.shared
        let thumbnailURL = await service.getThumbnailURL(videoId: "dQw4w9WgXcQ")
        XCTAssertEqual(thumbnailURL, "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg")
    }
}
