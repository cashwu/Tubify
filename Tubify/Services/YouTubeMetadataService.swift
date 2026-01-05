import Foundation

/// 影片資訊
struct VideoInfo: Codable {
    let id: String
    let title: String
    let thumbnail: String?
    let duration: Int?
    let uploader: String?
    let url: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnail
        case duration
        case uploader
        case url = "webpage_url"
    }
}

/// 播放清單資訊
struct PlaylistInfo: Codable {
    let id: String
    let title: String
    let entries: [PlaylistEntry]?

    struct PlaylistEntry: Codable {
        let id: String
        let title: String?
        let url: String?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case url
        }
    }
}

/// YouTube Metadata 服務錯誤
enum MetadataError: Error, LocalizedError {
    case ytdlpNotFound
    case fetchFailed(String)
    case parseError
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .ytdlpNotFound:
            return "找不到 yt-dlp"
        case .fetchFailed(let message):
            return "獲取資訊失敗: \(message)"
        case .parseError:
            return "解析資訊失敗"
        case .invalidURL:
            return "無效的 URL"
        }
    }
}

/// YouTube Metadata 服務
actor YouTubeMetadataService {
    static let shared = YouTubeMetadataService()

    private init() {}

    /// 檢查 URL 是否為播放清單
    func isPlaylist(url: String) -> Bool {
        return url.contains("list=") || url.contains("/playlist")
    }

    /// 獲取單一影片資訊
    func fetchVideoInfo(url: String, cookiesArguments: [String] = []) async throws -> VideoInfo {
        guard let ytdlpPath = await YTDLPService.shared.findYTDLPPath() else {
            throw MetadataError.ytdlpNotFound
        }

        TubifyLogger.ytdlp.info("獲取影片資訊: \(url)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        process.arguments = ["-J", "--no-playlist"] + cookiesArguments + [url]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw MetadataError.fetchFailed(error.localizedDescription)
        }

        // 在背景讀取 stdout（避免管道緩衝區滿導致死鎖）
        // 如果不先讀取數據，當 yt-dlp 輸出超過管道緩衝區（約 64KB）時會阻塞
        let outputHandle = pipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        // 使用異步方式讀取數據
        let outputData = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global().async {
                let data = outputHandle.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }

        let errorData = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global().async {
                let data = errorHandle.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }

        // 等待程序結束
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let resumeOnce = {
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }

            process.terminationHandler = { _ in
                resumeOnce()
            }

            if !process.isRunning {
                resumeOnce()
            }
        }

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知錯誤"
            throw MetadataError.fetchFailed(errorMessage)
        }

        let data = outputData

        do {
            let decoder = JSONDecoder()
            let videoInfo = try decoder.decode(VideoInfo.self, from: data)
            TubifyLogger.ytdlp.info("成功獲取影片資訊: \(videoInfo.title)")
            return videoInfo
        } catch {
            TubifyLogger.ytdlp.error("解析影片資訊失敗: \(error.localizedDescription)")
            throw MetadataError.parseError
        }
    }

    /// 獲取播放清單資訊
    func fetchPlaylistInfo(url: String, cookiesArguments: [String] = []) async throws -> [VideoInfo] {
        guard let ytdlpPath = await YTDLPService.shared.findYTDLPPath() else {
            throw MetadataError.ytdlpNotFound
        }

        TubifyLogger.ytdlp.info("獲取播放清單資訊: \(url)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlpPath)
        process.arguments = ["--flat-playlist", "-J"] + cookiesArguments + [url]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw MetadataError.fetchFailed(error.localizedDescription)
        }

        // 在背景讀取 stdout（避免管道緩衝區滿導致死鎖）
        let outputHandle = pipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        let outputData = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global().async {
                let data = outputHandle.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }

        let errorData = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global().async {
                let data = errorHandle.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }

        // 等待程序結束
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let resumeOnce = {
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }

            process.terminationHandler = { _ in
                resumeOnce()
            }

            if !process.isRunning {
                resumeOnce()
            }
        }

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知錯誤"
            throw MetadataError.fetchFailed(errorMessage)
        }

        let data = outputData

        do {
            let decoder = JSONDecoder()
            let playlistInfo = try decoder.decode(PlaylistInfo.self, from: data)

            guard let entries = playlistInfo.entries else {
                return []
            }

            TubifyLogger.ytdlp.info("成功獲取播放清單: \(playlistInfo.title), 共 \(entries.count) 個影片")

            // 轉換為 VideoInfo 陣列
            return entries.compactMap { entry -> VideoInfo? in
                let videoURL = entry.url ?? "https://www.youtube.com/watch?v=\(entry.id)"
                return VideoInfo(
                    id: entry.id,
                    title: entry.title ?? "未知標題",
                    thumbnail: "https://i.ytimg.com/vi/\(entry.id)/mqdefault.jpg",
                    duration: nil,
                    uploader: nil,
                    url: videoURL
                )
            }
        } catch {
            TubifyLogger.ytdlp.error("解析播放清單資訊失敗: \(error.localizedDescription)")
            throw MetadataError.parseError
        }
    }

    /// 獲取縮圖 URL
    func getThumbnailURL(videoId: String) -> String {
        return "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
    }

    /// 從下載命令中提取 cookies 相關參數
    func extractCookiesArguments(from commandTemplate: String) -> [String] {
        var arguments: [String] = []

        // 檢查 --cookies-from-browser
        if let range = commandTemplate.range(of: #"--cookies-from-browser[=\s]+(\w+)"#, options: .regularExpression) {
            let match = String(commandTemplate[range])
            // 轉換為標準格式
            if match.contains("=") {
                arguments.append(match)
            } else {
                // --cookies-from-browser safari → --cookies-from-browser=safari
                let parts = match.split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    arguments.append("--cookies-from-browser")
                    arguments.append(String(parts[1]))
                }
            }
        }

        // 檢查 --cookies (cookies 檔案路徑)
        if let range = commandTemplate.range(of: #"--cookies[=\s]+[^\s]+"#, options: .regularExpression) {
            let match = String(commandTemplate[range])
            if match.contains("=") {
                arguments.append(match)
            } else {
                let parts = match.split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    arguments.append("--cookies")
                    arguments.append(String(parts[1]))
                }
            }
        }

        return arguments
    }

    /// 從 URL 提取影片 ID
    func extractVideoId(from url: String) -> String? {
        Self.extractVideoIdSync(from: url)
    }

    /// 從 URL 提取影片 ID（靜態方法，不需要 actor 隔離）
    static func extractVideoIdSync(from url: String) -> String? {
        // 支援多種 YouTube URL 格式
        let patterns = [
            #"(?:v=|\/)([\w-]{11})(?:\?|&|$)"#,
            #"youtu\.be\/([\w-]{11})"#,
            #"embed\/([\w-]{11})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        return nil
    }

    /// 檢查 URL 是否為播放清單（靜態方法，不需要 actor 隔離）
    static func isPlaylistSync(url: String) -> Bool {
        url.contains("list=") || url.contains("/playlist")
    }

    /// 從 YouTube 網頁直接獲取標題（用於首播影片等 yt-dlp 無法獲取的情況）
    func fetchTitleFromWebpage(url: String) async -> String? {
        guard let requestURL = URL(string: url) else {
            return nil
        }

        // 必須設置 User-Agent，否則 YouTube 會返回簡化頁面（標題只有 "YouTube"）
        var request = URLRequest(url: requestURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("zh-TW,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            // 解析 <title>...</title> 標籤
            let pattern = #"<title>([^<]+)</title>"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let titleRange = Range(match.range(at: 1), in: html) else {
                return nil
            }

            var title = String(html[titleRange])

            // 移除 " - YouTube" 後綴
            if title.hasSuffix(" - YouTube") {
                title = String(title.dropLast(10))
            }

            TubifyLogger.download.info("從網頁獲取標題成功: \(title)")
            return title.isEmpty ? nil : title
        } catch {
            TubifyLogger.download.error("從網頁獲取標題失敗: \(error.localizedDescription)")
            return nil
        }
    }
}
