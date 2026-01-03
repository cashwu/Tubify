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

    /// 目前下載中的任務
    var currentTask: DownloadTask?

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

        do {
            let videoInfo = try await YouTubeMetadataService.shared.fetchVideoInfo(url: urlString)
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
        do {
            let videos = try await YouTubeMetadataService.shared.fetchPlaylistInfo(url: urlString)

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

        while let task = tasks.first(where: { $0.status == .pending }) {
            currentTask = task
            await downloadTask(task)

            // 等待間隔時間
            if tasks.contains(where: { $0.status == .pending }) {
                try? await Task.sleep(for: .seconds(downloadInterval))
            }
        }

        currentTask = nil
        isDownloading = false
        downloadTask = nil

        // 所有下載完成
        let completedCount = tasks.filter { $0.status == .completed }.count
        if completedCount > 0 {
            NotificationService.shared.sendAllDownloadsCompleteNotification(count: completedCount)
        }
    }

    /// 下載單一任務
    private func downloadTask(_ task: DownloadTask) async {
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
