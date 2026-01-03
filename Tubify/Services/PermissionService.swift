import Foundation
import AppKit

/// 權限檢測服務
class PermissionService {
    static let shared = PermissionService()

    private init() {}

    /// Safari cookies 路徑
    private var safariCookiesPath: String {
        NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies"
    }

    /// 檢測是否有完整磁碟存取權限（透過嘗試讀取 Safari cookies 目錄）
    func hasFullDiskAccess() -> Bool {
        return FileManager.default.isReadableFile(atPath: safariCookiesPath)
    }

    /// 開啟系統設定 - 完整磁碟存取
    func openFullDiskAccessSettings() {
        // macOS Ventura+ 使用新的 URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 開啟系統設定 - 隱私與安全性
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 檢查下載指令是否使用 Safari cookies
    func commandUsesSafariCookies(_ command: String) -> Bool {
        return command.contains("--cookies-from-browser safari") ||
               command.contains("--cookies-from-browser=safari")
    }

    /// 取得權限狀態描述
    func getPermissionStatusDescription() -> (status: Bool, message: String) {
        if hasFullDiskAccess() {
            return (true, "已授權完整磁碟存取")
        } else {
            return (false, "需要授權完整磁碟存取才能使用 Safari cookies")
        }
    }
}
