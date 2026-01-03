import Foundation
import UserNotifications

/// 通知服務
class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    /// 請求通知權限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                TubifyLogger.general.info("通知權限已授予")
            } else {
                TubifyLogger.general.info("通知權限被拒絕")
            }
            return granted
        } catch {
            TubifyLogger.general.error("請求通知權限失敗: \(error.localizedDescription)")
            return false
        }
    }

    /// 檢查通知權限狀態
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    /// 發送下載完成通知
    func sendDownloadCompleteNotification(title: String, outputPath: String) {
        let content = UNMutableNotificationContent()
        content.title = "下載完成"
        content.body = title
        content.sound = .default

        // 可以點擊通知打開檔案位置
        content.userInfo = ["outputPath": outputPath]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // 立即發送
        )

        notificationCenter.add(request) { error in
            if let error = error {
                TubifyLogger.general.error("發送通知失敗: \(error.localizedDescription)")
            } else {
                TubifyLogger.general.info("已發送下載完成通知: \(title)")
            }
        }
    }

    /// 發送下載失敗通知
    func sendDownloadFailedNotification(title: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "下載失敗"
        content.body = "\(title)\n\(error)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                TubifyLogger.general.error("發送通知失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 發送所有下載完成通知
    func sendAllDownloadsCompleteNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "所有下載已完成"
        content.body = "共完成 \(count) 個下載"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                TubifyLogger.general.error("發送通知失敗: \(error.localizedDescription)")
            }
        }
    }
}
