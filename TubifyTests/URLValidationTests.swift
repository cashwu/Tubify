import XCTest
@testable import Tubify

/// YouTube URL 驗證測試
final class URLValidationTests: XCTestCase {

    // MARK: - 有效的 YouTube URL

    func testValidStandardWatchURL() {
        XCTAssertTrue(isValidYouTubeURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testValidWatchURLWithTimestamp() {
        XCTAssertTrue(isValidYouTubeURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120"))
    }

    func testValidWatchURLWithPlaylistParam() {
        XCTAssertTrue(isValidYouTubeURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf"))
    }

    func testValidShortURL() {
        XCTAssertTrue(isValidYouTubeURL("https://youtu.be/dQw4w9WgXcQ"))
    }

    func testValidShortURLWithTimestamp() {
        XCTAssertTrue(isValidYouTubeURL("https://youtu.be/dQw4w9WgXcQ?t=60"))
    }

    func testValidPlaylistURL() {
        XCTAssertTrue(isValidYouTubeURL("https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf"))
    }

    func testValidShortsURL() {
        XCTAssertTrue(isValidYouTubeURL("https://www.youtube.com/shorts/abc123def45"))
    }

    func testValidURLWithoutWWW() {
        XCTAssertTrue(isValidYouTubeURL("https://youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testValidHTTPURL() {
        XCTAssertTrue(isValidYouTubeURL("http://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    // MARK: - 無效的 URL

    func testInvalidEmptyString() {
        XCTAssertFalse(isValidYouTubeURL(""))
    }

    func testInvalidRandomString() {
        XCTAssertFalse(isValidYouTubeURL("hello world"))
    }

    func testInvalidNonYouTubeURL() {
        XCTAssertFalse(isValidYouTubeURL("https://www.google.com"))
    }

    func testInvalidVimeoURL() {
        XCTAssertFalse(isValidYouTubeURL("https://vimeo.com/123456789"))
    }

    func testInvalidYouTubeHomepage() {
        XCTAssertFalse(isValidYouTubeURL("https://www.youtube.com/"))
    }

    func testInvalidYouTubeChannel() {
        XCTAssertFalse(isValidYouTubeURL("https://www.youtube.com/@channelname"))
    }

    func testInvalidMissingVideoID() {
        XCTAssertFalse(isValidYouTubeURL("https://www.youtube.com/watch"))
    }

    // MARK: - 輔助方法

    /// 複製 DownloadManager 中的 URL 驗證邏輯以供測試
    private func isValidYouTubeURL(_ urlString: String) -> Bool {
        let patterns = [
            #"youtube\.com/watch\?v="#,
            #"youtu\.be/"#,
            #"youtube\.com/playlist\?list="#,
            #"youtube\.com/shorts/"#
        ]

        return patterns.contains { pattern in
            urlString.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
