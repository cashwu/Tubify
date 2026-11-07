import Foundation

/// 把下載完成的影片與字幕改成使用者自訂的名稱（rename-download-title R4、R8、R9、R10、R12）
///
/// 只在影片所在的資料夾內改名，不搬移資料夾；不碰 yt-dlp 管理的 `.part` 等中間檔。
/// 任何情況都不覆蓋既有檔案：目標被佔用就改用編號，執行途中失敗會盡量還原已完成的步驟。
enum OutputFileRenamer {
    enum Mode {
        /// 檔案屬於本任務：直接改名
        case move
        /// 檔案是 yt-dlp 沿用的既有檔：複製出新名稱的檔案，原檔不動
        case copy
    }

    enum RenameError: LocalizedError, Equatable {
        case sourceMissing(String)
        case noAvailableName

        var errorDescription: String? {
            switch self {
            case .sourceMissing(let path):
                return "找不到檔案：\(path)"
            case .noAvailableName:
                return "找不到可用的檔案名稱"
            }
        }
    }

    /// 編號上限；超過代表資料夾狀態異常，直接放棄而不是無限嘗試
    private static let maxNumberingAttempts = 9_999

    /// 名稱轉成主檔名：與 yt-dlp 預設的 sanitize_filename 一致，`/` 換成 `⧸`、`:` 換成 `：`
    static func fileNameBase(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "\u{29F8}")
            .replacingOccurrences(of: ":", with: "\u{FF1A}")
    }

    /// 把影片與所選語言的字幕改成新名稱，回傳影片的新路徑。
    /// - Parameters:
    ///   - subtitleLanguages: 任務所選的字幕語言 key；只處理 `<影片主檔名>.<語言>.srt`，不存在的語言略過
    ///   - beforeEachOperation: 測試用，在每個實際的檔案操作前呼叫（參數為操作序號，影片為 0）
    /// - Returns: 新名稱就是目前的檔名時回傳原路徑，不做任何檔案操作
    static func apply(
        videoPath: String,
        newName: String,
        subtitleLanguages: [String],
        mode: Mode,
        beforeEachOperation: ((Int) -> Void)? = nil
    ) throws -> String {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: videoPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw RenameError.sourceMissing(videoPath)
        }

        let videoURL = URL(fileURLWithPath: videoPath)
        let directory = videoURL.deletingLastPathComponent()
        let oldBase = videoURL.deletingPathExtension().lastPathComponent
        let videoSuffix = videoURL.pathExtension.isEmpty ? "" : ".\(videoURL.pathExtension)"

        // 影片與字幕共用同一個主檔名，只差在後綴
        var sources: [(path: String, suffix: String)] = [(videoPath, videoSuffix)]
        var seenLanguages: Set<String> = []
        for language in subtitleLanguages where seenLanguages.insert(language).inserted {
            let suffix = ".\(language).srt"
            let subtitlePath = directory.appendingPathComponent(oldBase + suffix).path
            if isRegularFile(subtitlePath) {
                sources.append((subtitlePath, suffix))
            }
        }

        let desiredBase = fileNameBase(for: newName)
        for index in 0...maxNumberingAttempts {
            let base = index == 0 ? desiredBase : "\(desiredBase) (\(index))"
            let operations = sources.map { source in
                (source: source.path, target: directory.appendingPathComponent(base + source.suffix).path)
            }
            guard operations.allSatisfy({ isAvailable(target: $0.target, for: $0.source, mode: mode) }) else {
                continue
            }
            try perform(operations.filter { $0.source != $0.target }, mode: mode, beforeEachOperation: beforeEachOperation)
            return operations[0].target
        }
        throw RenameError.noAvailableName
    }

    // MARK: - 私有方法

    /// 依序執行；任一步失敗時反向還原已完成的步驟再拋出錯誤
    private static func perform(
        _ operations: [(source: String, target: String)],
        mode: Mode,
        beforeEachOperation: ((Int) -> Void)?
    ) throws {
        let fileManager = FileManager.default
        var completed: [(source: String, target: String)] = []
        do {
            for (index, operation) in operations.enumerated() {
                beforeEachOperation?(index)
                switch mode {
                case .move:
                    try move(from: operation.source, to: operation.target)
                case .copy:
                    try fileManager.copyItem(atPath: operation.source, toPath: operation.target)
                }
                completed.append(operation)
            }
        } catch {
            for operation in completed.reversed() {
                // 還原失敗時檔案會停在新名稱，而任務仍記錄舊路徑；只能寫 log 讓使用者與維護者找得到檔案
                do {
                    switch mode {
                    case .move:
                        try move(from: operation.target, to: operation.source)
                    case .copy:
                        // 只刪這次自己複製出來的檔案
                        try fileManager.removeItem(atPath: operation.target)
                    }
                } catch let rollbackError {
                    TubifyLogger.download.error("改名失敗後無法還原: \(operation.target) → \(operation.source)，\(rollbackError.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// `FileManager.moveItem` 在目標已存在時會失敗，因此不會覆蓋其他檔案。
    /// 不分大小寫的磁碟區上只改大小寫時，目標「已存在」的就是來源本身，改經暫存名稱分兩步完成
    private static func move(from source: String, to target: String) throws {
        let fileManager = FileManager.default
        guard isSameFile(source, target) else {
            try fileManager.moveItem(atPath: source, toPath: target)
            return
        }

        let temporaryPath = URL(fileURLWithPath: source)
            .deletingLastPathComponent()
            .appendingPathComponent(".tubify-rename-\(UUID().uuidString)")
            .path
        try fileManager.moveItem(atPath: source, toPath: temporaryPath)
        do {
            try fileManager.moveItem(atPath: temporaryPath, toPath: target)
        } catch {
            do {
                try fileManager.moveItem(atPath: temporaryPath, toPath: source)
            } catch let rollbackError {
                // 暫存名稱是隱藏檔，Finder 看不到，必須留下路徑才找得回來
                TubifyLogger.download.error("改名失敗後無法還原暫存檔: \(temporaryPath) → \(source)，\(rollbackError.localizedDescription)")
            }
            throw error
        }
    }

    /// 目標可用：就是來源本身、不存在，或（直接改名時）只差大小寫而指向來源本身。
    /// 複製時原檔必須保留，因此只差大小寫也算被佔用（E19）
    private static func isAvailable(target: String, for source: String, mode: Mode) -> Bool {
        if target == source { return true }
        guard itemExists(target) else { return true }
        return mode == .move && isSameFile(source, target)
    }

    /// `attributesOfItem` 不跟隨 symbolic link，取得的是連結本身的屬性
    private static func attributes(_ path: String) -> [FileAttributeKey: Any]? {
        try? FileManager.default.attributesOfItem(atPath: path)
    }

    /// 連結本身存在就算佔用
    private static func itemExists(_ path: String) -> Bool {
        attributes(path) != nil
    }

    private static func isRegularFile(_ path: String) -> Bool {
        attributes(path)?[.type] as? FileAttributeType == .typeRegular
    }

    private static func isSameFile(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = attributes(lhs),
              let right = attributes(rhs),
              let leftFile = left[.systemFileNumber] as? NSNumber,
              let rightFile = right[.systemFileNumber] as? NSNumber,
              let leftVolume = left[.systemNumber] as? NSNumber,
              let rightVolume = right[.systemNumber] as? NSNumber else {
            return false
        }
        return leftFile == rightFile && leftVolume == rightVolume
    }
}
