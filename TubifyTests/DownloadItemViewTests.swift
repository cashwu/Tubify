import XCTest
@testable import Tubify

final class DownloadItemViewTests: XCTestCase {
    func testErrorSummaryUsesFirstNonEmptyTrimmedLine() {
        let message = "  \n\tERROR: Video unavailable  \nAdditional diagnostic details"

        XCTAssertEqual(
            DownloadItemView.errorSummary(for: message),
            "ERROR: Video unavailable"
        )
    }

    func testErrorSummaryUsesFallbackForWhitespaceOnlyMessage() {
        XCTAssertEqual(
            DownloadItemView.errorSummary(for: " \n\t  \n"),
            "無法取得錯誤詳細資訊"
        )
    }

    func testErrorSummaryUsesFallbackForNilMessage() {
        XCTAssertEqual(
            DownloadItemView.errorSummary(for: nil),
            "無法取得錯誤詳細資訊"
        )
    }

    func testErrorSummaryTruncatesOverlongLineTo160Characters() {
        let message = String(repeating: "a", count: 161)
        let summary = DownloadItemView.errorSummary(for: message)

        XCTAssertEqual(summary.count, 160)
        XCTAssertEqual(summary, String(repeating: "a", count: 159) + "…")
    }

    func testErrorSummaryCountsExtendedGraphemeClustersAsCharacters() {
        let familyEmoji = "👨‍👩‍👧‍👦"
        let message = String(repeating: familyEmoji, count: 160) + "尾"
        let summary = DownloadItemView.errorSummary(for: message)

        XCTAssertEqual(summary.count, 160)
        XCTAssertEqual(summary, String(repeating: familyEmoji, count: 159) + "…")
    }
}
