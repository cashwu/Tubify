import Foundation

/// App 設定常數
enum AppSettingsKeys {
    static let downloadCommand = "downloadCommand"
    static let downloadCommandVersion = "downloadCommandVersion"
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

    /// 目前 downloadCommand 預設值的版本。每次調整上面的預設指令就 +1。
    static let downloadCommandVersion = 2

    /// 歷來用過的預設下載指令。
    ///
    /// 使用者一旦打開過設定頁，`@AppStorage` 就會把當下的指令寫進 UserDefaults，
    /// 此後再改 `downloadCommand` 對他完全無效 —— 除非手動按「重置為預設值」。
    /// 遷移時只有在存下來的值與某個歷史預設「完全相同」（代表從未自訂）才自動升級，
    /// 任何自訂內容一律保留。
    static let legacyDownloadCommands: [String] = [
        "yt-dlp -f mp4 --cookies-from-browser safari \"$youtubeUrl\"",
        "yt-dlp -f \"bv[ext=mp4][vcodec^=avc]+ba[ext=m4a]/b[ext=mp4][vcodec^=avc]\" --cookies-from-browser safari \"$youtubeUrl\""
    ]
    // 非 YouTube 網址使用的通用下載指令（固定常數，不可由使用者編輯）。
    // 結構與 downloadCommand 相同，僅 -f 格式選擇器改為通用值，以涵蓋 yt-dlp 支援的其他網站。
    static let genericDownloadCommand = "yt-dlp -f \"bv*+ba/b\" --cookies-from-browser safari \"$youtubeUrl\""
    static let downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    static let maxConcurrentDownloads: Int = 2 // 最大同時下載數量（1-5）
    static let autoRemoveCompleted: Bool = false // 下載完成後保留在列表中
}

/// 設定遷移
///
/// 舊版預設指令一旦被寫進 UserDefaults，就會蓋過程式碼裡的新預設值。
/// 曾有使用者因此在 app 已更新的情況下持續套用舊的格式選擇器，
/// 踩到 YouTube 端損壞的串流卻無從察覺。此處在啟動時把「從未自訂過」的
/// 舊預設值升級到目前版本。
enum AppSettingsMigrator {
    /// 回傳遷移後應寫入的指令；nil 表示不需變更。
    ///
    /// 抽成純函式以便測試，不觸碰 UserDefaults。
    static func migratedDownloadCommand(storedCommand: String?, storedVersion: Int) -> String? {
        guard storedVersion < AppSettingsDefaults.downloadCommandVersion else { return nil }
        // 沒有存過值的話，讀取時本來就會落到新預設，無須寫入
        guard let storedCommand else { return nil }
        // 只升級未經自訂的舊預設值，使用者自己寫的指令一律保留
        guard AppSettingsDefaults.legacyDownloadCommands.contains(storedCommand) else { return nil }
        return AppSettingsDefaults.downloadCommand
    }

    /// 在 app 啟動時執行，必須早於任何讀取 downloadCommand 的程式碼。
    static func migrate(defaults: UserDefaults = .standard) {
        let storedVersion = defaults.integer(forKey: AppSettingsKeys.downloadCommandVersion)
        guard storedVersion < AppSettingsDefaults.downloadCommandVersion else { return }

        let storedCommand = defaults.string(forKey: AppSettingsKeys.downloadCommand)
        if let migrated = migratedDownloadCommand(storedCommand: storedCommand, storedVersion: storedVersion) {
            defaults.set(migrated, forKey: AppSettingsKeys.downloadCommand)
            LogFileManager.shared.writeToFile(
                "下載指令已從舊預設值升級至第 \(AppSettingsDefaults.downloadCommandVersion) 版：\(migrated)"
            )
        }
        // 無論是否實際改寫，都記下版本，避免每次啟動重複判斷
        defaults.set(AppSettingsDefaults.downloadCommandVersion, forKey: AppSettingsKeys.downloadCommandVersion)
    }
}

/// 下載相關常數
enum DownloadConstants {
    /// 啟動每個新下載前的等待秒數（避免被 YouTube 限制）
    static let preStartDelay: Double = 1.0

    /// 首播／直播影片下載後，實際長度低於預期長度的此比例即視為不完整（只錄到串流片段）
    static let minimumCompleteDurationRatio: Double = 0.9

    /// yt-dlp 回報為首播／直播相關的 live_status
    static let liveRelatedStatuses: Set<String> = ["is_upcoming", "is_live", "post_live"]

    /// 會讓輸出刻意短於原片的 yt-dlp 選項；指令含這些選項時不做長度檢查
    static let durationShorteningOptions = ["--download-sections", "--sponsorblock-remove", "--remove-chapters"]
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
