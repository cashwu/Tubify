import Foundation

/// Safari Cookies 代理服務
/// 由於 yt-dlp 子進程沒有完整磁碟存取權限，但 Tubify 有，
/// 這個服務負責讀取 Safari cookies 並轉換為 yt-dlp 可用的格式
class SafariCookiesService {
    static let shared = SafariCookiesService()

    private init() {}

    /// Safari cookies 檔案路徑
    private var safariCookiesFile: String {
        NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
    }

    /// 臨時 cookies 文件路徑
    private var tempCookiesPath: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tubify_safari_cookies.txt")
    }

    /// macOS 絕對時間到 Unix 時間戳的偏移量
    /// macOS 使用 2001-01-01 作為紀元，Unix 使用 1970-01-01
    private let macOSTimeOffset: TimeInterval = 978307200

    // MARK: - 公開方法

    /// 導出 Safari cookies 為 Netscape 格式並返回臨時文件路徑
    func exportSafariCookies() -> String? {
        // 檢查是否有權限
        guard PermissionService.shared.hasFullDiskAccess() else {
            TubifyLogger.cookies.warning("沒有完整磁碟存取權限，無法讀取 Safari cookies")
            return nil
        }

        // 解析 binarycookies 文件
        guard let cookies = parseBinaryCookies() else {
            TubifyLogger.cookies.error("解析 Safari cookies 失敗")
            return nil
        }

        // 轉換為 Netscape 格式
        let netscapeContent = convertToNetscapeFormat(cookies)

        // 寫入臨時文件
        do {
            try netscapeContent.write(to: tempCookiesPath, atomically: true, encoding: .utf8)
            TubifyLogger.cookies.info("Safari cookies 已導出到: \(self.tempCookiesPath.path)")
            return tempCookiesPath.path
        } catch {
            TubifyLogger.cookies.error("寫入 cookies 文件失敗: \(error)")
            return nil
        }
    }

    /// 將 --cookies-from-browser safari 替換為 --cookies 文件
    func transformCommand(_ command: String) -> String {
        guard let cookiesPath = exportSafariCookies() else {
            return command
        }

        return command
            .replacingOccurrences(of: "--cookies-from-browser safari", with: "--cookies \"\(cookiesPath)\"")
            .replacingOccurrences(of: "--cookies-from-browser=safari", with: "--cookies \"\(cookiesPath)\"")
    }

    /// 檢查指令是否需要 Safari cookies
    func commandNeedsSafariCookies(_ command: String) -> Bool {
        return command.contains("--cookies-from-browser safari") ||
               command.contains("--cookies-from-browser=safari")
    }

    // MARK: - BinaryCookies 解析

    /// Cookie 結構
    struct Cookie {
        let domain: String
        let name: String
        let path: String
        let value: String
        let expirationDate: Date?
        let isSecure: Bool
        let isHTTPOnly: Bool
    }

    /// 解析 Safari binarycookies 文件
    private func parseBinaryCookies() -> [Cookie]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: safariCookiesFile)) else {
            TubifyLogger.cookies.error("無法讀取 Safari cookies 文件: \(self.safariCookiesFile)")
            return nil
        }

        var cookies: [Cookie] = []
        var offset = 0

        // 檢查魔數 "cook"
        guard data.count >= 4 else { return nil }
        let magic = String(data: data[0..<4], encoding: .ascii)
        guard magic == "cook" else {
            TubifyLogger.cookies.error("無效的 binarycookies 文件格式")
            return nil
        }
        offset = 4

        // 讀取頁數（大端）
        guard data.count >= offset + 4 else { return nil }
        let pageCount = data.readBigEndianUInt32(at: offset)
        offset += 4

        // 讀取每頁大小
        var pageSizes: [UInt32] = []
        for _ in 0..<pageCount {
            guard data.count >= offset + 4 else { return nil }
            let pageSize = data.readBigEndianUInt32(at: offset)
            pageSizes.append(pageSize)
            offset += 4
        }

        // 解析每個頁面
        for pageSize in pageSizes {
            guard data.count >= offset + Int(pageSize) else { break }
            let pageData = data[offset..<(offset + Int(pageSize))]
            if let pageCookies = parsePage(Data(pageData)) {
                cookies.append(contentsOf: pageCookies)
            }
            offset += Int(pageSize)
        }

        TubifyLogger.cookies.info("解析到 \(cookies.count) 個 cookies")
        return cookies
    }

    /// 解析單個頁面
    private func parsePage(_ data: Data) -> [Cookie]? {
        var cookies: [Cookie] = []
        var offset = 0

        // 頁頭 0x00000100（小端）
        guard data.count >= 4 else { return nil }
        let pageHeader = data.readLittleEndianUInt32(at: offset)
        guard pageHeader == 0x00000100 else { return nil }
        offset += 4

        // Cookie 數量（小端）
        guard data.count >= offset + 4 else { return nil }
        let cookieCount = data.readLittleEndianUInt32(at: offset)
        offset += 4

        // Cookie 偏移表
        var cookieOffsets: [UInt32] = []
        for _ in 0..<cookieCount {
            guard data.count >= offset + 4 else { return nil }
            let cookieOffset = data.readLittleEndianUInt32(at: offset)
            cookieOffsets.append(cookieOffset)
            offset += 4
        }

        // 頁尾（跳過）
        offset += 4

        // 解析每個 cookie
        for cookieOffset in cookieOffsets {
            if let cookie = parseCookie(data, at: Int(cookieOffset)) {
                cookies.append(cookie)
            }
        }

        return cookies
    }

    /// 解析單個 cookie
    private func parseCookie(_ data: Data, at startOffset: Int) -> Cookie? {
        var offset = startOffset

        // Cookie 大小
        guard data.count >= offset + 4 else { return nil }
        _ = data.readLittleEndianUInt32(at: offset)
        offset += 4

        // 未知欄位
        offset += 4

        // 標誌
        guard data.count >= offset + 4 else { return nil }
        let flags = data.readLittleEndianUInt32(at: offset)
        let isSecure = (flags & 0x01) != 0
        let isHTTPOnly = (flags & 0x04) != 0
        offset += 4

        // 未知欄位
        offset += 4

        // 偏移量
        guard data.count >= offset + 16 else { return nil }
        let urlOffset = data.readLittleEndianUInt32(at: offset)
        let nameOffset = data.readLittleEndianUInt32(at: offset + 4)
        let pathOffset = data.readLittleEndianUInt32(at: offset + 8)
        let valueOffset = data.readLittleEndianUInt32(at: offset + 12)
        offset += 16

        // 過期時間（8 字節 Double，macOS 絕對時間）
        guard data.count >= offset + 8 else { return nil }
        let expirationTime = data.readLittleEndianDouble(at: offset)
        offset += 8

        // 創建時間（跳過）
        offset += 8

        // 讀取字符串
        let domain = data.readNullTerminatedString(at: startOffset + Int(urlOffset)) ?? ""
        let name = data.readNullTerminatedString(at: startOffset + Int(nameOffset)) ?? ""
        let path = data.readNullTerminatedString(at: startOffset + Int(pathOffset)) ?? ""
        let value = data.readNullTerminatedString(at: startOffset + Int(valueOffset)) ?? ""

        // 轉換過期時間
        var expirationDate: Date? = nil
        if expirationTime > 0 {
            expirationDate = Date(timeIntervalSince1970: expirationTime + macOSTimeOffset)
        }

        return Cookie(
            domain: domain,
            name: name,
            path: path,
            value: value,
            expirationDate: expirationDate,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly
        )
    }

    // MARK: - Netscape 格式轉換

    /// 轉換為 Netscape cookies 格式
    private func convertToNetscapeFormat(_ cookies: [Cookie]) -> String {
        var lines: [String] = []

        // 文件頭
        lines.append("# Netscape HTTP Cookie File")
        lines.append("# https://curl.haxx.se/rfc/cookie_spec.html")
        lines.append("# This is a generated file! Do not edit.")
        lines.append("")

        for cookie in cookies {
            // 格式：domain \t includeSubdomains \t path \t secure \t expiry \t name \t value
            let domain = cookie.domain
            let includeSubdomains = domain.hasPrefix(".") ? "TRUE" : "FALSE"
            let path = cookie.path.isEmpty ? "/" : cookie.path
            let secure = cookie.isSecure ? "TRUE" : "FALSE"
            let expiry: String
            if let date = cookie.expirationDate {
                expiry = String(Int(date.timeIntervalSince1970))
            } else {
                expiry = "0"
            }

            let line = "\(domain)\t\(includeSubdomains)\t\(path)\t\(secure)\t\(expiry)\t\(cookie.name)\t\(cookie.value)"
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Data 擴展

private extension Data {
    /// 讀取大端 UInt32
    func readBigEndianUInt32(at offset: Int) -> UInt32 {
        guard count >= offset + 4 else { return 0 }
        return withUnsafeBytes { ptr in
            let bytes = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        }
    }

    /// 讀取小端 UInt32
    func readLittleEndianUInt32(at offset: Int) -> UInt32 {
        guard count >= offset + 4 else { return 0 }
        return withUnsafeBytes { ptr in
            let bytes = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        }
    }

    /// 讀取小端 Double
    func readLittleEndianDouble(at offset: Int) -> Double {
        guard count >= offset + 8 else { return 0 }
        return withUnsafeBytes { ptr in
            let bytes = ptr.baseAddress!.advanced(by: offset)
            var value: Double = 0
            memcpy(&value, bytes, 8)
            return value
        }
    }

    /// 讀取 null 終止字符串
    func readNullTerminatedString(at offset: Int) -> String? {
        guard offset >= 0 && offset < count else { return nil }
        var endOffset = offset
        while endOffset < count && self[endOffset] != 0 {
            endOffset += 1
        }
        return String(data: self[offset..<endOffset], encoding: .utf8)
    }
}
