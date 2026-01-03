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
            process.waitUntilExit()
        } catch {
            throw MetadataError.fetchFailed(error.localizedDescription)
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知錯誤"
            throw MetadataError.fetchFailed(errorMessage)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

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
            process.waitUntilExit()
        } catch {
            throw MetadataError.fetchFailed(error.localizedDescription)
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知錯誤"
            throw MetadataError.fetchFailed(errorMessage)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

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
}
