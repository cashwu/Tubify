import Foundation
import SwiftUI

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

        // 如果有待處理的任務，開始下載
        if tasks.contains(where: { $0.status == .pending }) {
            startDownloadQueue()
        }
    }

    /// 新增 URL 到下載佇列
    func addURL(_ urlString: String) {
        // 驗證 URL
        guard isValidYouTubeURL(urlString) else {
            TubifyLogger.download.error("無效的 YouTube URL: \(urlString)")
            return
        }

        // 檢查是否已存在
        if tasks.contains(where: { $0.url == urlString }) {
            TubifyLogger.download.info("URL 已在佇列中: \(urlString)")
            return
        }

        Task {
            await processURL(urlString)
        }
    }

    /// 處理 URL（單一影片或播放清單）
    private func processURL(_ urlString: String) async {
        let metadataService = YouTubeMetadataService.shared

        if await metadataService.isPlaylist(url: urlString) {
            // 處理播放清單
            await processPlaylist(urlString)
        } else {
            // 處理單一影片
            await processSingleVideo(urlString)
        }

        // 儲存任務
        PersistenceService.shared.saveTasks(tasks)

        // 開始下載
        startDownloadQueue()
    }

    /// 處理單一影片
    private func processSingleVideo(_ urlString: String) async {
        let task = DownloadTask(url: urlString)
        tasks.append(task)

        task.status = .fetchingInfo

        // 從下載命令中提取 cookies 參數
        let cookiesArgs = await YouTubeMetadataService.shared.extractCookiesArguments(from: downloadCommand)

        do {
            let videoInfo = try await YouTubeMetadataService.shared.fetchVideoInfo(url: urlString, cookiesArguments: cookiesArgs)
            task.title = videoInfo.title
            task.thumbnailURL = videoInfo.thumbnail
            task.status = .pending
        } catch {
            task.title = "無法獲取標題"
            task.status = .pending

            // 嘗試從 URL 提取 video ID 來獲取縮圖
            if let videoId = await YouTubeMetadataService.shared.extractVideoId(from: urlString) {
                task.thumbnailURL = await YouTubeMetadataService.shared.getThumbnailURL(videoId: videoId)
            }
        }
    }

    /// 處理播放清單
    private func processPlaylist(_ urlString: String) async {
        // 從下載命令中提取 cookies 參數
        let cookiesArgs = await YouTubeMetadataService.shared.extractCookiesArguments(from: downloadCommand)

        do {
            let videos = try await YouTubeMetadataService.shared.fetchPlaylistInfo(url: urlString, cookiesArguments: cookiesArgs)

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

            // 即使獲取播放清單失敗，也新增一個任務
            let task = DownloadTask(url: urlString, title: "播放清單（無法獲取詳細資訊）")
            tasks.append(task)
        }
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

            if availableSlots > 0 {
                // 取得待處理的任務
                let pendingTasks = tasks.filter { $0.status == .pending }.prefix(availableSlots)

                for task in pendingTasks {
                    currentTasks.insert(task.id)

                    // 啟動下載任務（不等待完成）
                    Task {
                        await self.downloadSingleTask(task)

                        // 下載完成後從 currentTasks 移除
                        _ = await MainActor.run {
                            self.currentTasks.remove(task.id)
                        }

                        // 等待間隔時間後觸發下一個
                        try? await Task.sleep(for: .seconds(self.downloadInterval))

                        // 繼續處理佇列
                        await MainActor.run {
                            if self.downloadTask == nil && self.tasks.contains(where: { $0.status == .pending }) {
                                self.startDownloadQueue()
                            }
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
    func removeTask(_ task: DownloadTask) {
        if task.status == .downloading {
            Task {
                await YTDLPService.shared.cancel(taskId: task.id)
            }
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
    func clearAllTasks() {
        // 取消所有進行中的下載
        for task in tasks where task.status == .downloading {
            Task {
                await YTDLPService.shared.cancel(taskId: task.id)
            }
        }

        tasks.removeAll()
        PersistenceService.shared.clearTasks()
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
