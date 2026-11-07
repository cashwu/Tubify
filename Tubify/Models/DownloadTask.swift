import Foundation

/// 下載任務的狀態
enum DownloadStatus: String, Codable {
    case pending = "pending"           // 等待中
    case fetchingInfo = "fetchingInfo" // 獲取資訊中
    case waitingForMediaSelection = "waitingForMediaSelection" // 等待選擇媒體選項（字幕/音軌）
    case downloading = "downloading"   // 下載中
    case paused = "paused"             // 已暫停
    case completed = "completed"       // 完成
    case failed = "failed"             // 失敗
    case cancelled = "cancelled"       // 已取消
    case scheduled = "scheduled"       // 尚未首播
    case livestreaming = "livestreaming" // 首播串流中
    case postLive = "postLive"         // 直播處理中

    var displayText: String {
        switch self {
        case .pending: return "等待中"
        case .fetchingInfo: return "獲取資訊中..."
        case .waitingForMediaSelection: return "等待選擇下載選項"
        case .downloading: return "下載中"
        case .paused: return "已暫停"
        case .completed: return "完成"
        case .failed: return "失敗"
        case .cancelled: return "已取消"
        case .scheduled: return "尚未首播"
        case .livestreaming: return "首播串流中"
        case .postLive: return "直播處理中"
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
    var availableSubtitles: [SubtitleTrack]?  // 可用的字幕列表
    var subtitleSelection: SubtitleSelection?  // 用戶選擇的字幕
    var availableAudioTracks: [AudioTrack]?   // 可用的音軌列表
    var audioSelection: AudioSelection?        // 用戶選擇的音軌
    var duration: Int?  // 影片時長（秒）
    var callbackScheme: String?  // 下載完成後的回調 Scheme（例如 "whispify"）
    var requestId: String?  // 請求識別碼，回調時原樣帶回給呼叫方
    var expectedEndTime: Date?  // 首播預計播放完成時間（僅適用於 livestreaming 狀態）
    var wasLive: Bool = false  // 曾為首播／直播（下載完成後需比對長度，避免把串流片段當成完整影片）
    /// 使用者自訂的名稱；有值時清單優先顯示，下載完成後也用它命名檔案。
    /// 與元資料標題（title）分開保存，元資料抓取只寫 title，因此不會覆蓋使用者的名稱（R5）
    var customTitle: String?
    /// outputPath 指向的檔案是否屬於本任務（實際下載產生或複製出來的）。
    /// false 表示 yt-dlp 沿用了既有的同名檔，改名時只能複製、不能動原檔（R10）。
    /// nil 為 App 更新前完成、沒有來源記錄的舊任務，視為屬於本任務（R12）
    var ownsOutputFile: Bool?

    enum CodingKeys: String, CodingKey {
        case id, url, title, thumbnailURL, status, progress
        case errorMessage, outputPath, createdAt, completedAt, premiereDate
        case availableSubtitles, subtitleSelection
        case availableAudioTracks, audioSelection
        case duration, callbackScheme, requestId, expectedEndTime, wasLive
        case customTitle, ownsOutputFile
    }

    /// 播放清單展開前的佔位任務標題；復原流程靠它判斷要重新展開播放清單
    static let playlistPlaceholderTitle = "載入播放清單中..."

    /// 清單顯示的名稱
    var displayTitle: String { customTitle ?? title }

    var isOutputFileOwned: Bool { ownsOutputFile ?? true }

    /// 播放清單佔位任務展開後會被個別影片任務取代，改名沒有意義（R1）
    var isRenamable: Bool { title != Self.playlistPlaceholderTitle }

    /// 把改名視窗的輸入整理成新名稱；空白或與目前顯示名稱相同時回傳 nil，代表沒有變更（R3）
    func renameCandidate(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != displayTitle else { return nil }
        return trimmed
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
        premiereDate: Date? = nil,
        availableSubtitles: [SubtitleTrack]? = nil,
        subtitleSelection: SubtitleSelection? = nil,
        availableAudioTracks: [AudioTrack]? = nil,
        audioSelection: AudioSelection? = nil,
        duration: Int? = nil,
        callbackScheme: String? = nil,
        requestId: String? = nil,
        expectedEndTime: Date? = nil
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
        self.availableSubtitles = availableSubtitles
        self.subtitleSelection = subtitleSelection
        self.availableAudioTracks = availableAudioTracks
        self.audioSelection = audioSelection
        self.duration = duration
        self.callbackScheme = callbackScheme
        self.requestId = requestId
        self.expectedEndTime = expectedEndTime
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
        availableSubtitles = try container.decodeIfPresent([SubtitleTrack].self, forKey: .availableSubtitles)
        subtitleSelection = try container.decodeIfPresent(SubtitleSelection.self, forKey: .subtitleSelection)
        availableAudioTracks = try container.decodeIfPresent([AudioTrack].self, forKey: .availableAudioTracks)
        audioSelection = try container.decodeIfPresent(AudioSelection.self, forKey: .audioSelection)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        callbackScheme = try container.decodeIfPresent(String.self, forKey: .callbackScheme)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        expectedEndTime = try container.decodeIfPresent(Date.self, forKey: .expectedEndTime)
        wasLive = try container.decodeIfPresent(Bool.self, forKey: .wasLive) ?? false
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
        ownsOutputFile = try container.decodeIfPresent(Bool.self, forKey: .ownsOutputFile)
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
        try container.encodeIfPresent(availableSubtitles, forKey: .availableSubtitles)
        try container.encodeIfPresent(subtitleSelection, forKey: .subtitleSelection)
        try container.encodeIfPresent(availableAudioTracks, forKey: .availableAudioTracks)
        try container.encodeIfPresent(audioSelection, forKey: .audioSelection)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(callbackScheme, forKey: .callbackScheme)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encodeIfPresent(expectedEndTime, forKey: .expectedEndTime)
        try container.encode(wasLive, forKey: .wasLive)
        try container.encodeIfPresent(customTitle, forKey: .customTitle)
        try container.encodeIfPresent(ownsOutputFile, forKey: .ownsOutputFile)
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
