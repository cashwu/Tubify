import XCTest
@testable import Tubify

final class NotificationServiceTests: XCTestCase {
    func testAppDelegateInitializesNotificationServiceBeforeLaunchFinishes() {
        var initializationCount = 0
        let delegate = AppDelegate {
            initializationCount += 1
        }

        delegate.applicationWillFinishLaunching(
            Notification(name: NSApplication.willFinishLaunchingNotification)
        )

        XCTAssertEqual(initializationCount, 1)
    }

    func testOutputRouterRevealsExistingOutputPath() {
        var checkedPaths: [String] = []
        var revealedPaths: [String] = []
        let router = NotificationOutputRouter(
            fileExists: { path in
                checkedPaths.append(path)
                return true
            },
            revealInFinder: { revealedPaths.append($0) }
        )

        router.route(userInfo: ["outputPath": "/tmp/video.mp4"])

        XCTAssertEqual(checkedPaths, ["/tmp/video.mp4"])
        XCTAssertEqual(revealedPaths, ["/tmp/video.mp4"])
    }

    func testOutputRouterIgnoresMissingOutputPath() {
        var checkedPathCount = 0
        var revealCount = 0
        let router = NotificationOutputRouter(
            fileExists: { _ in
                checkedPathCount += 1
                return true
            },
            revealInFinder: { _ in revealCount += 1 }
        )

        router.route(userInfo: [:])

        XCTAssertEqual(checkedPathCount, 0)
        XCTAssertEqual(revealCount, 0)
    }

    func testOutputRouterIgnoresInvalidOutputPath() {
        var revealedPaths: [String] = []
        let router = NotificationOutputRouter(
            fileExists: { _ in false },
            revealInFinder: { revealedPaths.append($0) }
        )

        router.route(userInfo: ["outputPath": "/tmp/deleted.mp4"])

        XCTAssertTrue(revealedPaths.isEmpty)
    }

    func testActivatedNotificationCompletesExactlyOnceForValidMissingAndInvalidPaths() {
        let cases: [(userInfo: [AnyHashable: Any], pathExists: Bool)] = [
            (["outputPath": "/tmp/video.mp4"], true),
            ([:], false),
            (["outputPath": "/tmp/deleted.mp4"], false),
        ]

        for testCase in cases {
            var completionCount = 0
            let service = NotificationService(outputRouter: NotificationOutputRouter(
                fileExists: { _ in testCase.pathExists },
                revealInFinder: { _ in }
            ))

            service.handleActivatedNotification(userInfo: testCase.userInfo) {
                completionCount += 1
            }

            XCTAssertEqual(completionCount, 1, "userInfo: \(testCase.userInfo)")
        }
    }

}
