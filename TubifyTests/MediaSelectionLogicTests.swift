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

    // MARK: - 字幕選取邏輯測試

    func testClearSelectedSubtitles_RemovesAllLanguagesWithoutChangingAudioSelection() {
        var selectedSubtitleLanguages: Set<String> = ["zh-TW", "en", "ja"]
        let selectedAudioLanguage: String? = "ja"

        clearSelectedSubtitles(&selectedSubtitleLanguages)

        XCTAssertTrue(selectedSubtitleLanguages.isEmpty)
        XCTAssertEqual(selectedAudioLanguage, "ja")
    }

    func testClearSelectedSubtitles_AllowsSelectingOnlyEnglishAfterClearing() {
        var selectedSubtitleLanguages: Set<String> = ["zh-TW", "en", "ja"]

        clearSelectedSubtitles(&selectedSubtitleLanguages)
        selectedSubtitleLanguages.insert("en")

        XCTAssertEqual(selectedSubtitleLanguages, ["en"])
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

    // MARK: - YouTube 自動字幕

    func testAutomaticTracks_HaveDistinctIDsAndLabels() {
        let uploaded = SubtitleTrack(languageCode: "en")
        let translated = SubtitleTrack.automatic(.traditionalChinese, captionKey: "zh-Hant", kind: .translated)
        let generated = SubtitleTrack.automatic(.english, captionKey: "en", kind: .generated)

        XCTAssertNotEqual(uploaded.id, generated.id)
        XCTAssertNotEqual(translated.id, generated.id)
        XCTAssertEqual(translated.displayName, "繁體中文（YouTube 自動翻譯）")
        XCTAssertEqual(generated.displayName, "英文（YouTube 自動產生）")
        XCTAssertEqual(uploaded.displayName, uploaded.languageName)
    }

    /// 同語言、不同來源的自動字幕共用同一個 id，播放清單合併選項時才會只出現一項
    func testAutomaticTracksFromDifferentSourcesShareID() {
        XCTAssertEqual(
            SubtitleTrack.automatic(.traditionalChinese, captionKey: "zh-Hant", kind: .translated).id,
            SubtitleTrack.automatic(.traditionalChinese, captionKey: "zh-Hant-en", kind: .translated).id
        )
        XCTAssertEqual(
            SubtitleTrack.automatic(.english, captionKey: "en", kind: .generated).id,
            SubtitleTrack.automatic(.english, captionKey: "en-ja", kind: .translated).id
        )
    }

    func testAutomaticCaptionTargetFromKey() {
        XCTAssertEqual(AutomaticCaptionTarget(captionKey: "zh-Hant"), .traditionalChinese)
        XCTAssertEqual(AutomaticCaptionTarget(captionKey: "zh-Hant-en"), .traditionalChinese)
        XCTAssertEqual(AutomaticCaptionTarget(captionKey: "en"), .english)
        XCTAssertEqual(AutomaticCaptionTarget(captionKey: "en-ja"), .english)
        XCTAssertNil(AutomaticCaptionTarget(captionKey: "zh-Hans"))
    }

    func testSubtitleSelectionFromTracks_SplitsUploadedAndAutomatic() throws {
        let selection = try XCTUnwrap(SubtitleSelection(tracks: [
            SubtitleTrack(languageCode: "ja"),
            .automatic(.traditionalChinese, captionKey: "zh-Hant-ja", kind: .translated),
            .automatic(.english, captionKey: "en", kind: .generated)
        ]))

        XCTAssertEqual(selection.selectedLanguages, ["ja"])
        XCTAssertEqual(selection.automaticLanguages, ["zh-Hant-ja", "en"])
        XCTAssertNil(SubtitleSelection(tracks: []))
    }

    /// 播放清單合併選擇後，各任務只保留自己擁有的字幕，自動字幕改用該任務自己的 key，且依語言分別判斷
    func testSubtitleSelectionRestricted_UsesEachTasksOwnTracks() throws {
        let selection = SubtitleSelection(selectedLanguages: ["en", "zh-Hant"], automaticLanguages: ["zh-Hant-en"])

        let uploadedOnly = try XCTUnwrap(selection.restricted(to: [SubtitleTrack(languageCode: "zh-Hant")]))
        XCTAssertEqual(uploadedOnly.selectedLanguages, ["zh-Hant"])
        XCTAssertEqual(uploadedOnly.automaticLanguages, [])

        let automaticOnly = try XCTUnwrap(selection.restricted(to: [
            .automatic(.traditionalChinese, captionKey: "zh-Hant-ja", kind: .translated),
            .automatic(.english, captionKey: "en-ja", kind: .translated)
        ]))
        XCTAssertEqual(automaticOnly.selectedLanguages, [])
        XCTAssertEqual(automaticOnly.automaticLanguages, ["zh-Hant-ja"])

        XCTAssertNil(selection.restricted(to: [SubtitleTrack(languageCode: "ja")]))
    }

    func testSubtitleSelectionRemovingAutomatic_KeepsOtherLanguages() throws {
        let mixed = SubtitleSelection(selectedLanguages: ["ja"], automaticLanguages: ["zh-Hant-ja", "en"])
        let remaining = try XCTUnwrap(mixed.removingAutomatic(["en"]))

        XCTAssertEqual(remaining.selectedLanguages, ["ja"])
        XCTAssertEqual(remaining.automaticLanguages, ["zh-Hant-ja"])
        XCTAssertNil(SubtitleSelection(selectedLanguages: [], automaticLanguages: ["zh-Hant"]).removingAutomatic(["zh-Hant"]))
    }

    /// 舊版持久化資料沒有自動字幕欄位，仍須能解碼為上傳字幕
    func testLegacyPersistedSubtitleDataDecodesAsUploaded() throws {
        let track = try JSONDecoder().decode(
            SubtitleTrack.self,
            from: Data(#"{"languageCode":"en","languageName":"英文"}"#.utf8)
        )
        let selection = try JSONDecoder().decode(
            SubtitleSelection.self,
            from: Data(#"{"selectedLanguages":["en"]}"#.utf8)
        )

        XCTAssertFalse(track.isAutomatic)
        XCTAssertEqual(selection.selectedLanguages, ["en"])
        XCTAssertEqual(selection.automaticLanguages, [])
    }

    func testAutomaticTrackRoundTripsThroughCodable() throws {
        let track = SubtitleTrack.automatic(.english, captionKey: "en", kind: .generated)
        let decoded = try JSONDecoder().decode(SubtitleTrack.self, from: JSONEncoder().encode(track))

        XCTAssertEqual(decoded, track)
    }
}
