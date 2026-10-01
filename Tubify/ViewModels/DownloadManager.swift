import AVFoundation
import Foundation
import SwiftUI

/// URL 驗證結果
enum URLValidationResult {
    case success
    case invalidFormat      // 格式不正確（如 markdown 連結）
    case alreadyExists     // 已在佇列中
}

/// 媒體選項選擇請求（字幕 + 音軌）
struct MediaSelectionRequest: Identifiable {
    let id: UUID
    let tasks: [DownloadTask]
    let availableSubtitles: [SubtitleTrack]
    let availableAudioTracks: [AudioTrack]
    let videoTitle: String?  // 單一影片為標題，播放清單為 nil

    init(
        id: UUID = UUID(),
        tasks: [DownloadTask],
        availableSubtitles: [SubtitleTrack],
        availableAudioTracks: [AudioTrack],
        videoTitle: String?
    ) {
        self.id = id
        self.tasks = tasks
        self.availableSubtitles = availableSubtitles
        self.availableAudioTracks = availableAudioTracks
        self.videoTitle = videoTitle
    }
}

/// 影片或播放清單選擇請求
struct VideoOrPlaylistChoiceRequest: Identifiable {
    let id = UUID()
    let urlString: String
    let callbackScheme: String?
    let requestId: String?
}

/// 播放清單選集請求
struct PlaylistSelectionRequest: Identifiable {
    let id = UUID()
    let playlistTitle: String
    let videos: [VideoInfo]
    let placeholderTaskId: UUID
    let callbackScheme: String?
    let requestId: String?
}

/// 已下載檔案的檢視與清理操作（可注入以供測試使用）
struct DownloadedFileInspector {
    /// 媒體檔的實際長度（秒）；無法判讀時回傳 nil
    var duration: (String) async -> TimeInterval?
    /// 將檔案移到垃圾桶
    var trash: (String) throws -> Void

    static let live = DownloadedFileInspector(
        duration: { path in
            // AVFoundation 不支援的容器格式回傳 nil
            guard let duration = try? await AVURLAsset(url: URL(fileURLWithPath: path)).load(.duration),
                  duration.isNumeric else {
                return nil
            }
            return duration.seconds
        },
        trash: { path in
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        }
    )
}

/// 下載管理器
@Observable
@MainActor
class DownloadManager {
    static let shared = DownloadManager()

    /// 所有下載任務
    var tasks: [DownloadTask] = []

    /// 是否正在下載
    var isDownloading: Bool = false

    /// 是否全部暫停
    var isAllPaused: Bool = false

    /// 目前下載中的任務（支援同時多個）
    var currentTasks: Set<UUID> = []

    /// 媒體選項選擇回調（由 UI 設置）
    var onMediaSelectionNeeded: ((MediaSelectionRequest) -> Void)?

    /// 播放清單選集回調（由 UI 設置）
    var onPlaylistSelectionNeeded: ((PlaylistSelectionRequest) -> Void)?

    /// 影片或播放清單選擇回調（由 UI 設置）
    var onVideoOrPlaylistChoiceNeeded: ((VideoOrPlaylistChoiceRequest) -> Void)?

    private var unresolvedMediaRequests: [MediaSelectionRequest] = []
    private var unresolvedPlaylistRequests: [PlaylistSelectionRequest] = []
    private var unresolvedVideoOrPlaylistRequests: [VideoOrPlaylistChoiceRequest] = []
    private var deliveredRequestIDsBySession: [UUID: Set<UUID>] = [:]
    private var activeUISessionID: UUID?
    private var didRecoverPersistedTasks = false

    /// 持久化服務（可注入以供測試使用）
    private let persistenceService: PersistenceServiceProtocol
    private let metadataService: YouTubeMetadataServiceProtocol
    private let ytdlpService: YTDLPServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let fileInspector: DownloadedFileInspector

    /// 設定（使用 UserDefaults 直接讀取，避免與 @Observable 衝突）
    var downloadCommand: String {
        get { UserDefaults.standard.string(forKey: AppSettingsKeys.downloadCommand) ?? AppSettingsDefaults.downloadCommand }
        set { UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.downloadCommand) }
    }

    var downloadFolder: String {
        get { UserDefaults.standard.string(forKey: AppSettingsKeys.downloadFolder) ?? AppSettingsDefaults.downloadFolder }
        set { UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.downloadFolder) }
    }

    var maxConcurrentDownloads: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: AppSettingsKeys.maxConcurrentDownloads).nonZeroOrDefault(AppSettingsDefaults.maxConcurrentDownloads)
            return min(max(value, 1), 5) // 限制在 1-5 之間
        }
        set { UserDefaults.standard.set(min(max(newValue, 1), 5), forKey: AppSettingsKeys.maxConcurrentDownloads) }
    }

    private var downloadTask: Task<Void, Never>?

    /// 正式環境初始化
    private convenience init() {
        self.init(persistenceService: PersistenceService.shared)
    }

    /// 可注入初始化（供測試使用）
    init(
        persistenceService: PersistenceServiceProtocol,
        metadataService: YouTubeMetadataServiceProtocol = YouTubeMetadataService.shared,
        ytdlpService: YTDLPServiceProtocol = YTDLPService.shared,
        notificationService: NotificationServiceProtocol = NotificationService.shared,
        fileInspector: DownloadedFileInspector = .live
    ) {
        self.persistenceService = persistenceService
        self.metadataService = metadataService
        self.ytdlpService = ytdlpService
        self.notificationService = notificationService
        self.fileInspector = fileInspector

        // 載入已儲存的任務
        tasks = persistenceService.loadTasks()

        // 監聽外部下載請求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalDownloadRequest(_:)),
            name: .externalDownloadRequest,
            object: nil
        )
    }

    func resumePersistedTasksAfterUIActivation(sessionID: UUID) {
        activeUISessionID = sessionID
        deliverUnresolvedRequests(to: sessionID)

        guard !didRecoverPersistedTasks else { return }
        didRecoverPersistedTasks = true

        var shouldStartQueue = false
        for task in tasks {
            switch task.status {
            case .downloading:
                task.status = .pending
                task.progress = 0
                shouldStartQueue = true
            case .pending:
                shouldStartQueue = true
            case .fetchingInfo:
                recoverFetchingInfoTask(task)
            case .waitingForMediaSelection:
                recoverWaitingForMediaSelectionTask(task)
            case .completed, .failed, .cancelled, .paused, .scheduled, .livestreaming, .postLive:
                break
            }
        }

        persistenceService.saveTasks(tasks)
        if shouldStartQueue {
            startDownloadQueue()
        }
    }

    func deactivateUI(sessionID: UUID) {
        guard activeUISessionID == sessionID else { return }
        activeUISessionID = nil
        onMediaSelectionNeeded = nil
        onPlaylistSelectionNeeded = nil
        onVideoOrPlaylistChoiceNeeded = nil
    }

    private func recoverFetchingInfoTask(_ task: DownloadTask) {
        if task.title == "載入播放清單中...",
           isValidYouTubeURL(task.url),
           YouTubeMetadataService.isPlaylistSync(url: task.url) {
            Task {
                await expandPlaylist(
                    placeholderTask: task,
                    urlString: task.url,
                    callbackScheme: task.callbackScheme,
                    requestId: task.requestId
                )
            }
            return
        }

        if task.title == "載入中..." {
            task.title = "重新載入中..."
        }
        Task {
            await fetchMetadataForTask(task)
        }
    }

    private func recoverWaitingForMediaSelectionTask(_ task: DownloadTask) {
        let subtitles = task.availableSubtitles ?? []
        let audioTracks = task.availableAudioTracks ?? []
        guard !subtitles.isEmpty || !audioTracks.isEmpty else {
            task.status = .fetchingInfo
            recoverFetchingInfoTask(task)
            return
        }

        registerMediaRequest(MediaSelectionRequest(
            tasks: [task],
            availableSubtitles: subtitles,
            availableAudioTracks: audioTracks,
            videoTitle: task.title
        ))
    }

    private func registerMediaRequest(_ request: MediaSelectionRequest) {
        guard !request.tasks.isEmpty,
              request.tasks.allSatisfy({ requestedTask in
                  tasks.contains { $0.id == requestedTask.id }
              }) else {
            return
        }
        unresolvedMediaRequests.append(request)
        deliver(request, using: onMediaSelectionNeeded)
    }

    private func registerPlaylistRequest(_ request: PlaylistSelectionRequest) {
        guard tasks.contains(where: { $0.id == request.placeholderTaskId }) else {
            return
        }
        unresolvedPlaylistRequests.append(request)
        deliver(request, using: onPlaylistSelectionNeeded)
    }

    private func registerVideoOrPlaylistRequest(_ request: VideoOrPlaylistChoiceRequest) {
        unresolvedVideoOrPlaylistRequests.append(request)
        deliver(request, using: onVideoOrPlaylistChoiceNeeded)
    }

    private func deliver<Request: Identifiable>(
        _ request: Request,
        using callback: ((Request) -> Void)?
    ) where Request.ID == UUID {
        guard let sessionID = activeUISessionID,
              let callback,
              deliveredRequestIDsBySession[sessionID, default: []].contains(request.id) == false else {
            return
        }
        deliveredRequestIDsBySession[sessionID, default: []].insert(request.id)
        callback(request)
    }

    private func deliverUnresolvedRequests(to sessionID: UUID) {
        guard activeUISessionID == sessionID else { return }
        for request in unresolvedMediaRequests {
            deliver(request, using: onMediaSelectionNeeded)
        }
        for request in unresolvedPlaylistRequests {
            deliver(request, using: onPlaylistSelectionNeeded)
        }
        for request in unresolvedVideoOrPlaylistRequests {
            deliver(request, using: onVideoOrPlaylistChoiceNeeded)
        }
    }

    private func removeUnresolvedRequests(referencing taskIDs: Set<UUID>) -> Bool {
        var shouldStartQueue = false
        unresolvedMediaRequests = unresolvedMediaRequests.compactMap { request in
            let remainingTasks = request.tasks.filter { !taskIDs.contains($0.id) }
            guard !remainingTasks.isEmpty else { return nil }
            guard remainingTasks.count != request.tasks.count else { return request }

            let subtitleCodes = Set(remainingTasks.flatMap { $0.availableSubtitles ?? [] }.map(\.languageCode))
            let audioCodes = Set(remainingTasks.flatMap { $0.availableAudioTracks ?? [] }.map(\.languageCode))
            let needsSelection = subtitleCodes.contains(where: SubtitleTrack.isSupportedLanguage)
                || audioCodes.filter(AudioTrack.isSupportedLanguage).count > 1
            guard needsSelection else {
                let newStatus: DownloadStatus = isAllPaused ? .paused : .pending
                for task in remainingTasks {
                    task.status = newStatus
                }
                shouldStartQueue = shouldStartQueue || newStatus == .pending
                return nil
            }

            return MediaSelectionRequest(
                id: request.id,
                tasks: remainingTasks,
                availableSubtitles: request.availableSubtitles.filter { subtitleCodes.contains($0.languageCode) },
                availableAudioTracks: request.availableAudioTracks.filter { audioCodes.contains($0.languageCode) },
                videoTitle: request.videoTitle
            )
        }
        unresolvedPlaylistRequests.removeAll { request in
            taskIDs.contains(request.placeholderTaskId)
        }
        return shouldStartQueue
    }

    @objc private func handleExternalDownloadRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let urlString = userInfo["url"] as? String else {
            return
        }

        let callbackScheme = userInfo["callback"] as? String
        let requestId = userInfo["request_id"] as? String

        // 建立下載任務，帶上 callback 和 request_id 資訊
        addURL(urlString, callbackScheme: callbackScheme, requestId: requestId)
    }

    /// 新增 URL 到下載佇列
    @discardableResult
    func addURL(_ urlString: String) -> URLValidationResult {
        return addURL(urlString, callbackScheme: nil, requestId: nil)
    }

    /// 新增 URL 到下載佇列（支援回調）
    /// - Parameters:
    ///   - urlString: YouTube URL
    ///   - callbackScheme: 下載完成後的回調 Scheme（可選）
    ///   - requestId: 請求識別碼，回調時原樣帶回（可選）
    @discardableResult
    func addURL(_ urlString: String, callbackScheme: String?, requestId: String?) -> URLValidationResult {
        // 基本格式檢查：必須是有效的 URL 格式，且不是 markdown 連結
        guard isValidURLFormat(urlString) else {
            TubifyLogger.download.error("無效的 URL 格式: \(urlString)")
            return .invalidFormat
        }

        // 檢查是否已存在
        if tasks.contains(where: { $0.url == urlString }) {
            TubifyLogger.download.info("URL 已在佇列中: \(urlString)")
            return .alreadyExists
        }

        // 播放清單偵測／展開與混合 URL 提示僅適用於 YouTube 網址；
        // 非 YouTube 網址一律走單一任務路徑，由 yt-dlp 自行處理清單。
        let isPlaylist = isValidYouTubeURL(urlString) && YouTubeMetadataService.isPlaylistSync(url: urlString)

        // 檢查是否同時包含影片 ID 和播放清單 ID（混合 URL）
        if isPlaylist, let components = URLComponents(string: urlString),
           components.queryItems?.contains(where: { $0.name == "v" && $0.value?.isEmpty == false }) == true {
            // 混合 URL：詢問使用者要下載影片還是播放清單
            let request = VideoOrPlaylistChoiceRequest(
                urlString: urlString,
                callbackScheme: callbackScheme,
                requestId: requestId
            )
            registerVideoOrPlaylistRequest(request)
            return .success
        }

        if isPlaylist {
            // 播放清單：先建立佔位任務，然後異步展開
            let task = DownloadTask(url: urlString, title: "載入播放清單中...")
            task.status = .fetchingInfo
            task.callbackScheme = callbackScheme
            task.requestId = requestId
            tasks.append(task)
            persistenceService.saveTasks(tasks)

            Task {
                await expandPlaylist(placeholderTask: task, urlString: urlString, callbackScheme: callbackScheme, requestId: requestId)
            }
        } else {
            // 單一影片：先同步建立任務並加入列表
            let task = DownloadTask(url: urlString)
            task.status = .fetchingInfo
            task.callbackScheme = callbackScheme
            task.requestId = requestId

            // 僅 YouTube 網址預取 ytimg 縮圖；extractVideoIdSync 的 11 碼樣式會誤命中
            // 非 YouTube 網址（如 Instagram）的路徑片段，故須閘控。
            if isValidYouTubeURL(urlString),
               let videoId = YouTubeMetadataService.extractVideoIdSync(from: urlString) {
                task.thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
            }

            tasks.append(task)
            persistenceService.saveTasks(tasks)

            // 異步獲取資訊（不阻塞新 URL 的加入）
            Task {
                await fetchMetadataForTask(task)
            }
        }

        return .success
    }

    /// 獲取 Cookies 參數
    private func getCookiesArguments() -> [String] {
        // 檢查設定的下載指令是否包含 Safari cookies
        if SafariCookiesService.shared.commandNeedsSafariCookies(downloadCommand) {
            // 嘗試導出 Cookies
            if let cookiesPath = SafariCookiesService.shared.exportSafariCookies() {
                TubifyLogger.download.info("使用導出的 Safari Cookies 進行元資料獲取")
                return ["--cookies", cookiesPath]
            }
        }
        return []
    }

    /// 獲取單一影片的元資料
    /// - Parameter statusOnFailure: 重試時傳入任務原本的狀態；metadata 抓取失敗時還原為該狀態而不排入佇列
    private func fetchMetadataForTask(_ task: DownloadTask, statusOnFailure: DownloadStatus? = nil) async {
        TubifyLogger.download.info("獲取影片元資料: \(task.url)")

        // 獲取 cookies 參數（解決 Bot 驗證問題）
        let cookiesArgs = getCookiesArguments()

        // 注意：不使用 cookies 來獲取元資料，因為：
        // 1. 公開影片不需要認證就可以獲取元資料
        // 2. 使用 Safari cookies 需要 Full Disk Access 權限，沒有權限會導致 yt-dlp 無限期掛起
        // 3. Cookies 只在下載時使用（下載私人影片時）

        // 決定新任務的狀態：如果全部暫停中，新任務也設為暫停
        let newStatus: DownloadStatus = isAllPaused ? .paused : .pending

        do {
            let videoInfo = try await metadataService.fetchVideoInfo(url: task.url, cookiesArguments: cookiesArgs)
            TubifyLogger.download.info("成功獲取影片資訊: \(videoInfo.title)")
            task.title = videoInfo.title
            task.thumbnailURL = videoInfo.thumbnail
            task.duration = videoInfo.duration
            if let liveStatus = videoInfo.liveStatus, DownloadConstants.liveRelatedStatuses.contains(liveStatus) {
                task.wasLive = true
            }

            // 檢查是否為尚未首播（首播排程中）：yt-dlp 以 --skip-download 抓取 metadata 時
            // 會成功回傳 JSON，若不攔截會落入 .pending 被排入佇列，下載時 yt-dlp 卡在 0% 無限等待。
            // 必須等首播播完才可下載，因此設為 .scheduled 且不加入佇列。
            if videoInfo.liveStatus == "is_upcoming" {
                TubifyLogger.download.info("偵測到尚未首播（首播排程中）: \(videoInfo.title)")
                task.status = .scheduled

                // 解析首播時間（release_timestamp 為 Unix 時間）
                if let releaseTimestamp = videoInfo.releaseTimestamp {
                    task.premiereDate = Date(timeIntervalSince1970: TimeInterval(releaseTimestamp))
                    TubifyLogger.download.info("首播時間: \(task.premiereDate!)")
                }

                persistenceService.saveTasks(tasks)
                return  // 不加入下載佇列
            }

            // 檢查是否正在首播串流
            if videoInfo.liveStatus == "is_live" {
                TubifyLogger.download.info("偵測到正在首播串流中: \(videoInfo.title)")
                task.status = .livestreaming

                // 計算預計播完時間
                if let releaseTimestamp = videoInfo.releaseTimestamp,
                   let duration = videoInfo.duration {
                    let endTimestamp = releaseTimestamp + duration
                    task.expectedEndTime = Date(timeIntervalSince1970: TimeInterval(endTimestamp))
                    TubifyLogger.download.info("預計播完時間: \(task.expectedEndTime!)")
                }

                persistenceService.saveTasks(tasks)
                return  // 不加入下載佇列
            }

            var mediaOptions: MediaOptions?

            // 檢查是否為直播剛結束、正在處理中
            if videoInfo.liveStatus == "post_live" {
                if !videoInfo.hasUsableMediaFormats {
                    do {
                        let fetchedOptions = try await metadataService.fetchMediaOptions(url: task.url, cookiesArguments: cookiesArgs)
                        guard YTDLPFormat.hasUsableMediaFormats(fetchedOptions.formats) else {
                            markTaskAsPostLive(task)
                            persistenceService.saveTasks(tasks)
                            return
                        }
                        mediaOptions = fetchedOptions
                    } catch {
                        handlePostLiveFormatLookupError(error, for: task)
                        persistenceService.saveTasks(tasks)
                        return
                    }
                }
            }

            // 獲取字幕和音軌資訊
            let resolvedMediaOptions: MediaOptions
            if let mediaOptions {
                resolvedMediaOptions = mediaOptions
            } else {
                resolvedMediaOptions = try await metadataService.fetchMediaOptions(url: task.url, cookiesArguments: cookiesArgs)
            }

            // 過濾只保留支援的語言
            let filteredSubtitles = resolvedMediaOptions.subtitles.filter { SubtitleTrack.isSupportedLanguage($0.languageCode) }
            let filteredAudioTracks = resolvedMediaOptions.audioTracks.filter { AudioTrack.isSupportedLanguage($0.languageCode) }

            if !filteredSubtitles.isEmpty || filteredAudioTracks.count > 1 {
                // 有字幕或多個音軌，等待用戶選擇
                task.availableSubtitles = resolvedMediaOptions.subtitles
                task.availableAudioTracks = resolvedMediaOptions.audioTracks
                task.status = .waitingForMediaSelection
                persistenceService.saveTasks(tasks)

                // 通知 UI 顯示媒體選項選擇視窗
                let request = MediaSelectionRequest(
                    tasks: [task],
                    availableSubtitles: resolvedMediaOptions.subtitles,
                    availableAudioTracks: resolvedMediaOptions.audioTracks,
                    videoTitle: task.title
                )
                registerMediaRequest(request)
                return
            } else {
                task.status = newStatus
            }
        } catch {
            let errorMessage = error.localizedDescription
            TubifyLogger.download.error("獲取影片資訊失敗: \(errorMessage)")

            // 檢查是否為首播影片
            if PremiereErrorParser.isPremiereError(errorMessage) {
                TubifyLogger.download.info("偵測到首播影片，嘗試從網頁獲取標題")

                // 嘗試從 YouTube 網頁直接獲取標題
                if let webTitle = await metadataService.fetchTitleFromWebpage(url: task.url) {
                    task.title = webTitle
                } else {
                    task.title = "無法獲取標題"
                }

                // 解析首播時間
                if let premiereDate = PremiereErrorParser.parsePremiereDate(from: errorMessage) {
                    task.premiereDate = premiereDate
                    task.status = .scheduled
                    task.wasLive = true
                    task.errorMessage = errorMessage
                } else {
                    task.status = newStatus
                }
            } else if let statusOnFailure {
                // 重試時無法確認首播是否已播完，維持原狀態，避免在串流仍進行時下載到片段
                task.status = statusOnFailure
                task.errorMessage = errorMessage
            } else {
                task.title = "無法獲取標題"
                task.status = newStatus
            }
        }

        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    private func markTaskAsPostLive(_ task: DownloadTask, message: String = "直播回放仍在處理中，請稍後重試。") {
        TubifyLogger.download.info("偵測到直播處理中: \(task.title)")
        task.status = .postLive
        task.wasLive = true
        task.errorMessage = message
    }

    private func handlePostLiveFormatLookupError(_ error: Error, for task: DownloadTask) {
        let errorMessage = error.localizedDescription
        if YTDLPErrorClassification.classify(errorMessage) == .endedLive {
            markTaskAsPostLive(task)
        } else {
            task.status = .failed
            task.errorMessage = errorMessage
            notificationService.sendDownloadFailedNotification(title: task.title, error: errorMessage)
        }
    }

    /// 展開播放清單
    private func expandPlaylist(placeholderTask: DownloadTask, urlString: String, callbackScheme: String? = nil, requestId: String? = nil) async {
        // 獲取 cookies 參數（解決 Bot 驗證問題）
        let cookiesArgs = getCookiesArguments()

        // 注意：不使用 cookies 來獲取播放清單元資料（原因同 fetchMetadataForTask）

        // 決定新任務的狀態：如果全部暫停中，新任務也設為暫停
        let newStatus: DownloadStatus = isAllPaused ? .paused : .pending

        do {
            let (playlistTitle, videos) = try await metadataService.fetchPlaylistInfo(url: urlString, cookiesArguments: cookiesArgs)

            // 空播放清單：移除佔位任務
            guard !videos.isEmpty else {
                TubifyLogger.download.info("播放清單為空，移除佔位任務")
                tasks.removeAll { $0.id == placeholderTask.id }
                persistenceService.saveTasks(tasks)
                return
            }

            // 觸發選集 UI，讓使用者選擇要下載的影片
            let request = PlaylistSelectionRequest(
                playlistTitle: playlistTitle,
                videos: videos,
                placeholderTaskId: placeholderTask.id,
                callbackScheme: callbackScheme,
                requestId: requestId
            )
            registerPlaylistRequest(request)
            return
        } catch {
            TubifyLogger.download.error("處理播放清單失敗: \(error.localizedDescription)")

            // 播放清單獲取失敗，將佔位任務轉為可下載狀態
            placeholderTask.title = "播放清單（無法獲取詳細資訊）"
            placeholderTask.status = newStatus
        }

        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 確認播放清單選集（由 UI 呼叫）
    func confirmPlaylistSelection(request: PlaylistSelectionRequest, selectedVideos: [VideoInfo]) {
        unresolvedPlaylistRequests.removeAll { $0.id == request.id }
        // 移除佔位任務
        tasks.removeAll { $0.id == request.placeholderTaskId }

        var newTasks: [DownloadTask] = []
        for video in selectedVideos {
            // 檢查是否已存在
            if tasks.contains(where: { $0.url == video.url }) {
                continue
            }

            let task = DownloadTask(
                url: video.url,
                title: video.title,
                thumbnailURL: video.thumbnail,
                status: .fetchingInfo,
                duration: video.duration,
                callbackScheme: request.callbackScheme,
                requestId: request.requestId
            )
            tasks.append(task)
            newTasks.append(task)
        }

        TubifyLogger.download.info("已新增播放清單中的 \(newTasks.count) 個影片（選取 \(selectedVideos.count)，共 \(request.videos.count) 個）")
        persistenceService.saveTasks(tasks)

        // 收集所有影片的字幕和音軌資訊
        Task {
            let cookiesArgs = getCookiesArguments()

            for task in newTasks {
                do {
                    let mediaOptions = try await metadataService.fetchMediaOptions(url: task.url, cookiesArguments: cookiesArgs)

                    // --flat-playlist 不含 duration 與 live_status，改用完整 metadata 回傳的值
                    if let duration = mediaOptions.duration {
                        task.duration = duration
                    }
                    if let liveStatus = mediaOptions.liveStatus, DownloadConstants.liveRelatedStatuses.contains(liveStatus) {
                        task.wasLive = true
                    }

                    // 尚未首播的影片必須等首播播完才可下載，設為 .scheduled 且不進佇列
                    if mediaOptions.liveStatus == "is_upcoming" {
                        TubifyLogger.download.info("播放清單中偵測到尚未首播: \(task.title)")
                        task.status = .scheduled
                        if let releaseTimestamp = mediaOptions.releaseTimestamp {
                            task.premiereDate = Date(timeIntervalSince1970: TimeInterval(releaseTimestamp))
                        }
                        continue
                    }

                    // 正在首播串流的影片此時下載只會得到片段，設為 .livestreaming 且不進佇列
                    if mediaOptions.liveStatus == "is_live" {
                        TubifyLogger.download.info("播放清單中偵測到正在首播串流中: \(task.title)")
                        task.status = .livestreaming
                        if let releaseTimestamp = mediaOptions.releaseTimestamp,
                           let duration = task.duration {
                            task.expectedEndTime = Date(timeIntervalSince1970: TimeInterval(releaseTimestamp + duration))
                        }
                        continue
                    }

                    if mediaOptions.liveStatus == "post_live" && !YTDLPFormat.hasUsableMediaFormats(mediaOptions.formats) {
                        markTaskAsPostLive(task)
                        continue
                    }
                    task.availableSubtitles = mediaOptions.subtitles
                    task.availableAudioTracks = mediaOptions.audioTracks
                } catch {
                    // metadata 抓取失敗：分類錯誤（直播已結束 → .postLive，其餘 → .failed）
                    // 原本依賴 --flat-playlist 永遠為 nil 的 pair.video.liveStatus，實際從不觸發
                    handlePostLiveFormatLookupError(error, for: task)
                }
            }

            let newStatus: DownloadStatus = isAllPaused ? .paused : .pending
            let activeTaskIDs = Set(tasks.map(\.id))
            let readyTasks = newTasks.filter {
                $0.status == .fetchingInfo && activeTaskIDs.contains($0.id)
            }
            let allSubtitleCodes = Set(readyTasks.flatMap { $0.availableSubtitles ?? [] }.map(\.languageCode))
            let allAudioCodes = Set(readyTasks.flatMap { $0.availableAudioTracks ?? [] }.map(\.languageCode))

            // 過濾只保留支援的語言
            let filteredSubtitleCodes = allSubtitleCodes.filter { SubtitleTrack.isSupportedLanguage($0) }
            let filteredAudioCodes = allAudioCodes.filter { AudioTrack.isSupportedLanguage($0) }

            if !filteredSubtitleCodes.isEmpty || filteredAudioCodes.count > 1 {
                for task in readyTasks {
                    task.status = .waitingForMediaSelection
                }
                persistenceService.saveTasks(tasks)

                let mergedSubtitles = allSubtitleCodes.map { SubtitleTrack(languageCode: $0) }
                    .sorted { $0.languageName.localizedCompare($1.languageName) == .orderedAscending }
                let mergedAudioTracks = allAudioCodes.map { AudioTrack(languageCode: $0) }
                    .sorted { $0.languageName.localizedCompare($1.languageName) == .orderedAscending }

                let mediaRequest = MediaSelectionRequest(
                    tasks: readyTasks,
                    availableSubtitles: mergedSubtitles,
                    availableAudioTracks: mergedAudioTracks,
                    videoTitle: nil
                )
                if !readyTasks.isEmpty {
                    registerMediaRequest(mediaRequest)
                }
            } else {
                for task in readyTasks {
                    task.status = newStatus
                }
                persistenceService.saveTasks(tasks)
                if !readyTasks.isEmpty {
                    startDownloadQueue()
                }
            }
        }
    }

    /// 確認影片或播放清單選擇（由 UI 呼叫）
    enum VideoOrPlaylistChoice {
        case video
        case playlist
        case cancel
    }

    func confirmVideoOrPlaylistChoice(request: VideoOrPlaylistChoiceRequest, choice: VideoOrPlaylistChoice) {
        unresolvedVideoOrPlaylistRequests.removeAll { $0.id == request.id }
        switch choice {
        case .video:
            // 去除播放清單相關參數，直接走單一影片流程
            let videoURL = stripPlaylistParameters(from: request.urlString)
            addURLAsSingleVideo(videoURL, callbackScheme: request.callbackScheme, requestId: request.requestId)
        case .playlist:
            // 走現有播放清單流程
            addURLAsPlaylist(request.urlString, callbackScheme: request.callbackScheme, requestId: request.requestId)
        case .cancel:
            break
        }
    }

    /// 去除 URL 中的播放清單相關參數
    private func stripPlaylistParameters(from urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        let playlistParams: Set<String> = ["list", "index"]
        components.queryItems = components.queryItems?.filter { !playlistParams.contains($0.name) }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        return components.url?.absoluteString ?? urlString
    }

    /// 以單一影片模式新增 URL（跳過混合 URL 檢測）
    private func addURLAsSingleVideo(_ urlString: String, callbackScheme: String?, requestId: String?) {
        // 檢查是否已存在
        guard !tasks.contains(where: { $0.url == urlString }) else { return }

        let task = DownloadTask(url: urlString)
        task.status = .fetchingInfo
        task.callbackScheme = callbackScheme
        task.requestId = requestId

        if let videoId = YouTubeMetadataService.extractVideoIdSync(from: urlString) {
            task.thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
        }

        tasks.append(task)
        persistenceService.saveTasks(tasks)

        Task {
            await fetchMetadataForTask(task)
        }
    }

    /// 以播放清單模式新增 URL（跳過混合 URL 檢測）
    private func addURLAsPlaylist(_ urlString: String, callbackScheme: String?, requestId: String?) {
        let task = DownloadTask(url: urlString, title: "載入播放清單中...")
        task.status = .fetchingInfo
        task.callbackScheme = callbackScheme
        task.requestId = requestId
        tasks.append(task)
        persistenceService.saveTasks(tasks)

        Task {
            await expandPlaylist(placeholderTask: task, urlString: urlString, callbackScheme: callbackScheme, requestId: requestId)
        }
    }

    /// 取消播放清單選集（由 UI 呼叫）
    func cancelPlaylistSelection(placeholderTaskId: UUID) {
        unresolvedPlaylistRequests.removeAll { $0.placeholderTaskId == placeholderTaskId }
        tasks.removeAll { $0.id == placeholderTaskId }
        persistenceService.saveTasks(tasks)
    }

    /// 確認媒體選項選擇（由 UI 呼叫）
    func confirmMediaSelection(for tasks: [DownloadTask], subtitleSelection: SubtitleSelection?, audioSelection: AudioSelection?) {
        let taskIDs = Set(tasks.map(\.id))
        unresolvedMediaRequests.removeAll { request in
            Set(request.tasks.map(\.id)).isSubset(of: taskIDs)
        }
        let newStatus: DownloadStatus = isAllPaused ? .paused : .pending
        let activeTaskIDs = Set(self.tasks.map(\.id))

        for task in tasks where activeTaskIDs.contains(task.id) {
            let availableSubtitleCodes = Set((task.availableSubtitles ?? []).map(\.languageCode))
            let selectedSubtitleCodes = subtitleSelection?.selectedLanguages.filter(availableSubtitleCodes.contains) ?? []
            task.subtitleSelection = selectedSubtitleCodes.isEmpty
                ? nil
                : SubtitleSelection(selectedLanguages: selectedSubtitleCodes)

            let availableAudioCodes = Set((task.availableAudioTracks ?? []).map(\.languageCode))
            if let selectedAudioCode = audioSelection?.selectedLanguage,
               availableAudioCodes.contains(selectedAudioCode) {
                task.audioSelection = AudioSelection(selectedLanguage: selectedAudioCode)
            } else {
                task.audioSelection = nil
            }
            task.status = newStatus
        }

        persistenceService.saveTasks(self.tasks)
        startDownloadQueue()
    }

    /// 開始下載佇列
    func startDownloadQueue() {
        guard downloadTask == nil else { return }

        downloadTask = Task {
            await processQueue()
        }
    }

    /// 處理下載佇列
    private func processQueue() async {
        isDownloading = true

        while tasks.contains(where: { $0.status == .pending }) || !currentTasks.isEmpty {
            // 找出可以開始的任務數量
            let availableSlots = maxConcurrentDownloads - currentTasks.count

            TubifyLogger.download.debug("佇列狀態: maxConcurrent=\(self.maxConcurrentDownloads), currentTasks=\(self.currentTasks.count), availableSlots=\(availableSlots)")

            if availableSlots > 0 && !isAllPaused {
                // 取得待處理的任務
                // 排除前一次下載流程尚未結束的任務（例如暫停後立即恢復），等舊流程退出後才重新下載
                let pendingTasks = tasks
                    .filter { $0.status == .pending && !currentTasks.contains($0.id) }
                    .prefix(availableSlots)

                TubifyLogger.download.debug("準備啟動 \(pendingTasks.count) 個下載任務")

                var isFirstTask = true
                for task in pendingTasks {
                    // 啟動新任務前等待間隔（第一個任務不等，避免不必要的延遲）
                    if !isFirstTask {
                        TubifyLogger.download.debug("等待 \(DownloadConstants.preStartDelay) 秒後啟動下一個任務")
                        try? await Task.sleep(for: .seconds(DownloadConstants.preStartDelay))
                    }
                    isFirstTask = false

                    currentTasks.insert(task.id)
                    TubifyLogger.download.info("啟動並行下載: \(task.title) (目前進行中: \(self.currentTasks.count))")

                    // 啟動下載任務（不等待完成）
                    Task {
                        await self.downloadSingleTask(task)

                        // 下載完成後從 currentTasks 移除
                        _ = await MainActor.run {
                            self.currentTasks.remove(task.id)
                        }
                    }
                }
            }

            // 等待一段時間後再檢查
            try? await Task.sleep(for: .milliseconds(500))

            // 如果沒有正在下載的任務且沒有待處理的任務，退出循環
            if currentTasks.isEmpty && !tasks.contains(where: { $0.status == .pending }) {
                break
            }
        }

        isDownloading = false
        downloadTask = nil

        // 所有下載完成
        let completedCount = tasks.filter { $0.status == .completed }.count
        if completedCount > 0 {
            notificationService.sendAllDownloadsCompleteNotification(count: completedCount)
        }
    }

    /// 下載單一任務
    private func downloadSingleTask(_ task: DownloadTask) async {
        task.status = .downloading
        task.progress = 0

        // 下載與完成後的長度檢查共用同一份指令，避免下載途中設定被修改而誤判
        let commandTemplate = effectiveDownloadCommand(for: task.url)

        do {
            let outputPath = try await ytdlpService.download(
                taskId: task.id,
                url: task.url,
                commandTemplate: commandTemplate,
                outputDirectory: downloadFolder,
                subtitleSelection: task.subtitleSelection,
                audioSelection: task.audioSelection
            ) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                }
            }

            // 首播／直播影片：比對實際長度，避免把串流片段當成完整影片
            let isIncomplete = await isIncompleteLiveDownload(task, outputPath: outputPath, commandTemplate: commandTemplate)
            // 完整性與清理權限分開判定：只有確定由此次下載產生的檔案才可移除
            let canRemoveOutput = isIncomplete ? await ytdlpService.didProduceOutputFile(taskId: task.id) : false

            // 長度檢查期間任務可能已被取消、暫停或移除，不可覆蓋其狀態
            guard task.status == .downloading, tasks.contains(where: { $0.id == task.id }) else {
                persistenceService.saveTasks(tasks)
                return
            }

            if isIncomplete && !canRemoveOutput {
                // yt-dlp 沿用了既有的同名檔（其他影片、其他任務，或先前未能清除的片段），不可移除也不可視為完成
                TubifyLogger.download.error("輸出檔長度不足且非此次下載產生，保留檔案: \(outputPath)")
                let errorMsg = "下載資料夾中已有同名檔案，且長度明顯短於預期。請移除或重新命名該檔案後重試：\(outputPath)"
                task.status = .failed
                task.errorMessage = errorMsg
                notificationService.sendDownloadFailedNotification(title: task.title, error: errorMsg)
                persistenceService.saveTasks(tasks)
                return
            }

            if isIncomplete {
                // 移到垃圾桶，否則重試時 yt-dlp 可能因同名檔案已存在而略過下載
                do {
                    try fileInspector.trash(outputPath)
                } catch {
                    TubifyLogger.download.error("無法將不完整的檔案移到垃圾桶: \(outputPath)，\(error.localizedDescription)")
                }
                markTaskAsPostLive(task, message: "下載到的影片長度明顯短於預期，可能只錄到串流片段，請稍後重試。")
                persistenceService.saveTasks(tasks)
                return
            }

            task.status = .completed
            task.progress = 1.0
            task.outputPath = outputPath
            task.completedAt = Date()

            // 如果標題獲取失敗，從檔案名稱提取標題
            if task.title == "無法獲取標題" || task.title.isEmpty {
                let fileName = URL(fileURLWithPath: outputPath).deletingPathExtension().lastPathComponent
                if !fileName.isEmpty {
                    task.title = fileName
                }
            }

            // 發送通知
            notificationService.sendDownloadCompleteNotification(
                title: task.title,
                outputPath: outputPath
            )

            // 觸發回調（如果有設定）
            if let callbackScheme = task.callbackScheme {
                Task {
                    await CallbackService.shared.triggerCallback(
                        scheme: callbackScheme,
                        task: task,
                        filePath: outputPath
                    )
                }
            }

            // 檢查是否自動移除已完成的任務
            let autoRemove = UserDefaults.standard.object(forKey: AppSettingsKeys.autoRemoveCompleted) as? Bool
                ?? AppSettingsDefaults.autoRemoveCompleted
            if autoRemove {
                tasks.removeAll { $0.id == task.id }
            }
        } catch {
            let errorMsg = error.localizedDescription

            // 如果任務已經被暫停或取消，不要覆蓋狀態
            guard task.status != .paused && task.status != .cancelled else {
                persistenceService.saveTasks(tasks)
                return
            }

            // 檢查是否為首播影片
            if YTDLPErrorClassification.classify(errorMsg) == .endedLive {
                markTaskAsPostLive(task)
            } else if let premiereDate = PremiereErrorParser.parsePremiereDate(from: errorMsg) {
                task.status = .scheduled
                task.wasLive = true
                task.premiereDate = premiereDate
                task.errorMessage = errorMsg
            } else {
                task.status = .failed
                task.errorMessage = errorMsg

                // 發送失敗通知
                notificationService.sendDownloadFailedNotification(
                    title: task.title,
                    error: errorMsg
                )
            }
        }

        // 儲存任務
        persistenceService.saveTasks(tasks)
    }

    /// 首播／直播影片下載後的實際長度是否明顯短於 metadata 的長度；無法判讀長度時視為完整
    private func isIncompleteLiveDownload(_ task: DownloadTask, outputPath: String, commandTemplate: String) async -> Bool {
        guard task.wasLive, let expectedDuration = task.duration, expectedDuration > 0 else {
            return false
        }

        // 自訂指令刻意截短輸出時，長度不足是預期結果
        guard !DownloadConstants.durationShorteningOptions.contains(where: commandTemplate.contains) else {
            return false
        }

        guard let actualDuration = await fileInspector.duration(outputPath) else {
            return false
        }

        let isIncomplete = actualDuration < Double(expectedDuration) * DownloadConstants.minimumCompleteDurationRatio
        if isIncomplete {
            TubifyLogger.download.error("下載長度不完整: \(task.title)，預期 \(expectedDuration) 秒，實際 \(Int(actualDuration)) 秒")
        }
        return isIncomplete
    }

    /// 取消任務
    func cancelTask(_ task: DownloadTask) {
        if task.status == .downloading {
            Task {
                await ytdlpService.cancel(taskId: task.id)
            }
        }

        task.status = .cancelled
        persistenceService.saveTasks(tasks)
    }

    /// 移除任務
    func removeTask(_ task: DownloadTask) async {
        if task.status == .downloading {
            await ytdlpService.cancel(taskId: task.id)
        }

        let shouldStartQueue = removeUnresolvedRequests(referencing: [task.id])
        tasks.removeAll { $0.id == task.id }
        persistenceService.saveTasks(tasks)
        if shouldStartQueue {
            startDownloadQueue()
        }
    }

    /// 重試任務
    func retryTask(_ task: DownloadTask) {
        // 首播（.scheduled）、首播串流中（.livestreaming）與直播處理中（.postLive）需重新抓取 metadata 再判斷：
        // 若首播已播完會轉為可下載，否則回到原狀態，避免直接排入佇列導致 yt-dlp 卡在 0%，
        // 或在串流仍進行時只錄到當下的一小段片段
        if task.status == .postLive || task.status == .scheduled || task.status == .livestreaming {
            let previousStatus = task.status
            task.wasLive = true
            task.status = .fetchingInfo
            task.progress = 0
            task.errorMessage = nil
            persistenceService.saveTasks(tasks)
            Task {
                await fetchMetadataForTask(task, statusOnFailure: previousStatus)
            }
            return
        }

        task.status = .pending
        task.progress = 0
        task.errorMessage = nil
        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 清除已完成的任務
    func clearCompletedTasks() {
        tasks.removeAll { $0.status == .completed }
        persistenceService.saveTasks(tasks)
    }

    /// 清除所有任務
    func clearAllTasks() async {
        // 取消所有進行中的下載
        let downloadingTasks = tasks.filter { $0.status == .downloading }
        for task in downloadingTasks {
            await ytdlpService.cancel(taskId: task.id)
        }

        tasks.removeAll()
        unresolvedMediaRequests.removeAll()
        unresolvedPlaylistRequests.removeAll()
        unresolvedVideoOrPlaylistRequests.removeAll()
        deliveredRequestIDsBySession.removeAll()
        persistenceService.clearTasks()
    }

    /// 暫停全部下載
    func pauseAll() async {
        isAllPaused = true

        // 暫停所有正在下載的任務
        for task in tasks where task.status == .downloading {
            await ytdlpService.cancel(taskId: task.id)
            task.status = .paused
        }

        // 將等待中的任務也設為暫停
        for task in tasks where task.status == .pending {
            task.status = .paused
        }

        persistenceService.saveTasks(tasks)
    }

    /// 繼續全部下載
    func resumeAll() {
        isAllPaused = false

        // 將所有暫停和失敗的任務設為等待中
        for task in tasks where task.status == .paused || task.status == .failed {
            task.status = .pending
            task.progress = 0
            task.errorMessage = nil
        }

        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 暫停單一任務
    func pauseTask(_ task: DownloadTask) async {
        if task.status == .downloading {
            await ytdlpService.cancel(taskId: task.id)
        }
        task.status = .paused
        persistenceService.saveTasks(tasks)
    }

    /// 繼續單一任務
    func resumeTask(_ task: DownloadTask) {
        // 如果全部暫停中，恢復單一任務時需要解除全部暫停狀態
        // 否則 processQueue 不會處理這個任務
        if isAllPaused {
            isAllPaused = false
        }
        
        task.status = .pending
        task.progress = 0  // 重置進度，因為需要重新下載
        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 驗證 URL 格式是否有效
    private func isValidURLFormat(_ urlString: String) -> Bool {
        // 必須以 http:// 或 https:// 開頭
        guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
            return false
        }

        // 必須是有效的 URL
        guard URL(string: urlString) != nil else {
            return false
        }

        // 拒絕 markdown 連結格式（如 [text](url) 或包含 ]( 的字串）
        if urlString.contains("](") || urlString.hasPrefix("[") {
            return false
        }

        return true
    }

    /// 依網址選擇下載指令模板：YouTube 網址沿用使用者可設定的 downloadCommand，
    /// 其他網址使用固定的通用指令 genericDownloadCommand。
    /// 設為 internal 以便測試透過 @testable import 直接呼叫。
    func effectiveDownloadCommand(for urlString: String) -> String {
        isValidYouTubeURL(urlString) ? downloadCommand : AppSettingsDefaults.genericDownloadCommand
    }

    /// 驗證 YouTube URL
    private func isValidYouTubeURL(_ urlString: String) -> Bool {
        let patterns = [
            #"youtube\.com/watch\?(.*&)?v="#,
            #"youtu\.be/"#,
            #"youtube\.com/playlist\?(.*&)?list="#,
            #"youtube\.com/shorts/"#
        ]

        return patterns.contains { pattern in
            urlString.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// 在 Finder 中顯示檔案
    func showInFinder(_ task: DownloadTask) {
        guard let path = task.outputPath else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}
