import XCTest
@testable import Tubify

/// Whispify 等外部 App 的完成回調參數。
/// 證據邊界：只驗證組出的 URL，不開啟 URL，也不能證明 Whispify 實際如何解讀參數。
final class CallbackServiceTests: XCTestCase {
    private func queryValue(_ name: String, in url: URL?) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first { $0.name == name }?.value
    }

    func testCallbackCarriesGivenFilePathAndMetadataTitle() {
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc", title: "原始標題")
        task.requestId = "req-1"

        let url = CallbackService.makeCallbackURL(scheme: "whispify", task: task, filePath: "/tmp/原始標題.mp4")

        XCTAssertEqual(url?.scheme, "whispify")
        XCTAssertEqual(url?.host, "import")
        XCTAssertEqual(queryValue("request_id", in: url), "req-1")
        XCTAssertEqual(queryValue("file", in: url), "/tmp/原始標題.mp4")
        XCTAssertEqual(queryValue("title", in: url), "原始標題")
    }

    func testCallbackTitleUsesCustomTitle() {
        // 改名後 file 已是自訂名稱的檔案，title 也要用同一個名稱，外部 App 看到的名稱才會和檔案一致
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=abc", title: "觸控屏 Macbook，最大的優點竟然是... | 大耳朵 TV")
        task.customTitle = "Macbook 觸控屏"

        let url = CallbackService.makeCallbackURL(scheme: "whispify", task: task, filePath: "/tmp/Macbook 觸控屏.mp4")

        XCTAssertEqual(queryValue("file", in: url), "/tmp/Macbook 觸控屏.mp4")
        XCTAssertEqual(queryValue("title", in: url), "Macbook 觸控屏")
    }

    func testCallbackOmitsPlaceholderTitle() {
        let loading = DownloadTask(url: "https://www.youtube.com/watch?v=abc")
        let unknown = DownloadTask(url: "https://www.youtube.com/watch?v=abc", title: "無法獲取標題")

        XCTAssertNil(queryValue("title", in: CallbackService.makeCallbackURL(scheme: "whispify", task: loading, filePath: "/tmp/a.mp4")))
        XCTAssertNil(queryValue("title", in: CallbackService.makeCallbackURL(scheme: "whispify", task: unknown, filePath: "/tmp/a.mp4")))
    }
}
