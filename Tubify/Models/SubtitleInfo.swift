import Foundation

/// 語言過濾工具（供字幕和音軌共用）
enum LanguageFilter {
    /// 支援下載的語言代碼前綴（英文、日文、中文）
    private static let supportedLanguagePrefixes = ["en", "ja", "zh"]

    /// 檢查語言代碼是否為支援的語言（英文、日文、中文）
    static func isSupportedLanguage(_ code: String) -> Bool {
        let baseCode = code.components(separatedBy: "-").first ?? code
        return supportedLanguagePrefixes.contains(baseCode.lowercased())
    }

    /// 從語言代碼取得顯示名稱
    static func languageName(for code: String) -> String {
        let locale = Locale(identifier: "zh-TW")
        if let name = locale.localizedString(forLanguageCode: code) {
            return name
        }
        // 處理一些 yt-dlp 特有的代碼格式
        let baseCode = code.components(separatedBy: "-").first ?? code
        return locale.localizedString(forLanguageCode: baseCode) ?? code
    }
}

/// 提供為選項的 YouTube 自動字幕語言（yt-dlp `automatic_captions`）
enum AutomaticCaptionTarget: String, CaseIterable {
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var languageName: String {
        switch self {
        case .traditionalChinese: "繁體中文"
        case .english: "英文"
        }
    }

    /// 由 yt-dlp key 判斷目標語言：`zh-Hant`、`zh-Hant-en`（由上傳英文字幕翻譯）、`en`、`en-ja` 等
    init?(captionKey: String) {
        guard let target = Self.allCases.first(where: {
            captionKey == $0.rawValue || captionKey.hasPrefix($0.rawValue + "-")
        }) else { return nil }
        self = target
    }

    /// 上傳字幕已涵蓋此語言時，不再提供自動字幕
    func isCovered(byUploadedLanguage code: String) -> Bool {
        let lowered = code.lowercased()
        switch self {
        case .traditionalChinese:
            return ["zh-hant", "zh-tw", "zh-hk", "zh-mo"].contains(lowered)
        case .english:
            return lowered == "en" || lowered.hasPrefix("en-")
        }
    }
}

/// YouTube 自動字幕的來源
enum AutomaticCaptionKind: String, Codable {
    case translated  // 由其他語言字幕機器翻譯
    case generated   // 影片原始語言的語音辨識字幕
}

/// 代表一個字幕軌道
struct SubtitleTrack: Codable, Identifiable, Hashable {
    /// YouTube 自動字幕
    /// - Parameter captionKey: yt-dlp `automatic_captions` 中的實際 key。由上傳字幕翻譯而來的 key
    ///   會帶上來源語言（例如 `zh-Hant-en`），其餘與目標語言相同（例如 `zh-Hant`、`en`）
    static func automatic(_ target: AutomaticCaptionTarget, captionKey: String, kind: AutomaticCaptionKind) -> SubtitleTrack {
        SubtitleTrack(languageCode: captionKey, languageName: target.languageName, automaticKind: kind)
    }

    /// 自動字幕的 id：不含來源語言，播放清單合併選項時各影片的同語言自動字幕才會併為同一項
    static func automaticID(captionKey: String) -> String {
        "auto:\(AutomaticCaptionTarget(captionKey: captionKey)?.rawValue ?? captionKey)"
    }

    /// 同語言的上傳字幕與自動字幕必須可區分，自動字幕以前綴區隔
    var id: String { isAutomatic ? Self.automaticID(captionKey: languageCode) : languageCode }
    let languageCode: String   // e.g., "zh-TW", "en"；自動字幕為 yt-dlp 的實際 key
    let languageName: String   // e.g., "繁體中文", "English"
    let automaticKind: AutomaticCaptionKind?  // nil 表示用戶上傳的字幕

    /// 是否為 YouTube 自動字幕
    var isAutomatic: Bool { automaticKind != nil }

    /// 顯示於選擇視窗的名稱，自動字幕會標示來源
    var displayName: String {
        switch automaticKind {
        case nil: languageName
        case .translated: "\(languageName)（YouTube 自動翻譯）"
        case .generated: "\(languageName)（YouTube 自動產生）"
        }
    }

    /// 檢查語言代碼是否為支援的語言（英文、日文、中文）
    static func isSupportedLanguage(_ code: String) -> Bool {
        LanguageFilter.isSupportedLanguage(code)
    }

    /// 從語言代碼取得顯示名稱
    static func languageName(for code: String) -> String {
        LanguageFilter.languageName(for: code)
    }

    init(languageCode: String, languageName: String? = nil, automaticKind: AutomaticCaptionKind? = nil) {
        self.languageCode = languageCode
        self.languageName = languageName ?? Self.languageName(for: languageCode)
        self.automaticKind = automaticKind
    }
}

/// 用戶的字幕選擇
struct SubtitleSelection: Codable {
    let selectedLanguages: [String]   // 選擇的上傳字幕語言代碼
    let automaticLanguages: [String]  // 選擇的 YouTube 自動字幕 key（yt-dlp automatic_captions）

    /// 上傳字幕與自動字幕的語言 key，即傳給 yt-dlp `--sub-lang` 的值，也是字幕檔名中的語言部分
    var allLanguages: [String] { selectedLanguages + automaticLanguages }

    init(selectedLanguages: [String], automaticLanguages: [String] = []) {
        self.selectedLanguages = selectedLanguages
        self.automaticLanguages = automaticLanguages
    }

    /// 從選取的字幕軌道建立；沒有選取任何軌道時回傳 nil
    init?(tracks: [SubtitleTrack]) {
        guard !tracks.isEmpty else { return nil }
        self.init(
            selectedLanguages: tracks.filter { !$0.isAutomatic }.map(\.languageCode),
            automaticLanguages: tracks.filter(\.isAutomatic).map(\.languageCode)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedLanguages = try container.decode([String].self, forKey: .selectedLanguages)
        automaticLanguages = try container.decodeIfPresent([String].self, forKey: .automaticLanguages) ?? []
    }

    /// 是否選取了該字幕軌道。自動字幕的實際 key 因影片的來源字幕而異，
    /// 播放清單合併選擇時只能表達「要不要該語言的自動字幕」，因此以 id 比對
    func contains(_ track: SubtitleTrack) -> Bool {
        track.isAutomatic
            ? automaticLanguages.contains { SubtitleTrack.automaticID(captionKey: $0) == track.id }
            : selectedLanguages.contains(track.languageCode)
    }

    /// 只保留在 tracks 中實際存在的選擇；結果為空時回傳 nil
    func restricted(to tracks: [SubtitleTrack]) -> SubtitleSelection? {
        SubtitleSelection(tracks: tracks.filter(contains))
    }

    /// 移除指定自動字幕後的選擇；沒有剩下任何字幕時回傳 nil
    func removingAutomatic(_ languages: [String]) -> SubtitleSelection? {
        let remainingAutomatic = automaticLanguages.filter { !languages.contains($0) }
        guard !selectedLanguages.isEmpty || !remainingAutomatic.isEmpty else { return nil }
        return SubtitleSelection(selectedLanguages: selectedLanguages, automaticLanguages: remainingAutomatic)
    }
}
