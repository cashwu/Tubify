import Foundation

/// 代表一個字幕軌道
struct SubtitleTrack: Codable, Identifiable, Hashable {
    var id: String { languageCode }
    let languageCode: String   // e.g., "zh-TW", "en"
    let languageName: String   // e.g., "繁體中文", "English"

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
