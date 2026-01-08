import Foundation

/// 代表一個音軌
struct AudioTrack: Codable, Identifiable, Hashable {
    var id: String { languageCode }
    let languageCode: String   // e.g., "ja", "en"
    let languageName: String   // e.g., "日文", "English"

    /// 重用字幕的語言過濾邏輯
    static func isSupportedLanguage(_ code: String) -> Bool {
        LanguageFilter.isSupportedLanguage(code)
    }

    static func languageName(for code: String) -> String {
        LanguageFilter.languageName(for: code)
    }

    init(languageCode: String, languageName: String? = nil) {
        self.languageCode = languageCode
        self.languageName = languageName ?? Self.languageName(for: languageCode)
    }
}

/// 用戶的音軌選擇（單選）
struct AudioSelection: Codable {
    let selectedLanguage: String?  // nil 表示使用預設音軌

    init(selectedLanguage: String?) {
        self.selectedLanguage = selectedLanguage
    }
}
