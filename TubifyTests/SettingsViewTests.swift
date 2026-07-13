import XCTest
@testable import Tubify

final class SettingsViewTests: XCTestCase {
    func testDownloadCommandValidationRejectsEmptyCommand() {
        XCTAssertEqual(validateDownloadCommand("  \n\t"), .empty)
    }

    func testDownloadCommandValidationRequiresYouTubeURLPlaceholder() {
        XCTAssertEqual(
            validateDownloadCommand("yt-dlp --format best"),
            .missingYouTubeURLPlaceholder
        )
    }

    func testDownloadCommandValidationAcceptsYouTubeURLPlaceholder() {
        XCTAssertEqual(
            validateDownloadCommand("yt-dlp --format best $youtubeUrl"),
            .valid
        )
    }
}
