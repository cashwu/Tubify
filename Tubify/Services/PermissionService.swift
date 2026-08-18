import Foundation
import AppKit

/// 權限檢測服務
class PermissionService {
    static let shared = PermissionService()

    private init() {}

    /// Safari cookies 可能的檔案路徑（依序嘗試，取第一個存在者）
    private var possibleCookiesPaths: [String] {
        [
            // Safari 沙箱化前的舊路徑；部分機器仍留有此目錄（多半是空的）
            NSHomeDirectory() + "/Library/Cookies/Cookies.binarycookies",
            // Safari 沙箱化後的容器路徑，macOS 26.5 實測仍在此
            NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
        ]
    }

    /// 檢測是否有完整磁碟存取權限（透過嘗試實際讀取 Safari cookies 檔案）
    ///
    /// 只有在所有 cookies 檔案都「不存在」時才退回目錄檢查。一旦某個檔案存在卻讀不到，
    /// 那就是權限被拒的直接證據，不得再用目錄檢查覆蓋——`~/Library/Cookies` 可能只是
    /// Safari 沙箱化前遺留的空目錄，能否列出並不足以證明有完整磁碟存取權限。
    ///
    /// `openFile` 與 `listDirectory` 可注入以便測試，預設走真實檔案系統。
    func hasFullDiskAccess(
        openFile: (String) throws -> Void = PermissionService.openFileForReading,
        listDirectory: (String) throws -> Void = PermissionService.listDirectoryContents
    ) -> Bool {
        var sawPermissionDenied = false

        for path in possibleCookiesPaths {
            do {
                try openFile(path)
                return true
            } catch {
                // 檔案不存在：這條路徑無從判斷權限，換下一條。
                if (error as NSError).code == NSFileReadNoSuchFileError {
                    continue
                }
                // 檔案存在卻打不開（如權限被拒）——已足以判定沒有權限。
                sawPermissionDenied = true
            }
        }

        guard !sawPermissionDenied else { return false }

        // 所有 cookies 檔案都不存在，改以所在目錄是否可列出作為判斷依據。
        for path in possibleCookiesPaths {
            let directoryPath = (path as NSString).deletingLastPathComponent
            do {
                try listDirectory(directoryPath)
                return true
            } catch {
                continue
            }
        }

        return false
    }

    private static func openFileForReading(_ path: String) throws {
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        fileHandle.closeFile()
    }

    private static func listDirectoryContents(_ path: String) throws {
        _ = try FileManager.default.contentsOfDirectory(atPath: path)
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
