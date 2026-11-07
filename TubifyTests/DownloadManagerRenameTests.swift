import XCTest
@testable import Tubify

/// DownloadManager 的任務改名流程（rename-download-title R5–R12）
///
/// 證據邊界：yt-dlp 由 MockYTDLPService 取代，回傳的輸出路徑指向暫存目錄裡預先建立的假檔；
/// 真實 yt-dlp 的檔名、字幕命名與 `__real_download` 行為不在這裡驗證。
@MainActor
final class DownloadManagerRenameTests: XCTestCase {
    private var manager: DownloadManager!
    private var mockPersistence: MockPersistenceService!
    private var mockMetadataService: MockYouTubeMetadataService!
    private var mockYTDLPService: MockYTDLPService!
    private var mockNotificationService: MockNotificationService!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockPersistenceService()
        mockMetadataService = MockYouTubeMetadataService()
        mockYTDLPService = MockYTDLPService()
        mockNotificationService = MockNotificationService()
        defaultsSuiteName = "DownloadManagerRenameTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadManagerRenameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults.set(directory.path, forKey: AppSettingsKeys.downloadFolder)
        manager = makeManager(with: [])
    }

    override func tearDown() async throws {
        manager = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    // MARK: - 輔助方法

    private func makeManager(with tasks: [DownloadTask]) -> DownloadManager {
        mockPersistence.savedTasks = tasks
        return DownloadManager(
            persistenceService: mockPersistence,
            metadataService: mockMetadataService,
            ytdlpService: mockYTDLPService,
            notificationService: mockNotificationService,
            defaults: defaults
        )
    }

    private func path(_ name: String) -> String {
        directory.appendingPathComponent(name).path
    }

    @discardableResult
    private func makeFile(_ name: String, contents: String? = nil) throws -> String {
        let filePath = path(name)
        try (contents ?? name).write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    private func fileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    private func waitUntil(timeout: TimeInterval = 2, condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    /// 讓 yt-dlp mock 「下載」出指定檔名的假檔，回傳該路徑
    @discardableResult
    private func stubDownloadedFile(_ name: String, producedByThisDownload: Bool = true) throws -> String {
        let filePath = try makeFile(name)
        mockYTDLPService.outputPath = filePath
        mockYTDLPService.didProduceOutputFile = producedByThisDownload
        return filePath
    }

    private func runDownload(_ task: DownloadTask) async -> Bool {
        manager.tasks = [task]
        manager.startDownloadQueue()
        return await waitUntil { task.status == .completed }
    }

    private func savedTask(_ task: DownloadTask) -> DownloadTask? {
        mockPersistence.savedTasks.first { $0.id == task.id }
    }

    // MARK: - 未完成任務：只更新名稱（R3、R5、R7）

    func testRenamePendingTaskUpdatesDisplayTitleAndPersists() async {
        // E1：清單立即顯示新名稱
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=pending", title: "觸控屏 Macbook，最大的優點竟然是... | 大耳朵 TV", status: .pending)
        manager.tasks = [task]

        let result = manager.renameTask(task, to: "  Macbook 觸控屏 ")

        XCTAssertEqual(result, .renamed)
        XCTAssertEqual(task.displayTitle, "Macbook 觸控屏")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(savedTask(task)?.customTitle, "Macbook 觸控屏")
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty, "改名不會啟動下載")
    }

    func testRenameDuringDownloadKeepsDownloadRunningAndNamesFinalFile() async throws {
        // E2：在 yt-dlp 回傳前（下載進行中）改名。下載不被取消或重啟、進度不歸零，
        // 完成時才讀取自訂名稱，所以檔名與完成通知都使用新名稱
        try stubDownloadedFile("原始.mp4")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=downloading", title: "原始", status: .pending)
        var renameResult: TaskRenameResult?
        var statusDuringRename: DownloadStatus?
        var progressBefore: Double?
        var progressAfter: Double?
        mockYTDLPService.beforeReturn = { @MainActor [unowned self] in
            statusDuringRename = task.status
            progressBefore = task.progress
            renameResult = manager.renameTask(task, to: "新名稱")
            progressAfter = task.progress
        }

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(statusDuringRename, .downloading)
        XCTAssertEqual(renameResult, .renamed)
        XCTAssertEqual(progressAfter, progressBefore)
        XCTAssertTrue(mockYTDLPService.cancelledTaskIDs.isEmpty)
        XCTAssertEqual(mockYTDLPService.downloadedURLs, [task.url], "yt-dlp 只執行一次")
        XCTAssertEqual(task.outputPath, path("新名稱.mp4"))
        XCTAssertEqual(mockNotificationService.completedNotifications.map(\.outputPath), [path("新名稱.mp4")])
    }

    func testRenameWithBlankOrUnchangedInputChangesNothing() async {
        // E6：只有空白或與目前名稱相同都視為沒有變更
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=same", title: "原始", status: .failed)
        manager.tasks = [task]

        let blank = manager.renameTask(task, to: "   ")
        let same = manager.renameTask(task, to: " 原始 ")

        XCTAssertEqual(blank, .unchanged)
        XCTAssertEqual(same, .unchanged)
        XCTAssertNil(task.customTitle)
        XCTAssertFalse(mockPersistence.saveTasksCalled)
    }

    func testPlaylistPlaceholderCannotBeRenamed() async {
        // E13：佔位任務展開後會被取代；改了也會破壞復原流程的佔位判斷
        let task = DownloadTask(url: "https://www.youtube.com/playlist?list=PL1", title: DownloadTask.playlistPlaceholderTitle, status: .fetchingInfo)
        manager.tasks = [task]

        let result = manager.renameTask(task, to: "新名稱")

        XCTAssertEqual(result, .unchanged)
        XCTAssertNil(task.customTitle)
        XCTAssertEqual(task.title, DownloadTask.playlistPlaceholderTitle)
    }

    func testCustomTitleSurvivesMetadataRecoveryAndNamesDownloadedFile() async throws {
        // E8：獲取資訊中改名後重啟 App。復原流程仍以佔位標題「載入中...」判斷要重新抓元資料（R5），
        // 元資料回來後顯示名稱仍是自訂名稱，下載完成的檔名也是它（R6、R7）
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=recover", status: .fetchingInfo)
        task.customTitle = "自訂"
        let persisted = try JSONDecoder().decode(DownloadTask.self, from: JSONEncoder().encode(task))
        mockMetadataService.videoInfo = VideoInfo(
            id: "recover", title: "元資料標題", thumbnail: nil, duration: 60, uploader: "Test",
            url: task.url, liveStatus: nil, releaseTimestamp: nil
        )
        try stubDownloadedFile("元資料標題.mp4")
        manager = makeManager(with: [persisted])

        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        let completed = await waitUntil { persisted.status == .completed }

        XCTAssertTrue(completed)
        XCTAssertEqual(mockMetadataService.fetchedVideoURLs, [task.url])
        XCTAssertEqual(persisted.title, "元資料標題")
        XCTAssertEqual(persisted.displayTitle, "自訂")
        XCTAssertEqual(persisted.outputPath, path("自訂.mp4"))
        XCTAssertEqual(try fileNames(), ["自訂.mp4"])
    }

    func testTitleFallbacksDoNotOverrideCustomTitle() async throws {
        // R5：元資料抓取失敗時寫入的「無法獲取標題」，以及完成時用檔名補標題，都只改元資料標題
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=fallback", status: .fetchingInfo)
        task.customTitle = "自訂"
        mockMetadataService.videoInfoError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "network down"])
        try stubDownloadedFile("檔名標題.mp4")
        manager = makeManager(with: [task])

        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        let completed = await waitUntil { task.status == .completed }

        XCTAssertTrue(completed)
        XCTAssertEqual(task.title, "檔名標題")
        XCTAssertEqual(task.displayTitle, "自訂")
        XCTAssertEqual(task.outputPath, path("自訂.mp4"))
    }

    // MARK: - 下載完成時套用（R7–R11）

    func testCompletedDownloadUsesCustomTitleForFileAndNotification() async throws {
        // E1、E2：完成通知與 outputPath 使用改名後的路徑
        try stubDownloadedFile("原始.mp4")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=complete", title: "原始", status: .pending)
        task.customTitle = "Macbook 觸控屏"

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.outputPath, path("Macbook 觸控屏.mp4"))
        XCTAssertEqual(try fileNames(), ["Macbook 觸控屏.mp4"])
        XCTAssertEqual(mockNotificationService.completedNotifications.map(\.outputPath), [path("Macbook 觸控屏.mp4")])
        XCTAssertEqual(mockNotificationService.completedNotifications.map(\.title), ["Macbook 觸控屏"])
        XCTAssertEqual(task.ownsOutputFile, true)
    }

    func testCompletedDownloadAppliesFileNameConversion() async throws {
        // E7
        try stubDownloadedFile("原始.mp4")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=convert", title: "原始", status: .pending)
        task.customTitle = "評測 / 重量: 心得"

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.displayTitle, "評測 / 重量: 心得")
        XCTAssertEqual(task.outputPath, path("評測 ⧸ 重量： 心得.mp4"))
    }

    func testCompletedDownloadRenamesSelectedSubtitlesTogetherWithNumbering() async throws {
        // E16：只有字幕目標被佔用，影片與字幕一起編號；既有的字幕不變
        try stubDownloadedFile("原始.mp4")
        try makeFile("原始.en.srt")
        try makeFile("新.en.srt", contents: "既有")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=subtitle", title: "原始", status: .pending)
        task.subtitleSelection = SubtitleSelection(selectedLanguages: [], automaticLanguages: ["en"])
        task.customTitle = "新"

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.outputPath, path("新 (1).mp4"))
        XCTAssertEqual(try fileNames(), ["新.en.srt", "新 (1).mp4", "新 (1).en.srt"])
        XCTAssertEqual(task.displayTitle, "新", "清單顯示使用者輸入的名稱，不含編號")
    }

    func testReusedFileIsCopiedWhenTaskHasCustomTitle() async throws {
        // E5：yt-dlp 沿用既有的 A.mp4，複製出 B.mp4，A.mp4 保留
        try stubDownloadedFile("A.mp4", producedByThisDownload: false)
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=reused", title: "A", status: .pending)
        task.customTitle = "B"

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.outputPath, path("B.mp4"))
        XCTAssertEqual(try fileNames(), ["A.mp4", "B.mp4"])
        XCTAssertEqual(task.ownsOutputFile, true, "複製出的檔案屬於本任務")
    }

    func testCompletedDownloadRecordsWhetherOutputFileIsOwned() async throws {
        let reused = DownloadTask(url: "https://www.youtube.com/watch?v=reused", title: "A", status: .pending)
        try stubDownloadedFile("A.mp4", producedByThisDownload: false)

        let completed = await runDownload(reused)

        XCTAssertTrue(completed)
        XCTAssertEqual(reused.ownsOutputFile, false)
        XCTAssertEqual(savedTask(reused)?.ownsOutputFile, false)
    }

    func testCompletedRealDownloadWithoutCustomTitleIsRecordedAsOwned() async throws {
        // 沒有自訂名稱時也要記錄來源：實際下載產生的檔案之後改名要直接改名，不能被當成沿用檔而複製出重複檔案
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=produced", title: "A", status: .pending)
        try stubDownloadedFile("A.mp4", producedByThisDownload: true)

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.ownsOutputFile, true)
        XCTAssertEqual(savedTask(task)?.ownsOutputFile, true)
    }

    func testRenameFailureAtCompletionFallsBackToOriginalFile() async throws {
        // E11：名稱超過檔案系統長度限制。任務仍完成，outputPath 與通知用原始檔，清單顯示原始主檔名
        let original = try stubDownloadedFile("原始.mp4")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=toolong", title: "元資料標題", status: .pending)
        task.customTitle = String(repeating: "長", count: 300)

        let completed = await runDownload(task)

        XCTAssertTrue(completed)
        XCTAssertEqual(task.outputPath, original)
        XCTAssertEqual(task.displayTitle, "原始")
        XCTAssertEqual(mockNotificationService.completedNotifications.map(\.outputPath), [original])
        XCTAssertEqual(try fileNames(), ["原始.mp4"])
    }

    func testFailedTaskRenamedThenRetriedUsesCustomTitle() async throws {
        // E9
        try stubDownloadedFile("原始.mp4")
        let task = DownloadTask(url: "https://www.youtube.com/watch?v=retry", title: "原始", status: .failed)
        manager.tasks = [task]

        let result = manager.renameTask(task, to: "新")
        manager.retryTask(task)
        let completed = await waitUntil { task.status == .completed }

        XCTAssertEqual(result, .renamed)
        XCTAssertTrue(completed)
        XCTAssertEqual(task.outputPath, path("新.mp4"))
    }

    // MARK: - 已完成任務（R11、R12）

    private func makeCompletedTask(fileName: String, ownsOutputFile: Bool?, subtitleLanguages: [String] = []) throws -> DownloadTask {
        let filePath = try makeFile(fileName)
        let task = DownloadTask(
            url: "https://www.youtube.com/watch?v=done",
            title: URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent,
            status: .completed,
            progress: 1,
            outputPath: filePath
        )
        task.ownsOutputFile = ownsOutputFile
        if !subtitleLanguages.isEmpty {
            task.subtitleSelection = SubtitleSelection(selectedLanguages: subtitleLanguages)
        }
        manager.tasks = [task]
        return task
    }

    func testRenameCompletedTaskRenamesVideoAndSubtitlesWithoutNotifyingAgain() async throws {
        // E3、R12：直接改名、更新 outputPath，不重新送出通知
        let task = try makeCompletedTask(fileName: "舊.mp4", ownsOutputFile: true, subtitleLanguages: ["zh-Hant"])
        try makeFile("舊.zh-Hant.srt")

        let result = manager.renameTask(task, to: "新")

        XCTAssertEqual(result, .renamed)
        XCTAssertEqual(try fileNames(), ["新.mp4", "新.zh-Hant.srt"])
        XCTAssertEqual(task.outputPath, path("新.mp4"))
        XCTAssertEqual(task.displayTitle, "新")
        XCTAssertEqual(savedTask(task)?.outputPath, path("新.mp4"))
        XCTAssertTrue(mockNotificationService.completedNotifications.isEmpty)
    }

    func testRenameCompletedTaskWithMissingFileReportsErrorAndKeepsState() async throws {
        // E10：檔案已被使用者移走
        let task = try makeCompletedTask(fileName: "舊.mp4", ownsOutputFile: true)
        let originalPath = try XCTUnwrap(task.outputPath)
        try FileManager.default.removeItem(atPath: originalPath)

        let result = manager.renameTask(task, to: "新")

        guard case .failed(let message) = result else {
            return XCTFail("應回報失敗，實際為 \(result)")
        }
        XCTAssertTrue(message.contains("找不到檔案"), message)
        XCTAssertEqual(task.displayTitle, "舊")
        XCTAssertNil(task.customTitle)
        XCTAssertEqual(task.outputPath, originalPath)
    }

    func testRenameCompletedLegacyTaskMovesFileAndAllowsCaseOnlyChange() async throws {
        // E14：沒有來源記錄的舊任務視為屬於本任務，只改大小寫也直接改名
        let task = try makeCompletedTask(fileName: "abc.mp4", ownsOutputFile: nil)

        let result = manager.renameTask(task, to: "ABC")

        XCTAssertEqual(result, .renamed)
        XCTAssertEqual(try fileNames(), ["ABC.mp4"])
        XCTAssertEqual(task.outputPath, path("ABC.mp4"))
    }

    func testRenameCompletedTaskWithReusedFileCopiesThenMovesOwnCopy() async throws {
        // E15：沿用的 A.mp4 保留並複製成 B.mp4；B.mp4 從此屬於本任務，再改名成 C 時直接改名
        let task = try makeCompletedTask(fileName: "A.mp4", ownsOutputFile: false)
        let restored = try JSONDecoder().decode(DownloadTask.self, from: JSONEncoder().encode(task))
        manager.tasks = [restored]

        let first = manager.renameTask(restored, to: "B")
        XCTAssertEqual(first, .renamed)
        XCTAssertEqual(try fileNames(), ["A.mp4", "B.mp4"])
        XCTAssertEqual(restored.outputPath, path("B.mp4"))
        XCTAssertEqual(restored.ownsOutputFile, true)

        let second = manager.renameTask(restored, to: "C")
        XCTAssertEqual(second, .renamed)
        XCTAssertEqual(try fileNames(), ["A.mp4", "C.mp4"])
        XCTAssertEqual(restored.outputPath, path("C.mp4"))
    }
}
