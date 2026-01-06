import Foundation

/// 代表一個字幕軌道
struct SubtitleTrack: Codable, Identifiable, Hashable {
    var id: String { languageCode }
    let languageCode: String   // e.g., "zh-TW", "en"
    let languageName: String   // e.g., "繁體中文", "English"

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

    init(languageCode: String, languageName: String? = nil) {
        self.languageCode = languageCode
        self.languageName = languageName ?? Self.languageName(for: languageCode)
    }
}

/// 用戶的字幕選擇
struct SubtitleSelection: Codable {
    let selectedLanguages: [String]  // 選擇的語言代碼

    init(selectedLanguages: [String]) {
        self.selectedLanguages = selectedLanguages
    }
}
