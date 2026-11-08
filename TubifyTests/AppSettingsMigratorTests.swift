import XCTest
@testable import Tubify

/// 設定遷移測試
///
/// 背景：舊版預設下載指令一旦被 @AppStorage 寫進 UserDefaults，就會蓋過程式碼裡的新預設值。
/// 曾有使用者在 app 已更新的情況下持續套用舊的格式選擇器，踩到 YouTube 端損壞的串流。
final class AppSettingsMigratorTests: XCTestCase {

    // MARK: - 純函式邏輯測試

    /// 存的是舊預設值（從未自訂）→ 升級到目前預設
    func testMigratesLegacyDefaultCommands() {
        for legacy in AppSettingsDefaults.legacyDownloadCommands {
            let migrated = AppSettingsMigrator.migratedDownloadCommand(
                storedCommand: legacy,
                storedVersion: 0
            )
            XCTAssertEqual(
                migrated,
                AppSettingsDefaults.downloadCommand,
                "舊預設值應升級：\(legacy)"
            )
        }
    }

    /// 使用者自訂的指令必須原封不動保留
    func testPreservesCustomCommand() {
        let custom = "yt-dlp -f \"bv[height<=720]+ba\" --write-thumbnail \"$youtubeUrl\""
        let migrated = AppSettingsMigrator.migratedDownloadCommand(
            storedCommand: custom,
            storedVersion: 0
        )
        XCTAssertNil(migrated, "自訂指令不應被覆寫")
    }

    /// 已是目前版本 → 不再變動（即使值剛好等於某個舊預設，也視為使用者刻意選擇）
    func testDoesNotMigrateWhenAlreadyCurrentVersion() {
        let migrated = AppSettingsMigrator.migratedDownloadCommand(
            storedCommand: AppSettingsDefaults.legacyDownloadCommands[0],
            storedVersion: AppSettingsDefaults.downloadCommandVersion
        )
        XCTAssertNil(migrated)
    }

    /// 全新安裝沒有存過值 → 讀取時本來就會落到新預設，無須寫入
    func testDoesNotWriteForFreshInstall() {
        let migrated = AppSettingsMigrator.migratedDownloadCommand(
            storedCommand: nil,
            storedVersion: 0
        )
        XCTAssertNil(migrated)
    }

    /// 目前預設值本身不應被列為 legacy，否則遷移會反覆改寫同一個值
    func testCurrentDefaultIsNotListedAsLegacy() {
        XCTAssertFalse(
            AppSettingsDefaults.legacyDownloadCommands.contains(AppSettingsDefaults.downloadCommand),
            "目前預設值不可同時出現在 legacyDownloadCommands"
        )
    }

    /// 迴歸測試：造成這次下載失敗的那個舊預設值必須在遷移清單內
    func testBrokenAvcOnlySelectorIsMigrated() {
        let avcOnly = "yt-dlp -f \"bv[ext=mp4][vcodec^=avc]+ba[ext=m4a]/b[ext=mp4][vcodec^=avc]\" --cookies-from-browser safari \"$youtubeUrl\""
        XCTAssertEqual(
            AppSettingsMigrator.migratedDownloadCommand(storedCommand: avcOnly, storedVersion: 0),
            AppSettingsDefaults.downloadCommand
        )
    }

    /// VP9 裝在 mp4 裡時 macOS 的 Quick Look／QuickTime 無法解碼，Finder 只剩通用圖示。
    /// 只限定 ext=mp4 時 yt-dlp 會選到 YouTube 的 VP9 格式（例如 Premium 1080p 的 616，
    /// vcodec 為 `vp09...`；DASH 的 VP9 則是 `vp9`），因此優先的 alternative 都要排除 vp 開頭的編碼。
    /// 最後保留不限定編碼的退路：只剩 VP9 可選時寧可下載也不要失敗（見 7 月格式損壞事件）。
    /// 證據邊界：只檢查選擇器字串，實際挑選結果曾以 `yt-dlp --print` 對真實影片手動驗證。
    func testDefaultCommandPrefersNonVP9AndKeepsUnrestrictedFallback() throws {
        let command = AppSettingsDefaults.downloadCommand
        let formatRange = try XCTUnwrap(command.range(of: #"-f "([^"]+)""#, options: .regularExpression))
        let format = String(command[formatRange].dropFirst(4).dropLast())
        let alternatives = format.split(separator: "/").map(String.init)

        XCTAssertGreaterThanOrEqual(alternatives.count, 3)
        for alternative in alternatives.dropLast(2) {
            for part in alternative.split(separator: "+") where part.hasPrefix("bv") {
                XCTAssertTrue(part.contains("[vcodec!^=vp]"), "優先的影片格式應排除 VP9：\(part)")
            }
        }
        XCTAssertEqual(Array(alternatives.suffix(2)), ["bv*+ba", "b"], "最後應保留不限定編碼的退路")
    }

    /// 第 2 版預設（會選到 VP9）未經自訂時要升級，否則已打開過設定頁的使用者拿不到修正
    func testVersion2DefaultCommandIsMigrated() {
        let version2 = "yt-dlp -f \"bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b\" --merge-output-format mp4 --cookies-from-browser safari \"$youtubeUrl\""
        XCTAssertEqual(
            AppSettingsMigrator.migratedDownloadCommand(storedCommand: version2, storedVersion: 2),
            AppSettingsDefaults.downloadCommand
        )
    }

    // MARK: - UserDefaults 實際寫入測試

    private func makeIsolatedDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppSettingsMigratorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    func testMigrateWritesCommandAndVersion() throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppSettingsDefaults.legacyDownloadCommands[1], forKey: AppSettingsKeys.downloadCommand)

        AppSettingsMigrator.migrate(defaults: defaults)

        XCTAssertEqual(
            defaults.string(forKey: AppSettingsKeys.downloadCommand),
            AppSettingsDefaults.downloadCommand
        )
        XCTAssertEqual(
            defaults.integer(forKey: AppSettingsKeys.downloadCommandVersion),
            AppSettingsDefaults.downloadCommandVersion
        )
    }

    /// 即使沒有實際改寫指令，也要記下版本，避免每次啟動重複判斷
    func testMigrateStampsVersionEvenWhenCommandUntouched() throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let custom = "yt-dlp -f best \"$youtubeUrl\""
        defaults.set(custom, forKey: AppSettingsKeys.downloadCommand)

        AppSettingsMigrator.migrate(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: AppSettingsKeys.downloadCommand), custom, "自訂指令不應被覆寫")
        XCTAssertEqual(
            defaults.integer(forKey: AppSettingsKeys.downloadCommandVersion),
            AppSettingsDefaults.downloadCommandVersion
        )
    }

    /// 遷移必須具備冪等性：重複執行不改變結果
    func testMigrateIsIdempotent() throws {
        let (defaults, suiteName) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppSettingsDefaults.legacyDownloadCommands[0], forKey: AppSettingsKeys.downloadCommand)

        AppSettingsMigrator.migrate(defaults: defaults)
        let afterFirst = defaults.string(forKey: AppSettingsKeys.downloadCommand)
        AppSettingsMigrator.migrate(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: AppSettingsKeys.downloadCommand), afterFirst)
    }
}
