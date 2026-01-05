import Foundation

/// 下載任務的狀態
enum DownloadStatus: String, Codable {
    case pending = "pending"           // 等待中
    case fetchingInfo = "fetchingInfo" // 獲取資訊中
    case downloading = "downloading"   // 下載中
    case paused = "paused"             // 已暫停
    case completed = "completed"       // 完成
    case failed = "failed"             // 失敗
    case cancelled = "cancelled"       // 已取消
    case scheduled = "scheduled"       // 尚未首播

    var displayText: String {
        switch self {
        case .pending: return "等待中"
        case .fetchingInfo: return "獲取資訊中..."
        case .downloading: return "下載中"
        case .paused: return "已暫停"
        case .completed: return "完成"
        case .failed: return "失敗"
        case .cancelled: return "已取消"
        case .scheduled: return "尚未首播"
        }
    }
}

/// 下載任務模型
@Observable
class DownloadTask: Identifiable, Codable {
    let id: UUID
    let url: String
    var title: String
    var thumbnailURL: String?
    var status: DownloadStatus
    var progress: Double // 0.0 - 1.0
    var errorMessage: String?
    var outputPath: String?
    var createdAt: Date
    var completedAt: Date?
    var premiereDate: Date?  // 首播時間（僅適用於 scheduled 狀態）

    enum CodingKeys: String, CodingKey {
        case id, url, title, thumbnailURL, status, progress
        case errorMessage, outputPath, createdAt, completedAt, premiereDate
    }

    init(
        id: UUID = UUID(),
        url: String,
        title: String = "載入中...",
        thumbnailURL: String? = nil,
        status: DownloadStatus = .pending,
        progress: Double = 0.0,
        errorMessage: String? = nil,
        outputPath: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        premiereDate: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
        self.outputPath = outputPath
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.premiereDate = premiereDate
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        status = try container.decode(DownloadStatus.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        outputPath = try container.decodeIfPresent(String.self, forKey: .outputPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        premiereDate = try container.decodeIfPresent(Date.self, forKey: .premiereDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(status, forKey: .status)
        try container.encode(progress, forKey: .progress)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(outputPath, forKey: .outputPath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(premiereDate, forKey: .premiereDate)
    }
}

extension DownloadTask: Equatable {
    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.id == rhs.id
    }
}

extension DownloadTask: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
