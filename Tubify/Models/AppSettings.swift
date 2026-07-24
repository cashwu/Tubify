import Foundation

/// App 設定常數
enum AppSettingsKeys {
    static let downloadCommand = "downloadCommand"
    static let downloadFolder = "downloadFolder"
    static let maxConcurrentDownloads = "maxConcurrentDownloads"
    static let autoRemoveCompleted = "autoRemoveCompleted"
}

/// App 預設設定值
enum AppSettingsDefaults {
    // 使用 Safari cookies 下載（需要完整磁碟存取權限）
    // 格式選擇器刻意不限定 vcodec：YouTube 偶爾會出現特定編碼的串流在伺服器端損壞
    // （連線在固定 byte offset 被切斷、Range 續傳無效），而 yt-dlp 的 "/" 回退只在
    // 格式「不存在」時生效，對「格式存在但下載失敗」無效。放寬編碼可讓 av01/vp9
    // 的同解析度串流成為可選項，避免被單一損壞格式卡死。
    static let downloadCommand = "yt-dlp -f \"bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b\" --merge-output-format mp4 --cookies-from-browser safari \"$youtubeUrl\""
    // 非 YouTube 網址使用的通用下載指令（固定常數，不可由使用者編輯）。
    // 結構與 downloadCommand 相同，僅 -f 格式選擇器改為通用值，以涵蓋 yt-dlp 支援的其他網站。
    static let genericDownloadCommand = "yt-dlp -f \"bv*+ba/b\" --cookies-from-browser safari \"$youtubeUrl\""
    static let downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    static let maxConcurrentDownloads: Int = 2 // 最大同時下載數量（1-5）
    static let autoRemoveCompleted: Bool = false // 下載完成後保留在列表中
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
