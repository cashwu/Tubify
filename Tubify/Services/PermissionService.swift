import Foundation
import AppKit

/// 權限檢測服務
class PermissionService {
    static let shared = PermissionService()

    private init() {}

    /// Safari cookies 檔案路徑
    private var safariCookiesFile: String {
        NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
    }

    /// 檢測是否有完整磁碟存取權限（透過嘗試實際讀取 Safari cookies 檔案）
    func hasFullDiskAccess() -> Bool {
        let fileURL = URL(fileURLWithPath: safariCookiesFile)

        // 嘗試打開檔案來確認權限
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            fileHandle.closeFile()
            return true
        } catch {
            // 如果是檔案不存在，也視為有權限（Safari 可能尚未建立 cookies）
            if (error as NSError).code == NSFileReadNoSuchFileError {
                // 嘗試檢查目錄是否可存取
                let directoryPath = (safariCookiesFile as NSString).deletingLastPathComponent
                do {
                    _ = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
                    return true
                } catch {
                    return false
                }
            }
            return false
        }
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
