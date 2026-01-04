import XCTest
@testable import Tubify

/// PremiereErrorParser 測試
final class PremiereErrorParserTests: XCTestCase {

    // MARK: - isPremiereError 測試

    func testIsPremiereError_WithValidPremiereMessage() {
        XCTAssertTrue(PremiereErrorParser.isPremiereError("ERROR: [youtube] sV7cOFFZsPk: Premieres in 81 minutes"))
        XCTAssertTrue(PremiereErrorParser.isPremiereError("Premieres in 2 hours"))
        XCTAssertTrue(PremiereErrorParser.isPremiereError("Video Premieres in 1 day"))
    }

    func testIsPremiereError_WithNonPremiereMessage() {
        XCTAssertFalse(PremiereErrorParser.isPremiereError("ERROR: Video unavailable"))
        XCTAssertFalse(PremiereErrorParser.isPremiereError("Network error"))
        XCTAssertFalse(PremiereErrorParser.isPremiereError(""))
    }

    // MARK: - parsePremiereDate 測試 - 分鐘

    func testParsePremiereDate_WithMinutes() {
        let now = Date()
        let error = "ERROR: [youtube] sV7cOFFZsPk: Premieres in 81 minutes"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 81 * 60.0
            let actualInterval = date.timeIntervalSince(now)
            // 允許 2 秒誤差（測試執行時間）
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    func testParsePremiereDate_WithSingleMinute() {
        let now = Date()
        let error = "Premieres in 1 minute"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 60.0
            let actualInterval = date.timeIntervalSince(now)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    // MARK: - parsePremiereDate 測試 - 小時

    func testParsePremiereDate_WithHours() {
        let now = Date()
        let error = "Premieres in 2 hours"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 2 * 3600.0
            let actualInterval = date.timeIntervalSince(now)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    func testParsePremiereDate_WithSingleHour() {
        let now = Date()
        let error = "Premieres in 1 hour"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 3600.0
            let actualInterval = date.timeIntervalSince(now)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    // MARK: - parsePremiereDate 測試 - 天

    func testParsePremiereDate_WithDays() {
        let now = Date()
        let error = "Premieres in 3 days"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 3 * 86400.0
            let actualInterval = date.timeIntervalSince(now)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    func testParsePremiereDate_WithSingleDay() {
        let now = Date()
        let error = "Premieres in 1 day"

        let result = PremiereErrorParser.parsePremiereDate(from: error)

        XCTAssertNotNil(result)
        if let date = result {
            let expectedInterval = 86400.0
            let actualInterval = date.timeIntervalSince(now)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 2.0)
        }
    }

    // MARK: - parsePremiereDate 測試 - 無效輸入

    func testParsePremiereDate_WithNonPremiereError() {
        let result = PremiereErrorParser.parsePremiereDate(from: "ERROR: Video unavailable")
        XCTAssertNil(result)
    }

    func testParsePremiereDate_WithEmptyString() {
        let result = PremiereErrorParser.parsePremiereDate(from: "")
        XCTAssertNil(result)
    }

    func testParsePremiereDate_WithPartialMatch() {
        // 缺少數字
        let result1 = PremiereErrorParser.parsePremiereDate(from: "Premieres in minutes")
        XCTAssertNil(result1)

        // 缺少單位
        let result2 = PremiereErrorParser.parsePremiereDate(from: "Premieres in 30")
        XCTAssertNil(result2)
    }

    func testParsePremiereDate_WithUnknownUnit() {
        // 不支援的單位
        let result = PremiereErrorParser.parsePremiereDate(from: "Premieres in 2 weeks")
        XCTAssertNil(result)
    }

    // MARK: - parsePremiereDate 測試 - 大小寫不敏感

    func testParsePremiereDate_CaseInsensitive() {
        let error1 = "PREMIERES IN 30 MINUTES"
        let error2 = "premieres in 30 minutes"
        let error3 = "Premieres In 30 Minutes"

        XCTAssertNotNil(PremiereErrorParser.parsePremiereDate(from: error1))
        XCTAssertNotNil(PremiereErrorParser.parsePremiereDate(from: error2))
        XCTAssertNotNil(PremiereErrorParser.parsePremiereDate(from: error3))
    }

    // MARK: - parsePremiereDate 測試 - 完整的 yt-dlp 錯誤訊息

    func testParsePremiereDate_WithFullYTDLPError() {
        let error = "ERROR: [youtube] sV7cOFFZsPk: Premieres in 81 minutes"
        let result = PremiereErrorParser.parsePremiereDate(from: error)
        XCTAssertNotNil(result)
    }
}
