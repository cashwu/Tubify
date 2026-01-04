import Foundation

/// App 設定常數
enum AppSettingsKeys {
    static let downloadCommand = "downloadCommand"
    static let downloadFolder = "downloadFolder"
    static let maxConcurrentDownloads = "maxConcurrentDownloads"
}

/// App 預設設定值
enum AppSettingsDefaults {
    // 使用 Safari cookies 下載（需要完整磁碟存取權限）
    static let downloadCommand = "yt-dlp -f \"bv[ext=mp4]+ba[ext=m4a]/b[ext=mp4]\" --cookies-from-browser safari \"$youtubeUrl\""
    static let downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    static let maxConcurrentDownloads: Int = 2 // 最大同時下載數量（1-5）
}

/// 下載相關常數
enum DownloadConstants {
    /// 啟動每個新下載前的等待秒數（避免被 YouTube 限制）
    static let preStartDelay: Double = 1.0
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
