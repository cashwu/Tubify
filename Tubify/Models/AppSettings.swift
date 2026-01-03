import Foundation

/// App 設定常數
enum AppSettingsKeys {
    static let downloadCommand = "downloadCommand"
    static let downloadFolder = "downloadFolder"
    static let downloadInterval = "downloadInterval"
}

/// App 預設設定值
enum AppSettingsDefaults {
    static let downloadCommand = "yt-dlp -f mp4 --cookies-from-browser safari \"$youtubeUrl\""
    static let downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    static let downloadInterval: Double = 2.0 // 秒
}

/// Double extension for UserDefaults handling
extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
