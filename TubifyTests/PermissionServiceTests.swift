import XCTest
@testable import Tubify

/// PermissionService 測試
final class PermissionServiceTests: XCTestCase {

    // MARK: - Helpers

    private func notFoundError() -> Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
    }

    private func permissionDeniedError() -> Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
    }

    // MARK: - hasFullDiskAccess

    /// 任一 cookies 檔案能開啟即代表有權限。
    func testHasFullDiskAccessWhenACookiesFileOpens() {
        var listedDirectories: [String] = []

        let granted = PermissionService.shared.hasFullDiskAccess(
            openFile: { path in
                // 模擬舊路徑不存在、容器路徑可開啟（容器路徑本身也含 /Library/Cookies/，
                // 因此以 /Containers/ 區分兩者）。
                if !path.contains("/Containers/") { throw self.notFoundError() }
            },
            listDirectory: { listedDirectories.append($0) }
        )

        XCTAssertTrue(granted)
        // 已由檔案判定，不應退回目錄檢查。
        XCTAssertTrue(listedDirectories.isEmpty)
    }

    /// 迴歸測試：cookies 檔案存在卻讀不到就是權限被拒，不得再用目錄檢查覆蓋這個結論。
    /// 先前因無條件退回目錄檢查，而 `~/Library/Cookies` 常是 Safari 沙箱化前遺留的空目錄，
    /// 導致未授權時仍被判定為已授權，UI 不提示、cookies 導出卻靜默失敗。
    func testDoesNotHaveFullDiskAccessWhenCookiesFileExistsButIsUnreadable() {
        var listedDirectories: [String] = []

        let granted = PermissionService.shared.hasFullDiskAccess(
            openFile: { path in
                // 舊路徑不存在；容器路徑存在卻讀不到。
                if !path.contains("/Containers/") { throw self.notFoundError() }
                throw self.permissionDeniedError()
            },
            listDirectory: { path in
                listedDirectories.append(path)
                // 空目錄可列出——正是先前造成誤判的情境。
            }
        )

        XCTAssertFalse(granted)
        XCTAssertTrue(listedDirectories.isEmpty, "已判定權限被拒時不應再做目錄檢查")
    }

    /// 所有 cookies 檔案都不存在時，才退回以目錄是否可列出判斷。
    func testFallsBackToDirectoryCheckWhenNoCookiesFileExists() {
        var listedDirectories: [String] = []

        let granted = PermissionService.shared.hasFullDiskAccess(
            openFile: { _ in throw self.notFoundError() },
            listDirectory: { listedDirectories.append($0) }
        )

        XCTAssertTrue(granted)
        XCTAssertEqual(listedDirectories.count, 1, "第一個可列出的目錄就足以判定")
    }

    /// cookies 檔案都不存在、目錄也都列不出來時，判定為沒有權限。
    func testDoesNotHaveFullDiskAccessWhenNothingIsReachable() {
        let granted = PermissionService.shared.hasFullDiskAccess(
            openFile: { _ in throw self.notFoundError() },
            listDirectory: { _ in throw self.permissionDeniedError() }
        )

        XCTAssertFalse(granted)
    }

    // MARK: - commandUsesSafariCookies

    func testCommandUsesSafariCookiesDetectsBothForms() {
        XCTAssertTrue(PermissionService.shared.commandUsesSafariCookies(
            "yt-dlp --cookies-from-browser safari \"$youtubeUrl\""
        ))
        XCTAssertTrue(PermissionService.shared.commandUsesSafariCookies(
            "yt-dlp --cookies-from-browser=safari \"$youtubeUrl\""
        ))
        XCTAssertFalse(PermissionService.shared.commandUsesSafariCookies(
            "yt-dlp -S ext:mp4 \"$youtubeUrl\""
        ))
    }
}
