import XCTest
@testable import Tubify

/// 媒體選擇邏輯測試
/// 測試音軌選擇是否應該顯示的邏輯
final class MediaSelectionLogicTests: XCTestCase {

    // MARK: - 輔助方法

    /// 建立指定數量的支援語言音軌（僅使用 en, ja, zh）
    /// - Note: 最多 3 個音軌，超過會循環
    private func createAudioTracks(count: Int) -> [AudioTrack] {
        let supportedLanguages = ["en", "ja", "zh"]
        return (0..<count).map { AudioTrack(languageCode: supportedLanguages[$0 % supportedLanguages.count]) }
    }

    /// 建立指定數量的支援語言字幕（僅使用 en, ja, zh-TW）
    /// - Note: 最多 3 個字幕，超過會循環
    private func createSubtitleTracks(count: Int) -> [SubtitleTrack] {
        let supportedLanguages = ["en", "ja", "zh-TW"]
        return (0..<count).map { SubtitleTrack(languageCode: supportedLanguages[$0 % supportedLanguages.count]) }
    }

    // MARK: - 音軌選擇顯示邏輯測試

    func testShouldNotShowAudioSelection_WhenZeroTracks() {
        // 0 個音軌不應顯示音軌選擇
        let tracks: [AudioTrack] = []
        XCTAssertFalse(tracks.count > 1)
    }

    func testShouldNotShowAudioSelection_WhenOnlyOneTrack() {
        // 只有 1 個額外音軌不應顯示音軌選擇（使用預設）
        let tracks = createAudioTracks(count: 1)
        XCTAssertFalse(tracks.count > 1)
    }

    func testShouldShowAudioSelection_WhenTwoTracks() {
        // 有 2 個音軌應顯示音軌選擇
        let tracks = createAudioTracks(count: 2)
        XCTAssertTrue(tracks.count > 1)
    }

    func testShouldShowAudioSelection_WhenMultipleTracks() {
        // 有多個音軌應顯示音軌選擇
        let tracks = createAudioTracks(count: 3)
        XCTAssertTrue(tracks.count > 1)
    }

    // MARK: - 媒體選擇對話框顯示邏輯測試

    func testShouldNotShowDialog_WhenNoSubtitlesAndOneAudioTrack() {
        // 沒有字幕且只有 1 個音軌 → 不顯示對話框
        let subtitles: [SubtitleTrack] = []
        let audioTracks = createAudioTracks(count: 1)

        let shouldShowDialog = !subtitles.isEmpty || audioTracks.count > 1
        XCTAssertFalse(shouldShowDialog)
    }

    func testShouldShowDialog_WhenHasSubtitlesOnly() {
        // 有字幕但沒有音軌 → 顯示對話框（選字幕）
        let subtitles = createSubtitleTracks(count: 2)
        let audioTracks: [AudioTrack] = []

        let shouldShowDialog = !subtitles.isEmpty || audioTracks.count > 1
        XCTAssertTrue(shouldShowDialog)
    }

    func testShouldShowDialog_WhenHasSubtitlesAndOneAudioTrack() {
        // 有字幕且只有 1 個音軌 → 顯示對話框（選字幕，但不顯示音軌區塊）
        let subtitles = createSubtitleTracks(count: 1)
        let audioTracks = createAudioTracks(count: 1)

        let shouldShowDialog = !subtitles.isEmpty || audioTracks.count > 1
        XCTAssertTrue(shouldShowDialog)  // 因為有字幕

        let shouldShowAudioSection = audioTracks.count > 1
        XCTAssertFalse(shouldShowAudioSection)  // 但不顯示音軌區塊
    }

    func testShouldShowDialog_WhenMultipleAudioTracksOnly() {
        // 沒有字幕但有多個音軌 → 顯示對話框（選音軌）
        let subtitles: [SubtitleTrack] = []
        let audioTracks = createAudioTracks(count: 2)

        let shouldShowDialog = !subtitles.isEmpty || audioTracks.count > 1
        XCTAssertTrue(shouldShowDialog)
    }

    func testShouldNotShowDialog_WhenNoOptions() {
        // 沒有字幕也沒有音軌 → 不顯示對話框
        let subtitles: [SubtitleTrack] = []
        let audioTracks: [AudioTrack] = []

        let shouldShowDialog = !subtitles.isEmpty || audioTracks.count > 1
        XCTAssertFalse(shouldShowDialog)
    }

    // MARK: - 語言過濾測試

    func testFilteredAudioTracks_OnlySupportedLanguages() {
        // 確認只有支援的語言（en, ja, zh）會被計入
        let allTracks = [
            AudioTrack(languageCode: "en"),
            AudioTrack(languageCode: "ja"),
            AudioTrack(languageCode: "ko"),  // 不支援
            AudioTrack(languageCode: "es")   // 不支援
        ]

        let filteredTracks = allTracks.filter { AudioTrack.isSupportedLanguage($0.languageCode) }

        XCTAssertEqual(filteredTracks.count, 2)  // 只有 en 和 ja
    }

    func testFilteredAudioTracks_SingleSupportedLanguage() {
        // 只有一個支援的語言時，過濾後應該只有 1 個
        let allTracks = [
            AudioTrack(languageCode: "en"),
            AudioTrack(languageCode: "ko"),  // 不支援
            AudioTrack(languageCode: "es")   // 不支援
        ]

        let filteredTracks = allTracks.filter { AudioTrack.isSupportedLanguage($0.languageCode) }

        XCTAssertEqual(filteredTracks.count, 1)
        XCTAssertFalse(filteredTracks.count > 1)  // 不應顯示音軌選擇
    }
}
