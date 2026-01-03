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
