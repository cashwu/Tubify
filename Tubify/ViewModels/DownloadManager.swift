import Foundation
import SwiftUI

/// URL 驗證結果
enum URLValidationResult {
    case success
    case invalidFormat      // 格式不正確（如 markdown 連結）
    case notYouTubeURL     // 非 YouTube 網址
    case alreadyExists     // 已在佇列中
}

/// 媒體選項選擇請求（字幕 + 音軌）
struct MediaSelectionRequest: Identifiable {
    let id = UUID()
    let tasks: [DownloadTask]
    let availableSubtitles: [SubtitleTrack]
    let availableAudioTracks: [AudioTrack]
    let videoTitle: String?  // 單一影片為標題，播放清單為 nil
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

    /// 持久化服務（可注入以供測試使用）
    private let persistenceService: PersistenceServiceProtocol

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
    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService

        // 載入已儲存的任務
        tasks = persistenceService.loadTasks()

        // 處理卡在 fetchingInfo 狀態的任務（可能是上次啟動時中斷的）
        // 這些任務需要重新獲取元資料，以確保能正確檢測字幕和音軌
        let stuckTasks = tasks.filter { $0.status == .fetchingInfo }
        for task in stuckTasks {
            TubifyLogger.download.info("重新獲取卡住任務的元資料: \(task.url)")
            if task.title == "載入中..." {
                task.title = "重新載入中..."
            }
            // 異步重新獲取元資料
            Task {
                await fetchMetadataForTask(task)
            }
        }

        // 如果有待處理的任務（非 fetchingInfo），開始下載
        if tasks.contains(where: { $0.status == .pending }) {
            persistenceService.saveTasks(tasks)
            startDownloadQueue()
        }

        // 監聽外部下載請求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalDownloadRequest(_:)),
            name: .externalDownloadRequest,
            object: nil
        )
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

        // 驗證是否為 YouTube URL
        guard isValidYouTubeURL(urlString) else {
            TubifyLogger.download.error("非 YouTube URL: \(urlString)")
            return .notYouTubeURL
        }

        // 檢查是否已存在
        if tasks.contains(where: { $0.url == urlString }) {
            TubifyLogger.download.info("URL 已在佇列中: \(urlString)")
            return .alreadyExists
        }

        // 使用靜態方法檢查是否為播放清單（不需要 await）
        let isPlaylist = YouTubeMetadataService.isPlaylistSync(url: urlString)

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

            // 使用靜態方法提取 video ID 來獲取縮圖（不需要 await）
            if let videoId = YouTubeMetadataService.extractVideoIdSync(from: urlString) {
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
    private func fetchMetadataForTask(_ task: DownloadTask) async {
        TubifyLogger.download.info("獲取影片元資料: \(task.url)")
        let metadataService = YouTubeMetadataService.shared

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

            // 檢查是否為直播剛結束、正在處理中
            if videoInfo.liveStatus == "post_live" {
                TubifyLogger.download.info("偵測到直播處理中: \(videoInfo.title)")
                task.status = .postLive
                persistenceService.saveTasks(tasks)
                return  // 不加入下載佇列，等待 YouTube 處理完成
            }

            // 獲取字幕和音軌資訊
            let mediaOptions = try await metadataService.fetchMediaOptions(url: task.url, cookiesArguments: cookiesArgs)

            // 過濾只保留支援的語言
            let filteredSubtitles = mediaOptions.subtitles.filter { SubtitleTrack.isSupportedLanguage($0.languageCode) }
            let filteredAudioTracks = mediaOptions.audioTracks.filter { AudioTrack.isSupportedLanguage($0.languageCode) }

            if !filteredSubtitles.isEmpty || filteredAudioTracks.count > 1 {
                // 有字幕或多個音軌，等待用戶選擇
                task.availableSubtitles = mediaOptions.subtitles
                task.availableAudioTracks = mediaOptions.audioTracks
                task.status = .waitingForMediaSelection
                persistenceService.saveTasks(tasks)

                // 通知 UI 顯示媒體選項選擇視窗
                let request = MediaSelectionRequest(
                    tasks: [task],
                    availableSubtitles: mediaOptions.subtitles,
                    availableAudioTracks: mediaOptions.audioTracks,
                    videoTitle: task.title
                )
                onMediaSelectionNeeded?(request)
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
                    task.errorMessage = errorMessage
                } else {
                    task.status = newStatus
                }
            } else {
                task.title = "無法獲取標題"
                task.status = newStatus
            }
        }

        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 展開播放清單
    private func expandPlaylist(placeholderTask: DownloadTask, urlString: String, callbackScheme: String? = nil, requestId: String? = nil) async {
        let metadataService = YouTubeMetadataService.shared

        // 獲取 cookies 參數（解決 Bot 驗證問題）
        let cookiesArgs = getCookiesArguments()

        // 注意：不使用 cookies 來獲取播放清單元資料（原因同 fetchMetadataForTask）

        // 決定新任務的狀態：如果全部暫停中，新任務也設為暫停
        let newStatus: DownloadStatus = isAllPaused ? .paused : .pending

        do {
            let videos = try await metadataService.fetchPlaylistInfo(url: urlString, cookiesArguments: cookiesArgs)

            // 移除佔位任務
            tasks.removeAll { $0.id == placeholderTask.id }

            var newTasks: [DownloadTask] = []
            for video in videos {
                // 檢查是否已存在
                if tasks.contains(where: { $0.url == video.url }) {
                    continue
                }

                let task = DownloadTask(
                    url: video.url,
                    title: video.title,
                    thumbnailURL: video.thumbnail,
                    status: .fetchingInfo,  // 先設為獲取資訊中
                    callbackScheme: callbackScheme,
                    requestId: requestId
                )
                tasks.append(task)
                newTasks.append(task)
            }

            TubifyLogger.download.info("已新增播放清單中的 \(videos.count) 個影片")
            persistenceService.saveTasks(tasks)

            // 收集所有影片的字幕和音軌資訊
            var allSubtitles: Set<String> = []
            var allAudioTracks: Set<String> = []
            for task in newTasks {
                if let mediaOptions = try? await metadataService.fetchMediaOptions(url: task.url, cookiesArguments: cookiesArgs) {
                    task.availableSubtitles = mediaOptions.subtitles
                    task.availableAudioTracks = mediaOptions.audioTracks
                    for sub in mediaOptions.subtitles {
                        allSubtitles.insert(sub.languageCode)
                    }
                    for audio in mediaOptions.audioTracks {
                        allAudioTracks.insert(audio.languageCode)
                    }
                }
            }

            // 過濾只保留支援的語言
            let filteredSubtitleCodes = allSubtitles.filter { SubtitleTrack.isSupportedLanguage($0) }
            let filteredAudioCodes = allAudioTracks.filter { AudioTrack.isSupportedLanguage($0) }

            if !filteredSubtitleCodes.isEmpty || filteredAudioCodes.count > 1 {
                // 有字幕或多個音軌，等待用戶選擇
                for task in newTasks {
                    task.status = .waitingForMediaSelection
                }
                persistenceService.saveTasks(tasks)

                // 合併所有字幕和音軌語言（聯集）
                let mergedSubtitles = allSubtitles.map { SubtitleTrack(languageCode: $0) }
                    .sorted { $0.languageName.localizedCompare($1.languageName) == .orderedAscending }
                let mergedAudioTracks = allAudioTracks.map { AudioTrack(languageCode: $0) }
                    .sorted { $0.languageName.localizedCompare($1.languageName) == .orderedAscending }

                // 通知 UI 顯示媒體選項選擇視窗
                let request = MediaSelectionRequest(
                    tasks: newTasks,
                    availableSubtitles: mergedSubtitles,
                    availableAudioTracks: mergedAudioTracks,
                    videoTitle: nil  // 播放清單不顯示單一標題
                )
                onMediaSelectionNeeded?(request)
                return
            } else {
                // 沒有字幕或音軌，直接設為待下載
                for task in newTasks {
                    task.status = newStatus
                }
            }
        } catch {
            TubifyLogger.download.error("處理播放清單失敗: \(error.localizedDescription)")

            // 播放清單獲取失敗，將佔位任務轉為可下載狀態
            placeholderTask.title = "播放清單（無法獲取詳細資訊）"
            placeholderTask.status = newStatus
        }

        persistenceService.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 確認媒體選項選擇（由 UI 呼叫）
    func confirmMediaSelection(for tasks: [DownloadTask], subtitleSelection: SubtitleSelection?, audioSelection: AudioSelection?) {
        let newStatus: DownloadStatus = isAllPaused ? .paused : .pending

        for task in tasks {
            task.subtitleSelection = subtitleSelection
            task.audioSelection = audioSelection
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
                let pendingTasks = tasks.filter { $0.status == .pending }.prefix(availableSlots)

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
            NotificationService.shared.sendAllDownloadsCompleteNotification(count: completedCount)
        }
    }

    /// 下載單一任務
    private func downloadSingleTask(_ task: DownloadTask) async {
        task.status = .downloading
        task.progress = 0

        do {
            let outputPath = try await YTDLPService.shared.download(
                taskId: task.id,
                url: task.url,
                commandTemplate: downloadCommand,
                outputDirectory: downloadFolder,
                subtitleSelection: task.subtitleSelection,
                audioSelection: task.audioSelection
            ) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                }
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
            NotificationService.shared.sendDownloadCompleteNotification(
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
            if let premiereDate = PremiereErrorParser.parsePremiereDate(from: errorMsg) {
                task.status = .scheduled
                task.premiereDate = premiereDate
                task.errorMessage = errorMsg
            } else {
                task.status = .failed
                task.errorMessage = errorMsg

                // 發送失敗通知
                NotificationService.shared.sendDownloadFailedNotification(
                    title: task.title,
                    error: errorMsg
                )
            }
        }

        // 儲存任務
        persistenceService.saveTasks(tasks)
    }

    /// 取消任務
    func cancelTask(_ task: DownloadTask) {
        if task.status == .downloading {
            Task {
                await YTDLPService.shared.cancel(taskId: task.id)
            }
        }

        task.status = .cancelled
        persistenceService.saveTasks(tasks)
    }

    /// 移除任務
    func removeTask(_ task: DownloadTask) async {
        if task.status == .downloading {
            await YTDLPService.shared.cancel(taskId: task.id)
        }

        tasks.removeAll { $0.id == task.id }
        persistenceService.saveTasks(tasks)
    }

    /// 重試任務
    func retryTask(_ task: DownloadTask) {
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
            await YTDLPService.shared.cancel(taskId: task.id)
        }

        tasks.removeAll()
        persistenceService.clearTasks()
    }

    /// 暫停全部下載
    func pauseAll() async {
        isAllPaused = true

        // 暫停所有正在下載的任務
        for task in tasks where task.status == .downloading {
            await YTDLPService.shared.cancel(taskId: task.id)
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
            await YTDLPService.shared.cancel(taskId: task.id)
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

    /// 驗證 YouTube URL
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

    /// 在 Finder 中顯示檔案
    func showInFinder(_ task: DownloadTask) {
        guard let path = task.outputPath else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}
