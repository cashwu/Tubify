import Foundation
import AppKit

/// 處理下載完成後的 URL Scheme 回調
actor CallbackService {
    static let shared = CallbackService()

    private init() {}

    /// 觸發回調通知外部 App
    /// - Parameters:
    ///   - scheme: 回調的 URL Scheme（例如 "whispify"）
    ///   - task: 完成的下載任務
    ///   - filePath: 下載檔案的本機路徑
    func triggerCallback(
        scheme: String,
        task: DownloadTask,
        filePath: String
    ) async {
        // 建構回調 URL
        var components = URLComponents()
        components.scheme = scheme
        components.host = "import"

        var queryItems: [URLQueryItem] = []

        // 必填: request_id（如果有的話）
        if let requestId = task.requestId {
            queryItems.append(URLQueryItem(
                name: "request_id",
                value: requestId
            ))
        }

        // 必填: 檔案路徑
        queryItems.append(URLQueryItem(
            name: "file",
            value: filePath
        ))

        // 選填: 標題
        if !task.title.isEmpty && task.title != "載入中..." && task.title != "無法獲取標題" {
            queryItems.append(URLQueryItem(
                name: "title",
                value: task.title
            ))
        }

        // 選填: 時長（如果有的話）
        if let duration = task.duration, duration > 0 {
            queryItems.append(URLQueryItem(
                name: "duration",
                value: String(duration)
            ))
        }

        // 選填: 縮圖 URL
        if let thumbnailURL = task.thumbnailURL {
            queryItems.append(URLQueryItem(
                name: "thumbnail",
                value: thumbnailURL
            ))
        }

        components.queryItems = queryItems

        guard let callbackURL = components.url else {
            TubifyLogger.general.error("無法建構回調 URL")
            return
        }

        TubifyLogger.general.info("觸發回調: \(callbackURL.absoluteString)")

        // 在主執行緒開啟 URL
        await MainActor.run {
            NSWorkspace.shared.open(callbackURL)
        }
    }

    /// 檢查目標 App 是否已安裝
    /// - Parameter scheme: URL Scheme
    /// - Returns: 是否可以開啟該 Scheme
    func canOpenScheme(_ scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else {
            return false
        }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}
