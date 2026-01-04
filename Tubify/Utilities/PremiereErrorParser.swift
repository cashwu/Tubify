import Foundation

/// 首播錯誤解析工具
enum PremiereErrorParser {
    /// 解析首播錯誤訊息，返回首播時間
    /// - Parameter error: 錯誤訊息，格式如 "Premieres in 81 minutes"
    /// - Returns: 首播時間，若非首播錯誤則返回 nil
    static func parsePremiereDate(from error: String) -> Date? {
        // 格式: "Premieres in X minutes" 或 "Premieres in X hours" 或 "Premieres in X days"
        let pattern = #"Premieres in (\d+) (minute|minutes|hour|hours|day|days)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: error, range: NSRange(error.startIndex..., in: error)),
              let numberRange = Range(match.range(at: 1), in: error),
              let unitRange = Range(match.range(at: 2), in: error) else {
            return nil
        }

        let number = Int(error[numberRange]) ?? 0
        let unit = String(error[unitRange]).lowercased()

        let seconds: Int
        if unit.hasPrefix("minute") {
            seconds = number * 60
        } else if unit.hasPrefix("hour") {
            seconds = number * 3600
        } else if unit.hasPrefix("day") {
            seconds = number * 86400
        } else {
            return nil
        }

        return Date().addingTimeInterval(TimeInterval(seconds))
    }

    /// 檢查錯誤訊息是否為首播錯誤
    /// - Parameter error: 錯誤訊息
    /// - Returns: 是否為首播錯誤
    static func isPremiereError(_ error: String) -> Bool {
        return error.contains("Premieres in")
    }
}
