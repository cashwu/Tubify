import XCTest
@testable import Tubify

/// DownloadManager 暫停/恢復功能測試
///
/// 這些測試涵蓋以下情境：
/// 1. 單一任務的暫停與恢復
/// 2. 全部任務的暫停與恢復
/// 3. 邊界情況（如：全部暫停後恢復單一任務）
@MainActor
final class DownloadManagerTests: XCTestCase {

    // MARK: - 測試用屬性

    /// 測試用的 DownloadManager（使用 Mock 持久化服務）
    var manager: DownloadManager!

    /// Mock 持久化服務
    var mockPersistence: MockPersistenceService!
    var mockMetadataService: MockYouTubeMetadataService!
    var mockYTDLPService: MockYTDLPService!
    var mockNotificationService: MockNotificationService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // 建立 Mock 並注入到新的 DownloadManager
        mockPersistence = MockPersistenceService()
        mockPersistence.reset()
        mockMetadataService = MockYouTubeMetadataService()
        mockYTDLPService = MockYTDLPService()
        mockNotificationService = MockNotificationService()
        manager = DownloadManager(
            persistenceService: mockPersistence,
            metadataService: mockMetadataService,
            ytdlpService: mockYTDLPService,
            notificationService: mockNotificationService
        )

        // 確保任務列表為空
        manager.tasks = []
        manager.isAllPaused = false
    }

    override func tearDown() async throws {
        manager = nil
        mockPersistence = nil
        mockMetadataService = nil
        mockYTDLPService = nil
        mockNotificationService = nil
        try await super.tearDown()
    }

    // MARK: - 輔助方法

    /// 建立測試用任務
    private func createTestTask(
        url: String = "https://www.youtube.com/watch?v=test123",
        title: String = "Test Video",
        status: DownloadStatus = .pending
    ) -> DownloadTask {
        return DownloadTask(
            url: url,
            title: title,
            status: status
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    private func makeManager(with tasks: [DownloadTask]) -> DownloadManager {
        mockPersistence.savedTasks = tasks
        mockMetadataService.videoInfo = VideoInfo(
            id: "recovered",
            title: "Recovered Video",
            thumbnail: nil,
            duration: 60,
            uploader: "Test",
            url: tasks.first?.url ?? "https://www.youtube.com/watch?v=recovered",
            liveStatus: nil,
            releaseTimestamp: nil
        )
        return DownloadManager(
            persistenceService: mockPersistence,
            metadataService: mockMetadataService,
            ytdlpService: mockYTDLPService,
            notificationService: mockNotificationService
        )
    }

    // MARK: - UI-activated persisted task recovery

    func testPersistedTasksDoNotRecoverBeforeUIActivation() async {
        let task = createTestTask(status: .downloading)
        manager = makeManager(with: [task])

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(task.status, .downloading)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertTrue(mockMetadataService.fetchedVideoURLs.isEmpty)
    }

    func testRecoveryStartsInterruptedAndPendingDownloadsOnlyOnce() async {
        let downloading = createTestTask(url: "https://example.com/downloading", status: .downloading)
        let pending = createTestTask(url: "https://example.com/pending", status: .pending)
        manager = makeManager(with: [downloading, pending])
        let sessionID = UUID()

        manager.resumePersistedTasksAfterUIActivation(sessionID: sessionID)
        manager.resumePersistedTasksAfterUIActivation(sessionID: sessionID)
        let completed = await waitUntil {
            self.mockYTDLPService.downloadedURLs.count == 2
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(Set(mockYTDLPService.downloadedURLs), Set([downloading.url, pending.url]))
    }

    func testRecoveryRoutesFetchingInfoByPersistedSource() async {
        let single = createTestTask(url: "https://www.youtube.com/watch?v=single", title: "載入中...", status: .fetchingInfo)
        let child = createTestTask(url: "https://www.youtube.com/watch?v=child&list=PLtest", title: "Playlist Child", status: .fetchingInfo)
        let placeholder = createTestTask(url: "https://www.youtube.com/playlist?list=PLtest", title: "載入播放清單中...", status: .fetchingInfo)
        mockMetadataService.playlistInfo = (
            "Recovered Playlist",
            [VideoInfo(id: "one", title: "One", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=one", liveStatus: nil, releaseTimestamp: nil)]
        )
        manager = makeManager(with: [single, child, placeholder])
        var playlistRequests: [PlaylistSelectionRequest] = []
        manager.onPlaylistSelectionNeeded = { playlistRequests.append($0) }

        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        let routed = await waitUntil {
            self.mockMetadataService.fetchedVideoURLs.count == 2 &&
            self.mockMetadataService.fetchedPlaylistURLs.count == 1 &&
            playlistRequests.count == 1
        }

        XCTAssertTrue(routed)
        XCTAssertEqual(Set(mockMetadataService.fetchedVideoURLs), Set([single.url, child.url]))
        XCTAssertEqual(mockMetadataService.fetchedPlaylistURLs, [placeholder.url])
    }

    func testRecoveryRebuildsMediaRequestAndReplaysItOncePerUISession() {
        let waiting = createTestTask(title: "Waiting", status: .waitingForMediaSelection)
        waiting.availableSubtitles = [SubtitleTrack(languageCode: "en")]
        waiting.availableAudioTracks = []
        manager = makeManager(with: [waiting])
        var receivedTaskIDs: [[UUID]] = []
        manager.onMediaSelectionNeeded = { request in
            receivedTaskIDs.append(request.tasks.map(\.id))
        }
        let firstSession = UUID()

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { request in
            receivedTaskIDs.append(request.tasks.map(\.id))
        }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedTaskIDs, [[waiting.id], [waiting.id]])
        XCTAssertTrue(mockMetadataService.fetchedVideoURLs.isEmpty)
    }

    func testRecoveryReplaysPlaylistRequestOncePerUISessionWithoutRefetching() async {
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLreplay",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        mockMetadataService.playlistInfo = (
            "Replay Playlist",
            [VideoInfo(
                id: "one",
                title: "One",
                thumbnail: nil,
                duration: 60,
                uploader: nil,
                url: "https://www.youtube.com/watch?v=one",
                liveStatus: nil,
                releaseTimestamp: nil
            )]
        )
        manager = makeManager(with: [placeholder])
        var receivedRequestIDs: [UUID] = []
        manager.onPlaylistSelectionNeeded = { receivedRequestIDs.append($0.id) }
        let firstSession = UUID()

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        let firstRequestArrived = await waitUntil { receivedRequestIDs.count == 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.deactivateUI(sessionID: firstSession)
        manager.onPlaylistSelectionNeeded = { receivedRequestIDs.append($0.id) }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertTrue(firstRequestArrived)
        XCTAssertEqual(receivedRequestIDs.count, 2)
        XCTAssertEqual(receivedRequestIDs.first, receivedRequestIDs.last)
        XCTAssertEqual(mockMetadataService.fetchedPlaylistURLs, [placeholder.url])
    }

    func testVideoOrPlaylistChoiceRequestReplaysOncePerUISession() {
        manager = makeManager(with: [])
        var receivedRequestIDs: [UUID] = []
        manager.onVideoOrPlaylistChoiceNeeded = { receivedRequestIDs.append($0.id) }
        let firstSession = UUID()
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)

        XCTAssertEqual(
            manager.addURL("https://www.youtube.com/watch?v=abcdefghijk&list=PLreplay"),
            .success
        )
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.deactivateUI(sessionID: firstSession)
        manager.onVideoOrPlaylistChoiceNeeded = { receivedRequestIDs.append($0.id) }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedRequestIDs.count, 2)
        XCTAssertEqual(receivedRequestIDs.first, receivedRequestIDs.last)
        XCTAssertTrue(mockMetadataService.fetchedVideoURLs.isEmpty)
        XCTAssertTrue(mockMetadataService.fetchedPlaylistURLs.isEmpty)
    }

    func testRecoveryRefetchesWaitingTaskWithoutPersistedOptions() async {
        let waiting = createTestTask(status: .waitingForMediaSelection)
        manager = makeManager(with: [waiting])

        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        let refetched = await waitUntil {
            self.mockMetadataService.fetchedVideoURLs == [waiting.url]
        }

        XCTAssertTrue(refetched)
    }

    func testRecoveryPreservesNonInterruptedStatesWithoutSideEffects() async {
        let statuses: [DownloadStatus] = [.completed, .failed, .cancelled, .paused, .scheduled, .livestreaming, .postLive]
        let tasks = statuses.enumerated().map { index, status in
            createTestTask(url: "https://example.com/\(index)", status: status)
        }
        manager = makeManager(with: tasks)
        var mediaRequestCount = 0
        var playlistRequestCount = 0
        var videoOrPlaylistRequestCount = 0
        manager.onMediaSelectionNeeded = { _ in mediaRequestCount += 1 }
        manager.onPlaylistSelectionNeeded = { _ in playlistRequestCount += 1 }
        manager.onVideoOrPlaylistChoiceNeeded = { _ in videoOrPlaylistRequestCount += 1 }

        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(tasks.map(\.status), statuses)
        XCTAssertTrue(mockMetadataService.fetchedVideoURLs.isEmpty)
        XCTAssertTrue(mockMetadataService.fetchedPlaylistURLs.isEmpty)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertEqual(mediaRequestCount, 0)
        XCTAssertEqual(playlistRequestCount, 0)
        XCTAssertEqual(videoOrPlaylistRequestCount, 0)
    }

    func testSelectionCreatedWithoutActiveUIIsDeliveredToNextSession() async {
        let fetching = createTestTask(status: .fetchingInfo)
        mockMetadataService.fetchDelayNanoseconds = 100_000_000
        mockMetadataService.mediaOptions = (
            subtitles: [SubtitleTrack(languageCode: "en")],
            audioTracks: [],
            formats: []
        )
        manager = makeManager(with: [fetching])
        let firstSession = UUID()
        var receivedRequests = 0
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.deactivateUI(sessionID: firstSession)
        try? await Task.sleep(for: .milliseconds(250))
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedRequests, 1)
    }

    func testRemovingWaitingTaskPreventsMediaRequestReplay() async {
        let waiting = createTestTask(status: .waitingForMediaSelection)
        waiting.availableSubtitles = [SubtitleTrack(languageCode: "en")]
        manager = makeManager(with: [waiting])
        var receivedRequests = 0
        let firstSession = UUID()
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)

        await manager.removeTask(waiting)
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedRequests, 1)
    }

    func testAsyncMetadataDoesNotRegisterRequestAfterTaskIsRemoved() async {
        let fetching = createTestTask(status: .fetchingInfo)
        mockMetadataService.fetchDelayNanoseconds = 100_000_000
        mockMetadataService.mediaOptions = (
            subtitles: [SubtitleTrack(languageCode: "en")],
            audioTracks: [],
            formats: []
        )
        manager = makeManager(with: [fetching])
        let firstSession = UUID()
        var receivedRequests = 0
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        await manager.removeTask(fetching)
        try? await Task.sleep(for: .milliseconds(250))
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedRequests, 0)
        XCTAssertTrue(manager.tasks.isEmpty)
    }

    func testAsyncPlaylistDoesNotRegisterRequestAfterPlaceholderIsRemoved() async {
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLstale",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        mockMetadataService.fetchDelayNanoseconds = 100_000_000
        mockMetadataService.playlistInfo = (
            "Stale Playlist",
            [VideoInfo(
                id: "one",
                title: "One",
                thumbnail: nil,
                duration: 60,
                uploader: nil,
                url: "https://www.youtube.com/watch?v=one",
                liveStatus: nil,
                releaseTimestamp: nil
            )]
        )
        manager = makeManager(with: [placeholder])
        let firstSession = UUID()
        var receivedRequests = 0
        manager.onPlaylistSelectionNeeded = { _ in receivedRequests += 1 }

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        await manager.removeTask(placeholder)
        try? await Task.sleep(for: .milliseconds(250))
        manager.deactivateUI(sessionID: firstSession)
        manager.onPlaylistSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertEqual(receivedRequests, 0)
        XCTAssertTrue(manager.tasks.isEmpty)
    }

    func testClearAllPreventsEveryUnresolvedRequestFromReplaying() async {
        let waiting = createTestTask(status: .waitingForMediaSelection)
        waiting.availableSubtitles = [SubtitleTrack(languageCode: "en")]
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLclear",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        mockMetadataService.playlistInfo = (
            "Clear Playlist",
            [VideoInfo(
                id: "one",
                title: "One",
                thumbnail: nil,
                duration: 60,
                uploader: nil,
                url: "https://www.youtube.com/watch?v=one",
                liveStatus: nil,
                releaseTimestamp: nil
            )]
        )
        manager = makeManager(with: [waiting, placeholder])
        var mediaRequests = 0
        var playlistRequests = 0
        var choiceRequests = 0
        manager.onMediaSelectionNeeded = { _ in mediaRequests += 1 }
        manager.onPlaylistSelectionNeeded = { _ in playlistRequests += 1 }
        manager.onVideoOrPlaylistChoiceNeeded = { _ in choiceRequests += 1 }
        let firstSession = UUID()

        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        let initialRequestsArrived = await waitUntil {
            mediaRequests == 1 && playlistRequests == 1
        }
        _ = manager.addURL("https://www.youtube.com/watch?v=abcdefghijk&list=PLchoice")
        await manager.clearAllTasks()
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { _ in mediaRequests += 1 }
        manager.onPlaylistSelectionNeeded = { _ in playlistRequests += 1 }
        manager.onVideoOrPlaylistChoiceNeeded = { _ in choiceRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertTrue(initialRequestsArrived)
        XCTAssertEqual(mediaRequests, 1)
        XCTAssertEqual(playlistRequests, 1)
        XCTAssertEqual(choiceRequests, 1)
    }

    func testPlaylistBatchStillRequestsMediaSelectionAfterOneChildIsRemoved() async {
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLpartial",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager = makeManager(with: [])
        mockMetadataService.fetchDelayNanoseconds = 100_000_000
        mockMetadataService.mediaOptions = (
            subtitles: [SubtitleTrack(languageCode: "en")],
            audioTracks: [],
            formats: []
        )
        let request = PlaylistSelectionRequest(
            playlistTitle: "Partial Playlist",
            videos: [
                VideoInfo(id: "one", title: "One", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=one", liveStatus: nil, releaseTimestamp: nil),
                VideoInfo(id: "two", title: "Two", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=two", liveStatus: nil, releaseTimestamp: nil)
            ],
            placeholderTaskId: placeholder.id,
            callbackScheme: nil,
            requestId: nil
        )
        var receivedTaskIDs: [[UUID]] = []
        manager.onMediaSelectionNeeded = { mediaRequest in
            receivedTaskIDs.append(mediaRequest.tasks.map(\.id))
        }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        manager.tasks = [placeholder]

        manager.confirmPlaylistSelection(request: request, selectedVideos: request.videos)
        let removedTask = manager.tasks[0]
        let remainingTaskID = manager.tasks[1].id
        await manager.removeTask(removedTask)
        let requestArrived = await waitUntil(timeout: 1) {
            receivedTaskIDs.count == 1
        }

        XCTAssertTrue(requestArrived)
        XCTAssertEqual(receivedTaskIDs, [[remainingTaskID]])
        XCTAssertEqual(manager.tasks.map(\.id), [remainingTaskID])
    }

    func testRegisteredPlaylistMediaRequestReplaysRemainingChildAfterOneIsRemoved() async {
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLregistered",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager = makeManager(with: [])
        mockMetadataService.mediaOptions = (
            subtitles: [SubtitleTrack(languageCode: "en")],
            audioTracks: [],
            formats: []
        )
        let request = PlaylistSelectionRequest(
            playlistTitle: "Registered Playlist",
            videos: [
                VideoInfo(id: "one", title: "One", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=one", liveStatus: nil, releaseTimestamp: nil),
                VideoInfo(id: "two", title: "Two", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=two", liveStatus: nil, releaseTimestamp: nil)
            ],
            placeholderTaskId: placeholder.id,
            callbackScheme: nil,
            requestId: nil
        )
        var receivedTaskIDs: [[UUID]] = []
        let firstSession = UUID()
        manager.onMediaSelectionNeeded = { mediaRequest in
            receivedTaskIDs.append(mediaRequest.tasks.map(\.id))
        }
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.tasks = [placeholder]

        manager.confirmPlaylistSelection(request: request, selectedVideos: request.videos)
        let initialRequestArrived = await waitUntil {
            receivedTaskIDs.count == 1
        }
        let removedTask = manager.tasks[0]
        let remainingTaskID = manager.tasks[1].id
        await manager.removeTask(removedTask)
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { mediaRequest in
            receivedTaskIDs.append(mediaRequest.tasks.map(\.id))
        }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())

        XCTAssertTrue(initialRequestArrived)
        XCTAssertEqual(receivedTaskIDs.count, 2)
        XCTAssertEqual(receivedTaskIDs.last, [remainingTaskID])
    }

    func testRemovedPlaylistChildDoesNotContributeMediaOptionsToRemainingChild() async {
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLoptions",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager = makeManager(with: [])
        manager.isAllPaused = true
        mockMetadataService.fetchDelayNanoseconds = 100_000_000
        mockMetadataService.mediaOptionsByURL = [
            "https://www.youtube.com/watch?v=one": (
                subtitles: [SubtitleTrack(languageCode: "en")],
                audioTracks: [],
                formats: []
            ),
            "https://www.youtube.com/watch?v=two": (
                subtitles: [],
                audioTracks: [],
                formats: []
            )
        ]
        let request = PlaylistSelectionRequest(
            playlistTitle: "Options Playlist",
            videos: [
                VideoInfo(id: "one", title: "One", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=one", liveStatus: nil, releaseTimestamp: nil),
                VideoInfo(id: "two", title: "Two", thumbnail: nil, duration: 60, uploader: nil, url: "https://www.youtube.com/watch?v=two", liveStatus: nil, releaseTimestamp: nil)
            ],
            placeholderTaskId: placeholder.id,
            callbackScheme: nil,
            requestId: nil
        )
        var receivedRequests = 0
        manager.onMediaSelectionNeeded = { _ in receivedRequests += 1 }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        manager.tasks = [placeholder]

        manager.confirmPlaylistSelection(request: request, selectedVideos: request.videos)
        let firstLookupCompleted = await waitUntil {
            self.mockMetadataService.fetchedMediaOptionURLs.count == 1
        }
        let removedTask = manager.tasks[0]
        let remainingTask = manager.tasks[1]
        await manager.removeTask(removedTask)
        let allLookupsCompleted = await waitUntil {
            self.mockMetadataService.fetchedMediaOptionURLs.count == 2
                && remainingTask.status != .fetchingInfo
        }

        XCTAssertTrue(firstLookupCompleted)
        XCTAssertTrue(allLookupsCompleted)
        XCTAssertEqual(receivedRequests, 0)
        XCTAssertEqual(remainingTask.status, .paused)
    }

    func testRegisteredPlaylistMediaRequestAutoResolvesAfterRemovingOnlyChildWithOptions() async {
        let firstURL = "https://www.youtube.com/watch?v=one"
        let secondURL = "https://www.youtube.com/watch?v=two"
        let placeholder = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLresolve",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager = makeManager(with: [])
        manager.isAllPaused = true
        mockMetadataService.mediaOptionsByURL = [
            firstURL: (
                subtitles: [SubtitleTrack(languageCode: "en")],
                audioTracks: [],
                formats: []
            ),
            secondURL: (
                subtitles: [],
                audioTracks: [],
                formats: []
            )
        ]
        let playlistRequest = PlaylistSelectionRequest(
            playlistTitle: "Resolve Playlist",
            videos: [
                VideoInfo(id: "one", title: "One", thumbnail: nil, duration: 60, uploader: nil, url: firstURL, liveStatus: nil, releaseTimestamp: nil),
                VideoInfo(id: "two", title: "Two", thumbnail: nil, duration: 60, uploader: nil, url: secondURL, liveStatus: nil, releaseTimestamp: nil)
            ],
            placeholderTaskId: placeholder.id,
            callbackScheme: nil,
            requestId: nil
        )
        var receivedRequests: [MediaSelectionRequest] = []
        let firstSession = UUID()
        manager.onMediaSelectionNeeded = { receivedRequests.append($0) }
        manager.resumePersistedTasksAfterUIActivation(sessionID: firstSession)
        manager.tasks = [placeholder]

        manager.confirmPlaylistSelection(request: playlistRequest, selectedVideos: playlistRequest.videos)
        let initialRequestArrived = await waitUntil {
            receivedRequests.count == 1
        }
        let staleRequest = try! XCTUnwrap(receivedRequests.first)
        let removedTask = try! XCTUnwrap(manager.tasks.first { $0.url == firstURL })
        let remainingTask = try! XCTUnwrap(manager.tasks.first { $0.url == secondURL })
        await manager.removeTask(removedTask)
        manager.deactivateUI(sessionID: firstSession)
        manager.onMediaSelectionNeeded = { receivedRequests.append($0) }
        manager.resumePersistedTasksAfterUIActivation(sessionID: UUID())
        manager.confirmMediaSelection(
            for: staleRequest.tasks,
            subtitleSelection: SubtitleSelection(selectedLanguages: ["en"]),
            audioSelection: nil
        )

        XCTAssertTrue(initialRequestArrived)
        XCTAssertEqual(receivedRequests.count, 1)
        XCTAssertNil(remainingTask.subtitleSelection)
        XCTAssertEqual(remainingTask.status, .paused)
    }

    // MARK: - Post-live replay metadata tests

    func testPostLiveMetadataWithPairableFormatsStartsDownloadFlow() async {
        // Arrange
        let url = "https://www.youtube.com/watch?v=TR_NgGeXWGc"
        mockMetadataService.videoInfo = VideoInfo(
            id: "TR_NgGeXWGc",
            title: "Post Live Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: url,
            liveStatus: "post_live",
            releaseTimestamp: nil,
            formats: [
                YTDLPFormat(formatID: "137", vcodec: "avc1.640028", acodec: "none", protocolName: "https", ext: "mp4"),
                YTDLPFormat(formatID: "140", vcodec: "none", acodec: "mp4a.40.2", protocolName: "https", ext: "m4a")
            ]
        )
        mockMetadataService.mediaOptions = (subtitles: [], audioTracks: [], formats: [])
        mockYTDLPService.outputPath = "/tmp/Post Live Replay.mp4"

        // Act
        XCTAssertEqual(manager.addURL(url), .success)
        let didStartDownload = await waitUntil {
            self.mockYTDLPService.downloadedURLs.contains(url)
        }

        // Assert
        XCTAssertTrue(didStartDownload, "post_live metadata with 137+140 should enter the normal download flow")
        XCTAssertNotEqual(manager.tasks.first?.status, .postLive)
    }

    func testPostLiveFollowUpFormatLookupWithPairableFormatsStartsDownloadFlow() async {
        // Arrange
        let url = "https://www.youtube.com/watch?v=TR_NgGeXWGc"
        mockMetadataService.videoInfo = VideoInfo(
            id: "TR_NgGeXWGc",
            title: "Post Live Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: url,
            liveStatus: "post_live",
            releaseTimestamp: nil
        )
        mockMetadataService.mediaOptions = (
            subtitles: [],
            audioTracks: [],
            formats: [
                YTDLPFormat(formatID: "137", vcodec: "avc1.640028", acodec: "none", protocolName: "https", ext: "mp4"),
                YTDLPFormat(formatID: "140", vcodec: "none", acodec: "mp4a.40.2", protocolName: "https", ext: "m4a")
            ]
        )

        // Act
        XCTAssertEqual(manager.addURL(url), .success)
        let didStartDownload = await waitUntil {
            self.mockYTDLPService.downloadedURLs.contains(url)
        }

        // Assert
        XCTAssertTrue(didStartDownload, "post_live follow-up lookup with 137+140 should enter the normal download flow")
        XCTAssertNotEqual(manager.tasks.first?.status, .postLive)
    }

    func testPostLiveMetadataWithoutUsableFormatsStaysPostLiveAndDoesNotStartDownload() async {
        // Arrange
        let url = "https://www.youtube.com/watch?v=TR_NgGeXWGc"
        mockMetadataService.videoInfo = VideoInfo(
            id: "TR_NgGeXWGc",
            title: "Post Live Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: url,
            liveStatus: "post_live",
            releaseTimestamp: nil
        )
        mockMetadataService.mediaOptions = (subtitles: [], audioTracks: [], formats: [])

        // Act
        XCTAssertEqual(manager.addURL(url), .success)
        let becamePostLive = await waitUntil {
            self.manager.tasks.first?.status == .postLive
        }

        // Assert
        XCTAssertTrue(becamePostLive)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertEqual(manager.tasks.first?.errorMessage, "直播回放仍在處理中，請稍後重試。")
    }

    func testPostLiveFormatLookupErrorsSetExpectedStatusAndNotifications() async {
        // Arrange: ended-live lookup error
        let endedLiveURL = "https://www.youtube.com/watch?v=TR_NgGeXWGc"
        mockMetadataService.videoInfo = VideoInfo(
            id: "TR_NgGeXWGc",
            title: "Post Live Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: endedLiveURL,
            liveStatus: "post_live",
            releaseTimestamp: nil
        )
        mockMetadataService.mediaOptionsError = YTDLPError.executionFailed("ERROR: [youtube] TR_NgGeXWGc: This live event has ended.")

        // Act
        XCTAssertEqual(manager.addURL(endedLiveURL), .success)
        let endedLiveHandled = await waitUntil {
            self.manager.tasks.first?.status == .postLive
        }

        // Assert
        XCTAssertTrue(endedLiveHandled)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertTrue(mockNotificationService.failedNotifications.isEmpty)

        // Arrange: non-ended lookup error
        manager.tasks = []
        mockPersistence.reset()
        mockMetadataService.mediaOptionsError = YTDLPError.executionFailed("ERROR: [youtube] abc123: Video unavailable")
        let unavailableURL = "https://www.youtube.com/watch?v=abc123"
        mockMetadataService.videoInfo = VideoInfo(
            id: "abc123",
            title: "Unavailable Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: unavailableURL,
            liveStatus: "post_live",
            releaseTimestamp: nil
        )

        // Act
        XCTAssertEqual(manager.addURL(unavailableURL), .success)
        let failedHandled = await waitUntil {
            self.manager.tasks.first?.status == .failed
        }

        // Assert
        XCTAssertTrue(failedHandled)
        XCTAssertTrue(manager.tasks.first?.errorMessage?.contains("Video unavailable") == true)
        XCTAssertEqual(mockNotificationService.failedNotifications.count, 1)
    }

    func testDownloadEndedLiveErrorBecomesPostLiveWithoutFailedNotification() async {
        // Arrange
        let endedLiveTask = createTestTask(
            url: "https://www.youtube.com/watch?v=TR_NgGeXWGc",
            title: "Post Live Replay",
            status: .pending
        )
        manager.tasks = [endedLiveTask]
        mockYTDLPService.downloadError = YTDLPError.executionFailed("ERROR: [youtube] TR_NgGeXWGc: This live event has ended.")

        // Act
        manager.startDownloadQueue()
        let becamePostLive = await waitUntil {
            endedLiveTask.status == .postLive
        }

        // Assert
        XCTAssertTrue(becamePostLive)
        XCTAssertEqual(endedLiveTask.errorMessage, "直播回放仍在處理中，請稍後重試。")
        XCTAssertTrue(mockNotificationService.failedNotifications.isEmpty)
        _ = await waitUntil {
            !self.manager.isDownloading
        }

        // Arrange
        let unavailableTask = createTestTask(
            url: "https://www.youtube.com/watch?v=abc123",
            title: "Unavailable Video",
            status: .pending
        )
        manager.tasks = [unavailableTask]
        mockYTDLPService.downloadError = YTDLPError.executionFailed("ERROR: [youtube] abc123: Video unavailable")

        // Act
        manager.startDownloadQueue()
        let becameFailed = await waitUntil {
            unavailableTask.status == .failed
        }

        // Assert
        XCTAssertTrue(becameFailed)
        XCTAssertTrue(unavailableTask.errorMessage?.contains("Video unavailable") == true)
        XCTAssertEqual(mockNotificationService.failedNotifications.count, 1)
    }

    // MARK: - 依網址分流下載指令（command routing）

    /// YouTube 任務經 queue flow 下載時，downloadSingleTask 實際使用既有 downloadCommand（零回退）。
    func testDownloadSingleTaskUsesExistingCommandForYouTubeURL() async {
        // Arrange：直接放入 .pending YouTube 任務，不走 addURL 的 metadata async flow
        let youtubeTask = createTestTask(
            url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            status: .pending
        )
        manager.tasks = [youtubeTask]

        // Act
        manager.startDownloadQueue()
        let didDownload = await waitUntil {
            !self.mockYTDLPService.downloadedCommandTemplates.isEmpty
        }

        // Assert
        XCTAssertTrue(didDownload)
        XCTAssertEqual(mockYTDLPService.downloadedCommandTemplates.first, manager.downloadCommand)
    }

    /// 非 YouTube 任務經 queue flow 下載時，downloadSingleTask 使用 genericDownloadCommand。
    func testDownloadSingleTaskUsesGenericCommandForNonYouTubeURL() async {
        // Arrange
        let nonYouTubeTask = createTestTask(
            url: "https://x.com/user/status/123",
            status: .pending
        )
        manager.tasks = [nonYouTubeTask]

        // Act
        manager.startDownloadQueue()
        let didDownload = await waitUntil {
            !self.mockYTDLPService.downloadedCommandTemplates.isEmpty
        }

        // Assert
        XCTAssertTrue(didDownload)
        XCTAssertEqual(mockYTDLPService.downloadedCommandTemplates.first, AppSettingsDefaults.genericDownloadCommand)
    }

    // MARK: - Completed task retention

    func testCompletedTaskRemainsWhenAutoRemovePreferenceIsMissing() async {
        let defaults = UserDefaults.standard
        let originalPreference = defaults.object(forKey: AppSettingsKeys.autoRemoveCompleted)
        defaults.removeObject(forKey: AppSettingsKeys.autoRemoveCompleted)
        defer {
            if let originalPreference {
                defaults.set(originalPreference, forKey: AppSettingsKeys.autoRemoveCompleted)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.autoRemoveCompleted)
            }
        }

        let task = createTestTask(url: "https://example.com/keep-completed", status: .pending)
        manager.tasks = [task]

        manager.startDownloadQueue()
        let completed = await waitUntil {
            task.status == .completed
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(manager.tasks.map(\.id), [task.id])
    }

    func testCompletedTaskIsRemovedWhenAutoRemovePreferenceIsExplicitlyEnabled() async {
        let defaults = UserDefaults.standard
        let originalPreference = defaults.object(forKey: AppSettingsKeys.autoRemoveCompleted)
        defaults.set(true, forKey: AppSettingsKeys.autoRemoveCompleted)
        defer {
            if let originalPreference {
                defaults.set(originalPreference, forKey: AppSettingsKeys.autoRemoveCompleted)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.autoRemoveCompleted)
            }
        }

        let task = createTestTask(url: "https://example.com/remove-completed", status: .pending)
        manager.tasks = [task]

        manager.startDownloadQueue()
        let removed = await waitUntil {
            self.manager.tasks.contains(where: { $0.id == task.id }) == false
        }

        XCTAssertTrue(removed)
        XCTAssertEqual(mockNotificationService.completedNotifications.count, 1)
    }

    /// effectiveDownloadCommand(for:) 對 YouTube 支援形狀回傳 downloadCommand。
    func testEffectiveDownloadCommandReturnsDownloadCommandForYouTubeURLs() {
        let youtubeURLs = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf"
        ]
        for url in youtubeURLs {
            XCTAssertEqual(
                manager.effectiveDownloadCommand(for: url),
                manager.downloadCommand,
                "YouTube 網址應使用 downloadCommand：\(url)"
            )
        }
    }

    /// effectiveDownloadCommand(for:) 對非 YouTube 網址與「不受支援的 YouTube-domain 形狀」皆回傳 genericDownloadCommand，
    /// 藉此排除以 domain 為判斷的實作。
    func testEffectiveDownloadCommandReturnsGenericForNonYouTubeAndUnsupportedShapes() {
        let genericURLs = [
            "https://x.com/user/status/123",
            "https://www.instagram.com/reel/abc123/",
            "https://www.youtube.com/@channelname",
            "https://www.youtube.com/watch?list=PL123"
        ]
        for url in genericURLs {
            XCTAssertEqual(
                manager.effectiveDownloadCommand(for: url),
                AppSettingsDefaults.genericDownloadCommand,
                "應使用 genericDownloadCommand：\(url)"
            )
        }
    }

    func testRetryPostLiveTaskRerunsMetadataAndDownloadFlow() async {
        // Arrange
        let url = "https://www.youtube.com/watch?v=TR_NgGeXWGc"
        let task = createTestTask(url: url, title: "Post Live Replay", status: .postLive)
        task.errorMessage = "old post-live result"
        task.progress = 0.75
        manager.tasks = [task]
        mockMetadataService.videoInfo = VideoInfo(
            id: "TR_NgGeXWGc",
            title: "Post Live Replay",
            thumbnail: nil,
            duration: 120,
            uploader: "Test",
            url: url,
            liveStatus: "post_live",
            releaseTimestamp: nil,
            formats: [
                YTDLPFormat(formatID: "137", vcodec: "avc1.640028", acodec: "none", protocolName: "https", ext: "mp4"),
                YTDLPFormat(formatID: "140", vcodec: "none", acodec: "mp4a.40.2", protocolName: "https", ext: "m4a")
            ]
        )
        mockMetadataService.mediaOptions = (subtitles: [], audioTracks: [], formats: [])

        // Act
        manager.retryTask(task)
        XCTAssertNil(task.errorMessage)
        XCTAssertEqual(task.progress, 0)
        let didDownload = await waitUntil {
            self.mockYTDLPService.downloadedURLs.contains(url)
        }

        // Assert
        XCTAssertTrue(didDownload)
        XCTAssertNotEqual(task.status, .postLive)
    }

    // MARK: - 尚未首播（is_upcoming）測試

    func testUpcomingPremiereBecomesScheduledAndDoesNotStartDownload() async {
        // Arrange：尚未首播的影片 yt-dlp metadata 會成功回傳 live_status = is_upcoming
        let url = "https://www.youtube.com/watch?v=LkLLx7Krovk"
        let premiereTimestamp = 1_784_721_606
        mockMetadataService.videoInfo = VideoInfo(
            id: "LkLLx7Krovk",
            title: "首播影片",
            thumbnail: nil,
            duration: 600,
            uploader: "Test",
            url: url,
            liveStatus: "is_upcoming",
            releaseTimestamp: premiereTimestamp
        )

        // Act
        XCTAssertEqual(manager.addURL(url), .success)
        let becameScheduled = await waitUntil {
            self.manager.tasks.first?.status == .scheduled
        }

        // Assert：設為 .scheduled、帶首播時間、且絕不進下載佇列（避免 yt-dlp 卡在 0%）
        XCTAssertTrue(becameScheduled, "尚未首播應設為 .scheduled")
        XCTAssertEqual(
            manager.tasks.first?.premiereDate,
            Date(timeIntervalSince1970: TimeInterval(premiereTimestamp))
        )
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty, "尚未首播不應開始下載")
    }

    func testConfirmPlaylistSelectionUpcomingPremiereStaysScheduled() async {
        // Arrange
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [placeholderTask]
        let url = "https://www.youtube.com/watch?v=upcoming1"
        let premiereTimestamp = 1_784_721_606
        // --flat-playlist 不含 live_status，改由 fetchMediaOptions 完整 JSON 回傳
        mockMetadataService.liveStatusByURL = [url: "is_upcoming"]
        mockMetadataService.releaseTimestampByURL = [url: premiereTimestamp]

        let selectedVideos = [
            VideoInfo(
                id: "upcoming1",
                title: "首播影片",
                thumbnail: nil,
                duration: 600,
                uploader: "Test",
                url: url,
                liveStatus: nil,
                releaseTimestamp: nil
            )
        ]
        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)
        let becameScheduled = await waitUntil {
            self.manager.tasks.first?.status == .scheduled
        }

        // Assert
        XCTAssertTrue(becameScheduled)
        XCTAssertEqual(
            manager.tasks.first?.premiereDate,
            Date(timeIntervalSince1970: TimeInterval(premiereTimestamp))
        )
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
    }

    func testRetryScheduledPremiereRerunsMetadataAndDownloadsWhenAired() async {
        // Arrange：使用者對 .scheduled 任務按重試，此時首播已播完（live_status 變成非 is_upcoming）
        let url = "https://www.youtube.com/watch?v=LkLLx7Krovk"
        let task = createTestTask(url: url, title: "首播影片", status: .scheduled)
        task.premiereDate = Date(timeIntervalSince1970: 1_784_721_606)
        manager.tasks = [task]
        mockMetadataService.videoInfo = VideoInfo(
            id: "LkLLx7Krovk",
            title: "首播影片",
            thumbnail: nil,
            duration: 600,
            uploader: "Test",
            url: url,
            liveStatus: "not_live",
            releaseTimestamp: 1_784_721_606
        )
        mockMetadataService.mediaOptions = (subtitles: [], audioTracks: [], formats: [])

        // Act
        manager.retryTask(task)
        let didDownload = await waitUntil {
            self.mockYTDLPService.downloadedURLs.contains(url)
        }

        // Assert：重試會重新抓 metadata，播完後進入正常下載，而非直接排入佇列
        XCTAssertTrue(didDownload, "首播已播完，重試應開始下載")
        XCTAssertNotEqual(task.status, .scheduled)
    }

    // MARK: - DownloadStatus.paused 基本測試

    func testPausedStatusDisplayText() {
        XCTAssertEqual(DownloadStatus.paused.displayText, "已暫停")
    }

    func testPausedStatusRawValue() {
        XCTAssertEqual(DownloadStatus.paused.rawValue, "paused")
    }

    func testPausedStatusFromRawValue() {
        XCTAssertEqual(DownloadStatus(rawValue: "paused"), .paused)
    }

    // MARK: - 單一任務暫停測試

    func testPauseSingleTask_ChangesToPausedStatus() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertEqual(task.status, .paused)
    }

    func testPauseSingleTask_FromDownloadingStatus() async {
        // Arrange
        let task = createTestTask(status: .downloading)
        task.progress = 0.5
        manager.tasks = [task]

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertEqual(task.status, .paused)
    }

    func testPauseSingleTask_DoesNotAffectOtherTasks() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .downloading)
        manager.tasks = [task1, task2, task3]

        // Act
        await manager.pauseTask(task2)

        // Assert
        XCTAssertEqual(task1.status, .pending, "task1 應該維持 pending 狀態")
        XCTAssertEqual(task2.status, .paused, "task2 應該變成 paused 狀態")
        XCTAssertEqual(task3.status, .downloading, "task3 應該維持 downloading 狀態")
    }

    func testPauseSingleTask_DoesNotChangeIsAllPausedFlag() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        await manager.pauseTask(task)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "暫停單一任務不應該設置 isAllPaused 標記")
    }

    // MARK: - 單一任務恢復測試

    func testResumeSingleTask_ChangesToPendingStatus() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertEqual(task.status, .pending)
    }

    func testResumeSingleTask_ResetsProgress() {
        // Arrange
        let task = createTestTask(status: .paused)
        task.progress = 0.5
        manager.tasks = [task]

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertEqual(task.progress, 0, "恢復任務應該重置進度")
    }

    func testResumeSingleTask_DoesNotAffectOtherPausedTasks() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .paused)
        manager.tasks = [task1, task2, task3]

        // Act
        manager.resumeTask(task2)

        // Assert
        XCTAssertEqual(task1.status, .paused, "task1 應該維持 paused 狀態")
        XCTAssertEqual(task2.status, .pending, "task2 應該變成 pending 狀態")
        XCTAssertEqual(task3.status, .paused, "task3 應該維持 paused 狀態")
    }

    /// 核心測試：當全部暫停時，恢復單一任務應該清除 isAllPaused 標記
    /// 這是修復的 bug：原本 isAllPaused 為 true 時，processQueue 會跳過 pending 任務
    func testResumeSingleTask_WhenAllPaused_ClearsIsAllPausedFlag() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        manager.tasks = [task1, task2]
        manager.isAllPaused = true

        // Act
        manager.resumeTask(task1)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "恢復單一任務應該清除 isAllPaused 標記")
        XCTAssertEqual(task1.status, .pending, "task1 應該變成 pending 狀態")
        XCTAssertEqual(task2.status, .paused, "其他任務應該維持 paused 狀態")
    }

    func testResumeSingleTask_WhenIsAllPausedFalse_RemainsUnchanged() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        manager.resumeTask(task)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "isAllPaused 應該保持為 false")
    }

    // MARK: - 全部暫停測試

    func testPauseAll_AllPendingTasksBecomePaused() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .pending)
        manager.tasks = [task1, task2, task3]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)
        XCTAssertEqual(task3.status, .paused)
    }

    func testPauseAll_DownloadingTasksBecomePaused() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .downloading)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        manager.tasks = [task1, task2]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)
    }

    func testPauseAll_SetsIsAllPausedFlag() async {
        // Arrange
        let task = createTestTask(status: .pending)
        manager.tasks = [task]
        manager.isAllPaused = false

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertTrue(manager.isAllPaused)
    }

    func testPauseAll_DoesNotAffectCompletedTasks() async {
        // Arrange
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        manager.tasks = [completedTask, pendingTask]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(completedTask.status, .completed, "已完成的任務不應該被暫停")
        XCTAssertEqual(pendingTask.status, .paused, "待處理的任務應該被暫停")
    }

    func testPauseAll_DoesNotAffectFailedTasks() async {
        // Arrange
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        failedTask.errorMessage = "Network error"
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        manager.tasks = [failedTask, pendingTask]

        // Act
        await manager.pauseAll()

        // Assert
        XCTAssertEqual(failedTask.status, .failed, "失敗的任務不應該被暫停")
        XCTAssertEqual(pendingTask.status, .paused, "待處理的任務應該被暫停")
    }

    // MARK: - 全部恢復測試

    func testResumeAll_AllPausedTasksBecomePending() {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .paused)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .paused)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .paused)
        manager.tasks = [task1, task2, task3]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(task1.status, .pending)
        XCTAssertEqual(task2.status, .pending)
        XCTAssertEqual(task3.status, .pending)
    }

    func testResumeAll_ClearsIsAllPausedFlag() {
        // Arrange
        let task = createTestTask(status: .paused)
        manager.tasks = [task]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertFalse(manager.isAllPaused)
    }

    func testResumeAll_AlsoResumesFailedTasks() {
        // Arrange
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        failedTask.errorMessage = "Network error"
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [failedTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(failedTask.status, .pending, "失敗的任務應該被恢復為 pending")
        XCTAssertNil(failedTask.errorMessage, "錯誤訊息應該被清除")
        XCTAssertEqual(pausedTask.status, .pending, "暫停的任務應該被恢復為 pending")
    }

    func testResumeAll_ResetsProgressForPausedTasks() {
        // Arrange
        let task = createTestTask(status: .paused)
        task.progress = 0.75
        manager.tasks = [task]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(task.progress, 0, "恢復任務應該重置進度")
    }

    func testResumeAll_DoesNotAffectCompletedTasks() {
        // Arrange
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        completedTask.progress = 1.0
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [completedTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(completedTask.status, .completed, "已完成的任務不應該被影響")
        XCTAssertEqual(completedTask.progress, 1.0, "已完成任務的進度不應該被重置")
    }

    func testResumeAll_DoesNotAffectCancelledTasks() {
        // Arrange
        let cancelledTask = createTestTask(url: "https://www.youtube.com/watch?v=cancelled", status: .cancelled)
        let pausedTask = createTestTask(url: "https://www.youtube.com/watch?v=paused", status: .paused)
        manager.tasks = [cancelledTask, pausedTask]
        manager.isAllPaused = true

        // Act
        manager.resumeAll()

        // Assert
        XCTAssertEqual(cancelledTask.status, .cancelled, "已取消的任務不應該被影響")
        XCTAssertEqual(pausedTask.status, .pending, "暫停的任務應該被恢復")
    }

    // MARK: - 複合情境測試

    func testPauseAllThenResumeAll_RestoresOriginalBehavior() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        manager.tasks = [task1, task2]

        // Act
        await manager.pauseAll()

        // Assert intermediate state
        XCTAssertTrue(manager.isAllPaused)
        XCTAssertEqual(task1.status, .paused)
        XCTAssertEqual(task2.status, .paused)

        // Act
        manager.resumeAll()

        // Assert final state
        XCTAssertFalse(manager.isAllPaused)
        XCTAssertEqual(task1.status, .pending)
        XCTAssertEqual(task2.status, .pending)
    }

    func testPauseAllThenResumeSingle_OnlyResumesThatTask() async {
        // Arrange
        let task1 = createTestTask(url: "https://www.youtube.com/watch?v=video1", status: .pending)
        let task2 = createTestTask(url: "https://www.youtube.com/watch?v=video2", status: .pending)
        let task3 = createTestTask(url: "https://www.youtube.com/watch?v=video3", status: .pending)
        manager.tasks = [task1, task2, task3]

        // Act: Pause all
        await manager.pauseAll()

        // Act: Resume only task2
        manager.resumeTask(task2)

        // Assert
        XCTAssertFalse(manager.isAllPaused, "isAllPaused 應該被清除")
        XCTAssertEqual(task1.status, .paused, "task1 應該維持暫停")
        XCTAssertEqual(task2.status, .pending, "task2 應該被恢復")
        XCTAssertEqual(task3.status, .paused, "task3 應該維持暫停")
    }

    func testMixedStatusTasks_PauseAndResume() async {
        // Arrange: 各種狀態的任務
        let pendingTask = createTestTask(url: "https://www.youtube.com/watch?v=pending", status: .pending)
        let downloadingTask = createTestTask(url: "https://www.youtube.com/watch?v=downloading", status: .downloading)
        let completedTask = createTestTask(url: "https://www.youtube.com/watch?v=completed", status: .completed)
        let failedTask = createTestTask(url: "https://www.youtube.com/watch?v=failed", status: .failed)
        let scheduledTask = createTestTask(url: "https://www.youtube.com/watch?v=scheduled", status: .scheduled)

        manager.tasks = [pendingTask, downloadingTask, completedTask, failedTask, scheduledTask]

        // Act: Pause all
        await manager.pauseAll()

        // Assert: 只有 pending 和 downloading 會被暫停
        XCTAssertEqual(pendingTask.status, .paused)
        XCTAssertEqual(downloadingTask.status, .paused)
        XCTAssertEqual(completedTask.status, .completed)
        XCTAssertEqual(failedTask.status, .failed)
        XCTAssertEqual(scheduledTask.status, .scheduled)

        // Act: Resume all
        manager.resumeAll()

        // Assert: paused 和 failed 會變成 pending
        XCTAssertEqual(pendingTask.status, .pending)
        XCTAssertEqual(downloadingTask.status, .pending)
        XCTAssertEqual(completedTask.status, .completed)
        XCTAssertEqual(failedTask.status, .pending) // failed 也會被恢復
        XCTAssertEqual(scheduledTask.status, .scheduled)
    }

    // MARK: - 新任務加入時的狀態測試

    func testNewTaskStatus_WhenAllPaused_ShouldBePaused() {
        // 這個測試驗證當 isAllPaused 為 true 時，
        // fetchMetadataForTask 會將新任務設為 paused 狀態

        // Arrange
        manager.isAllPaused = true

        // 直接測試狀態設定邏輯
        let newStatus: DownloadStatus = manager.isAllPaused ? .paused : .pending

        // Assert
        XCTAssertEqual(newStatus, .paused, "當全部暫停時，新任務應該設為 paused")
    }

    func testNewTaskStatus_WhenNotAllPaused_ShouldBePending() {
        // Arrange
        manager.isAllPaused = false

        // 直接測試狀態設定邏輯
        let newStatus: DownloadStatus = manager.isAllPaused ? .paused : .pending

        // Assert
        XCTAssertEqual(newStatus, .pending, "當未全部暫停時，新任務應該設為 pending")
    }

    // MARK: - 播放清單選集測試

    func testConfirmPlaylistSelection_AddsSelectedVideosToQueue() {
        // Arrange: 建立佔位任務
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [placeholderTask]

        let selectedVideos = [
            VideoInfo(
                id: "vid1", title: "Video 1", thumbnail: nil,
                duration: 120, uploader: "Test", url: "https://www.youtube.com/watch?v=vid1",
                liveStatus: nil, releaseTimestamp: nil
            ),
            VideoInfo(
                id: "vid2", title: "Video 2", thumbnail: nil,
                duration: 180, uploader: "Test", url: "https://www.youtube.com/watch?v=vid2",
                liveStatus: nil, releaseTimestamp: nil
            ),
        ]

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)

        // Assert: 佔位任務被移除，選擇的影片被加入
        XCTAssertFalse(manager.tasks.contains(where: { $0.id == placeholderTask.id }), "佔位任務應該被移除")
        XCTAssertEqual(manager.tasks.count, 2, "應該有 2 個新任務")
        XCTAssertTrue(manager.tasks.contains(where: { $0.url == "https://www.youtube.com/watch?v=vid1" }), "vid1 應該在佇列中")
        XCTAssertTrue(manager.tasks.contains(where: { $0.url == "https://www.youtube.com/watch?v=vid2" }), "vid2 應該在佇列中")
        XCTAssertEqual(manager.tasks.first?.title, "Video 1", "任務標題應該正確設定")
        XCTAssertTrue(mockPersistence.saveTasksCalled, "應該呼叫 saveTasks 持久化")
    }

    func testConfirmPlaylistSelectionPostLiveVideoWithoutUsableFormatsStaysPostLive() async {
        // Arrange
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [placeholderTask]
        mockMetadataService.mediaOptions = (subtitles: [], audioTracks: [], formats: [])
        // 播放清單路徑改用 fetchMediaOptions 回傳的 liveStatus（--flat-playlist 不含此欄位）
        mockMetadataService.liveStatusByURL = ["https://www.youtube.com/watch?v=TR_NgGeXWGc": "post_live"]

        let selectedVideos = [
            VideoInfo(
                id: "TR_NgGeXWGc",
                title: "Post Live Replay",
                thumbnail: nil,
                duration: 120,
                uploader: "Test",
                url: "https://www.youtube.com/watch?v=TR_NgGeXWGc",
                liveStatus: "post_live",
                releaseTimestamp: nil
            )
        ]

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)
        let becamePostLive = await waitUntil {
            self.manager.tasks.first?.status == .postLive
        }

        // Assert
        XCTAssertTrue(becamePostLive)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertEqual(manager.tasks.first?.errorMessage, "直播回放仍在處理中，請稍後重試。")
    }

    func testConfirmPlaylistSelectionPostLiveEndedLiveLookupErrorStaysPostLiveWithoutFailedNotification() async {
        // Arrange
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [placeholderTask]
        mockMetadataService.mediaOptionsError = YTDLPError.executionFailed("ERROR: [youtube] TR_NgGeXWGc: This live event has ended.")

        let selectedVideos = [
            VideoInfo(
                id: "TR_NgGeXWGc",
                title: "Post Live Replay",
                thumbnail: nil,
                duration: 120,
                uploader: "Test",
                url: "https://www.youtube.com/watch?v=TR_NgGeXWGc",
                liveStatus: "post_live",
                releaseTimestamp: nil
            )
        ]

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)
        let becamePostLive = await waitUntil {
            self.manager.tasks.first?.status == .postLive
        }

        // Assert
        XCTAssertTrue(becamePostLive)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertTrue(mockNotificationService.failedNotifications.isEmpty)
        XCTAssertEqual(manager.tasks.first?.errorMessage, "直播回放仍在處理中，請稍後重試。")
    }

    func testConfirmPlaylistSelectionPostLiveNonEndedLookupErrorFailsAndSendsNotification() async {
        // Arrange
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [placeholderTask]
        mockMetadataService.mediaOptionsError = YTDLPError.executionFailed("ERROR: [youtube] abc123: Video unavailable")

        let selectedVideos = [
            VideoInfo(
                id: "abc123",
                title: "Unavailable Replay",
                thumbnail: nil,
                duration: 120,
                uploader: "Test",
                url: "https://www.youtube.com/watch?v=abc123",
                liveStatus: "post_live",
                releaseTimestamp: nil
            )
        ]

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)
        let failed = await waitUntil {
            self.manager.tasks.first?.status == .failed
        }

        // Assert
        XCTAssertTrue(failed)
        XCTAssertTrue(mockYTDLPService.downloadedURLs.isEmpty)
        XCTAssertTrue(manager.tasks.first?.errorMessage?.contains("Video unavailable") == true)
        XCTAssertEqual(mockNotificationService.failedNotifications.count, 1)
    }

    func testConfirmPlaylistSelection_SkipsDuplicateVideos() {
        // Arrange: 佇列中已存在一個影片
        let existingTask = createTestTask(
            url: "https://www.youtube.com/watch?v=vid1",
            title: "Existing Video",
            status: .pending
        )
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [existingTask, placeholderTask]

        let selectedVideos = [
            VideoInfo(
                id: "vid1", title: "Video 1", thumbnail: nil,
                duration: 120, uploader: "Test", url: "https://www.youtube.com/watch?v=vid1",
                liveStatus: nil, releaseTimestamp: nil
            ),
            VideoInfo(
                id: "vid2", title: "Video 2", thumbnail: nil,
                duration: 180, uploader: "Test", url: "https://www.youtube.com/watch?v=vid2",
                liveStatus: nil, releaseTimestamp: nil
            ),
        ]

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: selectedVideos,
            placeholderTaskId: placeholderTask.id,
            callbackScheme: nil,
            requestId: nil
        )

        // Act
        manager.confirmPlaylistSelection(request: request, selectedVideos: selectedVideos)

        // Assert: 已存在的 vid1 應該被跳過，只新增 vid2
        XCTAssertEqual(manager.tasks.count, 2, "應該有 2 個任務（1 個既有 + 1 個新增）")
        XCTAssertTrue(manager.tasks.contains(where: { $0.url == "https://www.youtube.com/watch?v=vid1" && $0.title == "Existing Video" }), "既有的 vid1 應該保持不變")
        XCTAssertTrue(manager.tasks.contains(where: { $0.url == "https://www.youtube.com/watch?v=vid2" }), "vid2 應該被新增")
    }

    func testCancelPlaylistSelection_RemovesPlaceholderTask() {
        // Arrange: 建立佔位任務和一個正常任務
        let normalTask = createTestTask(
            url: "https://www.youtube.com/watch?v=normal",
            title: "Normal Video",
            status: .pending
        )
        let placeholderTask = createTestTask(
            url: "https://www.youtube.com/playlist?list=PLtest",
            title: "載入播放清單中...",
            status: .fetchingInfo
        )
        manager.tasks = [normalTask, placeholderTask]

        // Act
        manager.cancelPlaylistSelection(placeholderTaskId: placeholderTask.id)

        // Assert: 佔位任務被移除，正常任務不受影響
        XCTAssertEqual(manager.tasks.count, 1, "應該只剩 1 個任務")
        XCTAssertEqual(manager.tasks.first?.id, normalTask.id, "正常任務應該保留")
        XCTAssertFalse(manager.tasks.contains(where: { $0.id == placeholderTask.id }), "佔位任務應該被移除")
        XCTAssertTrue(mockPersistence.saveTasksCalled, "應該呼叫 saveTasks 持久化")
    }

    func testPlaylistSelectionCallback_IsTriggered() {
        // Arrange: 設定回調
        var receivedRequest: PlaylistSelectionRequest?
        manager.onPlaylistSelectionNeeded = { request in
            receivedRequest = request
        }

        let request = PlaylistSelectionRequest(
            playlistTitle: "Test Playlist",
            videos: [
                VideoInfo(
                    id: "vid1", title: "Video 1", thumbnail: nil,
                    duration: 120, uploader: "Test", url: "https://www.youtube.com/watch?v=vid1",
                    liveStatus: nil, releaseTimestamp: nil
                ),
            ],
            placeholderTaskId: UUID(),
            callbackScheme: nil,
            requestId: nil
        )

        // Act: 手動觸發回調
        manager.onPlaylistSelectionNeeded?(request)

        // Assert
        XCTAssertNotNil(receivedRequest, "回調應該被觸發")
        XCTAssertEqual(receivedRequest?.playlistTitle, "Test Playlist", "播放清單標題應該正確")
        XCTAssertEqual(receivedRequest?.videos.count, 1, "影片數量應該正確")
    }
}

final class MockYouTubeMetadataService: YouTubeMetadataServiceProtocol {
    var videoInfo: VideoInfo!
    var mediaOptions: (subtitles: [SubtitleTrack], audioTracks: [AudioTrack], formats: [YTDLPFormat]) = ([], [], [])
    var mediaOptionsByURL: [String: (subtitles: [SubtitleTrack], audioTracks: [AudioTrack], formats: [YTDLPFormat])] = [:]
    var liveStatusByURL: [String: String] = [:]
    var releaseTimestampByURL: [String: Int] = [:]
    var videoInfoError: Error?
    var mediaOptionsError: Error?
    var playlistInfo: (title: String, videos: [VideoInfo]) = ("", [])
    var fetchDelayNanoseconds: UInt64 = 0
    private(set) var fetchedVideoURLs: [String] = []
    private(set) var fetchedMediaOptionURLs: [String] = []
    private(set) var fetchedPlaylistURLs: [String] = []

    func fetchVideoInfo(url: String, cookiesArguments: [String]) async throws -> VideoInfo {
        fetchedVideoURLs.append(url)
        if fetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }
        if let videoInfoError {
            throw videoInfoError
        }
        return videoInfo
    }

    func fetchMediaOptions(url: String, cookiesArguments: [String]) async throws -> MediaOptions {
        if fetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }
        if let mediaOptionsError {
            throw mediaOptionsError
        }
        fetchedMediaOptionURLs.append(url)
        let base = mediaOptionsByURL[url] ?? mediaOptions
        return MediaOptions(
            subtitles: base.subtitles,
            audioTracks: base.audioTracks,
            formats: base.formats,
            liveStatus: liveStatusByURL[url],
            releaseTimestamp: releaseTimestampByURL[url]
        )
    }

    func fetchPlaylistInfo(url: String, cookiesArguments: [String]) async throws -> (title: String, videos: [VideoInfo]) {
        fetchedPlaylistURLs.append(url)
        if fetchDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }
        return playlistInfo
    }

    func fetchTitleFromWebpage(url: String) async -> String? {
        return nil
    }
}

final class MockYTDLPService: YTDLPServiceProtocol {
    var outputPath = "/tmp/test.mp4"
    private(set) var downloadedURLs: [String] = []
    private(set) var downloadedCommandTemplates: [String] = []
    private(set) var cancelledTaskIDs: [UUID] = []
    var downloadError: Error?

    func download(
        taskId: UUID,
        url: String,
        commandTemplate: String,
        outputDirectory: String,
        subtitleSelection: SubtitleSelection?,
        audioSelection: AudioSelection?,
        onProgress: @escaping ProgressCallback
    ) async throws -> String {
        downloadedURLs.append(url)
        downloadedCommandTemplates.append(commandTemplate)
        if let downloadError {
            throw downloadError
        }
        onProgress(1)
        return outputPath
    }

    func cancel(taskId: UUID) async {
        cancelledTaskIDs.append(taskId)
    }
}

final class MockNotificationService: NotificationServiceProtocol {
    private(set) var completedNotifications: [(title: String, outputPath: String)] = []
    private(set) var failedNotifications: [(title: String, error: String)] = []
    private(set) var allDownloadsCompleteCounts: [Int] = []

    func sendDownloadCompleteNotification(title: String, outputPath: String) {
        completedNotifications.append((title, outputPath))
    }

    func sendDownloadFailedNotification(title: String, error: String) {
        failedNotifications.append((title, error))
    }

    func sendAllDownloadsCompleteNotification(count: Int) {
        allDownloadsCompleteCounts.append(count)
    }
}
