import Foundation
import AppKit

/// 權限檢測服務
class PermissionService {
    static let shared = PermissionService()

    private init() {}

    /// Safari cookies 可能的檔案路徑（macOS 26+ 使用新路徑）
    private var possibleCookiesPaths: [String] {
        [
            // macOS 26 (Tahoe) 及之後版本使用此路徑
            NSHomeDirectory() + "/Library/Cookies/Cookies.binarycookies",
            // macOS 15 及之前版本使用容器路徑
            NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
        ]
    }

    /// 檢測是否有完整磁碟存取權限（透過嘗試實際讀取 Safari cookies 檔案）
    func hasFullDiskAccess() -> Bool {
        // 嘗試所有可能的路徑
        for path in possibleCookiesPaths {
            let fileURL = URL(fileURLWithPath: path)
            
            // 嘗試打開檔案來確認權限
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                fileHandle.closeFile()
                return true
            } catch {
                // 如果是檔案不存在，繼續嘗試下一個路徑
                if (error as NSError).code == NSFileReadNoSuchFileError {
                    continue
                }
                // 其他錯誤（如權限被拒）表示沒有完整磁碟存取權限
                // 但繼續嘗試其他路徑
            }
        }
        
        // 如果所有檔案都不存在，嘗試檢查目錄是否可存取
        for path in possibleCookiesPaths {
            let directoryPath = (path as NSString).deletingLastPathComponent
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
                return true
            } catch {
                continue
            }
        }
        
        return false
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
