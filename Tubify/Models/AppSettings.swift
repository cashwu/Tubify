import Foundation

/// App 設定常數
enum AppSettingsKeys {
    static let downloadCommand = "downloadCommand"
    static let downloadFolder = "downloadFolder"
    static let downloadInterval = "downloadInterval"
    static let maxConcurrentDownloads = "maxConcurrentDownloads"
}

/// App 預設設定值
enum AppSettingsDefaults {
    // 使用 Safari cookies 下載（需要完整磁碟存取權限）
    // 使用 -S ext:mp4 以獲得最佳 mp4 品質
    static let downloadCommand = "yt-dlp -S ext:mp4 --cookies-from-browser safari \"$youtubeUrl\""
    static let downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    static let downloadInterval: Double = 2.0 // 秒
    static let maxConcurrentDownloads: Int = 2 // 最大同時下載數量（1-5）
}

/// Double extension for UserDefaults handling
extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

/// Int extension for UserDefaults handling
extension Int {
    func nonZeroOrDefault(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}
