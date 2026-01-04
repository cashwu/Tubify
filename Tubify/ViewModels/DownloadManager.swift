import Foundation
import SwiftUI

/// URL 驗證結果
enum URLValidationResult {
    case success
    case invalidFormat      // 格式不正確（如 markdown 連結）
    case notYouTubeURL     // 非 YouTube 網址
    case alreadyExists     // 已在佇列中
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

    /// 目前下載中的任務（支援同時多個）
    var currentTasks: Set<UUID> = []

    /// 設定（使用 UserDefaults 直接讀取，避免與 @Observable 衝突）
    var downloadCommand: String {
        get { UserDefaults.standard.string(forKey: AppSettingsKeys.downloadCommand) ?? AppSettingsDefaults.downloadCommand }
        set { UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.downloadCommand) }
    }

    var downloadFolder: String {
        get { UserDefaults.standard.string(forKey: AppSettingsKeys.downloadFolder) ?? AppSettingsDefaults.downloadFolder }
        set { UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.downloadFolder) }
    }

    var downloadInterval: Double {
        get { UserDefaults.standard.double(forKey: AppSettingsKeys.downloadInterval).nonZeroOrDefault(AppSettingsDefaults.downloadInterval) }
        set { UserDefaults.standard.set(newValue, forKey: AppSettingsKeys.downloadInterval) }
    }

    var maxConcurrentDownloads: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: AppSettingsKeys.maxConcurrentDownloads).nonZeroOrDefault(AppSettingsDefaults.maxConcurrentDownloads)
            return min(max(value, 1), 5) // 限制在 1-5 之間
        }
        set { UserDefaults.standard.set(min(max(newValue, 1), 5), forKey: AppSettingsKeys.maxConcurrentDownloads) }
    }

    private var downloadTask: Task<Void, Never>?

    private init() {
        // 載入已儲存的任務
        tasks = PersistenceService.shared.loadTasks()

        // 處理卡在 fetchingInfo 狀態的任務（可能是上次啟動時中斷的）
        for task in tasks where task.status == .fetchingInfo {
            TubifyLogger.download.info("重置卡住的任務: \(task.url)")
            task.status = .pending
            if task.title == "載入中..." {
                task.title = "無法獲取標題"
            }
        }

        // 如果有待處理的任務，開始下載
        if tasks.contains(where: { $0.status == .pending }) {
            PersistenceService.shared.saveTasks(tasks)
            startDownloadQueue()
        }
    }

    /// 新增 URL 到下載佇列
    @discardableResult
    func addURL(_ urlString: String) -> URLValidationResult {
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
            tasks.append(task)
            PersistenceService.shared.saveTasks(tasks)

            Task {
                await expandPlaylist(placeholderTask: task, urlString: urlString)
            }
        } else {
            // 單一影片：先同步建立任務並加入列表
            let task = DownloadTask(url: urlString)
            task.status = .fetchingInfo

            // 使用靜態方法提取 video ID 來獲取縮圖（不需要 await）
            if let videoId = YouTubeMetadataService.extractVideoIdSync(from: urlString) {
                task.thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
            }

            tasks.append(task)
            PersistenceService.shared.saveTasks(tasks)

            // 異步獲取資訊（不阻塞新 URL 的加入）
            Task {
                await fetchMetadataForTask(task)
            }
        }

        return .success
    }

    /// 獲取單一影片的元資料
    private func fetchMetadataForTask(_ task: DownloadTask) async {
        TubifyLogger.download.info("獲取影片元資料: \(task.url)")
        let metadataService = YouTubeMetadataService.shared

        // 注意：不使用 cookies 來獲取元資料，因為：
        // 1. 公開影片不需要認證就可以獲取元資料
        // 2. 使用 Safari cookies 需要 Full Disk Access 權限，沒有權限會導致 yt-dlp 無限期掛起
        // 3. Cookies 只在下載時使用（下載私人影片時）

        do {
            let videoInfo = try await metadataService.fetchVideoInfo(url: task.url, cookiesArguments: [])
            TubifyLogger.download.info("成功獲取影片資訊: \(videoInfo.title)")
            task.title = videoInfo.title
            task.thumbnailURL = videoInfo.thumbnail
            task.status = .pending
        } catch {
            TubifyLogger.download.error("獲取影片資訊失敗: \(error.localizedDescription)")
            task.title = "無法獲取標題"
            task.status = .pending
        }

        PersistenceService.shared.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 展開播放清單
    private func expandPlaylist(placeholderTask: DownloadTask, urlString: String) async {
        let metadataService = YouTubeMetadataService.shared

        // 注意：不使用 cookies 來獲取播放清單元資料（原因同 fetchMetadataForTask）

        do {
            let videos = try await metadataService.fetchPlaylistInfo(url: urlString, cookiesArguments: [])

            // 移除佔位任務
            tasks.removeAll { $0.id == placeholderTask.id }

            for video in videos {
                // 檢查是否已存在
                if tasks.contains(where: { $0.url == video.url }) {
                    continue
                }

                let task = DownloadTask(
                    url: video.url,
                    title: video.title,
                    thumbnailURL: video.thumbnail
                )
                tasks.append(task)
            }

            TubifyLogger.download.info("已新增播放清單中的 \(videos.count) 個影片")
        } catch {
            TubifyLogger.download.error("處理播放清單失敗: \(error.localizedDescription)")

            // 播放清單獲取失敗，將佔位任務轉為可下載狀態
            placeholderTask.title = "播放清單（無法獲取詳細資訊）"
            placeholderTask.status = .pending
        }

        PersistenceService.shared.saveTasks(tasks)
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

            if availableSlots > 0 {
                // 取得待處理的任務
                let pendingTasks = tasks.filter { $0.status == .pending }.prefix(availableSlots)

                TubifyLogger.download.debug("準備啟動 \(pendingTasks.count) 個下載任務")

                var isFirstTask = true
                for task in pendingTasks {
                    // 啟動新任務前等待間隔（第一個任務不等，避免不必要的延遲）
                    if !isFirstTask && downloadInterval > 0 {
                        TubifyLogger.download.debug("等待 \(self.downloadInterval) 秒後啟動下一個任務")
                        try? await Task.sleep(for: .seconds(downloadInterval))
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
                outputDirectory: downloadFolder
            ) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                    LogFileManager.shared.logDownloadProgress(taskId: task?.id ?? UUID(), progress: progress)
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
        } catch {
            task.status = .failed
            task.errorMessage = error.localizedDescription

            // 發送失敗通知
            NotificationService.shared.sendDownloadFailedNotification(
                title: task.title,
                error: error.localizedDescription
            )
        }

        // 儲存任務
        PersistenceService.shared.saveTasks(tasks)
    }

    /// 取消任務
    func cancelTask(_ task: DownloadTask) {
        if task.status == .downloading {
            Task {
                await YTDLPService.shared.cancel(taskId: task.id)
            }
        }

        task.status = .cancelled
        PersistenceService.shared.saveTasks(tasks)
    }

    /// 移除任務
    func removeTask(_ task: DownloadTask) async {
        if task.status == .downloading {
            await YTDLPService.shared.cancel(taskId: task.id)
        }

        tasks.removeAll { $0.id == task.id }
        PersistenceService.shared.saveTasks(tasks)
    }

    /// 重試任務
    func retryTask(_ task: DownloadTask) {
        task.status = .pending
        task.progress = 0
        task.errorMessage = nil
        PersistenceService.shared.saveTasks(tasks)
        startDownloadQueue()
    }

    /// 清除已完成的任務
    func clearCompletedTasks() {
        tasks.removeAll { $0.status == .completed }
        PersistenceService.shared.saveTasks(tasks)
    }

    /// 清除所有任務
    func clearAllTasks() async {
        // 取消所有進行中的下載
        let downloadingTasks = tasks.filter { $0.status == .downloading }
        for task in downloadingTasks {
            await YTDLPService.shared.cancel(taskId: task.id)
        }

        tasks.removeAll()
        PersistenceService.shared.clearTasks()
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
