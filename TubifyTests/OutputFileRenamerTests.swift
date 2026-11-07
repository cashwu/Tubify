import XCTest
@testable import Tubify

/// 下載檔案改名規則（rename-download-title R4、R8、R9、R10、R12）
///
/// 證據邊界：檔案都是暫存目錄裡的假檔，字幕檔名 `<主檔名>.<語言>.srt` 是依 yt-dlp 2026.10.26 原始碼
/// （`subtitles_filename`）推得的格式，這裡不能證明真實 yt-dlp 的輸出。
final class OutputFileRenamerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OutputFileRenamerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            // 權限測試會把檔案改成不可讀，先還原才能刪除
            if let items = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
                for item in items {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path(item))
                }
            }
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
        try super.tearDownWithError()
    }

    // MARK: - 輔助方法

    private func path(_ name: String) -> String {
        directory.appendingPathComponent(name).path
    }

    @discardableResult
    private func makeFile(_ name: String, contents: String? = nil) throws -> String {
        let filePath = path(name)
        try (contents ?? name).write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    private func contents(_ name: String) -> String? {
        try? String(contentsOfFile: path(name), encoding: .utf8)
    }

    private func fileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    private func isCaseSensitiveVolume() throws -> Bool {
        let values = try directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
        return values.volumeSupportsCaseSensitiveNames ?? false
    }

    // MARK: - R4 檔名轉換

    func testFileNameBaseReplacesSlashAndColonLikeYTDLP() {
        XCTAssertEqual(OutputFileRenamer.fileNameBase(for: "評測 / 重量: 心得"), "評測 ⧸ 重量： 心得")
    }

    func testFileNameBaseTrimsSurroundingWhitespace() {
        XCTAssertEqual(OutputFileRenamer.fileNameBase(for: "  新名稱 \n"), "新名稱")
    }

    // MARK: - 直接改名（屬於本任務的檔案）

    func testMoveRenamesVideoAndSelectedSubtitles() throws {
        // E3、R8：影片與所選語言的字幕一起改名，保留語言與副檔名；同主檔名但未選的語言不動
        let video = try makeFile("舊.mp4")
        try makeFile("舊.zh-Hant.srt")
        try makeFile("舊.ja.srt")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "新", subtitleLanguages: ["zh-Hant"], mode: .move)

        XCTAssertEqual(newPath, path("新.mp4"))
        XCTAssertEqual(try fileNames(), ["新.mp4", "新.zh-Hant.srt", "舊.ja.srt"])
        XCTAssertEqual(contents("舊.ja.srt"), "舊.ja.srt")
        XCTAssertEqual(contents("新.mp4"), "舊.mp4")
        XCTAssertEqual(contents("新.zh-Hant.srt"), "舊.zh-Hant.srt")
    }

    func testMoveAppliesFileNameConversion() throws {
        // E7：清單顯示原字串，檔名使用替換後的字元
        let video = try makeFile("舊.mp4")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "評測 / 重量: 心得", subtitleLanguages: [], mode: .move)

        XCTAssertEqual(newPath, path("評測 ⧸ 重量： 心得.mp4"))
        XCTAssertEqual(try fileNames(), ["評測 ⧸ 重量： 心得.mp4"])
    }

    func testMoveLeavesSubtitlesOfUnselectedLanguagesUntouched() throws {
        // E17：沒有選字幕的任務不動任何字幕；只處理所選語言
        let video = try makeFile("A.mp4")
        try makeFile("A.en.srt")
        try makeFile("A.ja.srt")

        _ = try OutputFileRenamer.apply(videoPath: video, newName: "B", subtitleLanguages: [], mode: .move)
        XCTAssertEqual(try fileNames(), ["B.mp4", "A.en.srt", "A.ja.srt"])

        _ = try OutputFileRenamer.apply(videoPath: path("B.mp4"), newName: "C", subtitleLanguages: ["ja"], mode: .move)
        XCTAssertEqual(try fileNames(), ["C.mp4", "A.en.srt", "A.ja.srt"], "字幕主檔名必須與影片相同才屬於本任務")
    }

    func testMoveSkipsSelectedSubtitleThatDoesNotExist() throws {
        let video = try makeFile("A.mp4")
        try makeFile("A.en.srt")

        _ = try OutputFileRenamer.apply(videoPath: video, newName: "B", subtitleLanguages: ["en", "ja"], mode: .move)

        XCTAssertEqual(try fileNames(), ["B.mp4", "B.en.srt"])
    }

    func testRenamingToCurrentFileNameChangesNothing() throws {
        let video = try makeFile("同名.mp4")

        let movePath = try OutputFileRenamer.apply(videoPath: video, newName: "同名", subtitleLanguages: [], mode: .move)
        let copyPath = try OutputFileRenamer.apply(videoPath: video, newName: "同名", subtitleLanguages: [], mode: .copy)

        XCTAssertEqual(movePath, video)
        XCTAssertEqual(copyPath, video, "目標就是原檔時不複製出編號檔")
        XCTAssertEqual(try fileNames(), ["同名.mp4"])
    }

    // MARK: - R9 同名衝突

    func testExistingUnrelatedVideoGetsNumberedName() throws {
        // E4：既有的「新.mp4」不變，影片與字幕一起改用「新 (1)」
        try makeFile("新.mp4", contents: "既有")
        let video = try makeFile("舊.mp4")
        try makeFile("舊.en.srt")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "新", subtitleLanguages: ["en"], mode: .move)

        XCTAssertEqual(newPath, path("新 (1).mp4"))
        XCTAssertEqual(try fileNames(), ["新.mp4", "新 (1).mp4", "新 (1).en.srt"])
        XCTAssertEqual(contents("新.mp4"), "既有")
    }

    func testNumberingContinuesUntilEveryTargetIsFree() throws {
        try makeFile("新.mp4")
        try makeFile("新 (1).mp4")
        let video = try makeFile("舊.mp4")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "新", subtitleLanguages: [], mode: .move)

        XCTAssertEqual(newPath, path("新 (2).mp4"))
    }

    func testExistingUnrelatedSubtitleAloneCausesNumbering() throws {
        // E16：影片目標可用，但字幕目標被佔用時，影片與字幕一起編號
        try makeFile("新.en.srt", contents: "既有字幕")
        let video = try makeFile("舊.mp4")
        try makeFile("舊.en.srt")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "新", subtitleLanguages: ["en"], mode: .move)

        XCTAssertEqual(newPath, path("新 (1).mp4"))
        XCTAssertEqual(try fileNames(), ["新.en.srt", "新 (1).mp4", "新 (1).en.srt"])
        XCTAssertEqual(contents("新.en.srt"), "既有字幕")
    }

    func testCaseOnlyRenameOfOwnedFileIsNotTreatedAsConflict() throws {
        // E14：在不分大小寫的磁碟區上 ABC.mp4 與 abc.mp4 是同一個檔案，不可視為和自己衝突
        let video = try makeFile("abc.mp4")
        try makeFile("abc.en.srt")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "ABC", subtitleLanguages: ["en"], mode: .move)

        XCTAssertEqual(newPath, path("ABC.mp4"))
        XCTAssertEqual(try fileNames(), ["ABC.mp4", "ABC.en.srt"])
    }

    func testCaseOnlyCopyOfReusedFileGetsNumberedName() throws {
        // E19：沿用檔要保留原檔，在不分大小寫的磁碟區上 ABC.mp4 會撞到原檔而改用編號
        let video = try makeFile("abc.mp4")
        let expectedBase = try isCaseSensitiveVolume() ? "ABC" : "ABC (1)"

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "ABC", subtitleLanguages: [], mode: .copy)

        XCTAssertEqual(newPath, path("\(expectedBase).mp4"))
        XCTAssertEqual(try fileNames(), ["abc.mp4", "\(expectedBase).mp4"])
    }

    // MARK: - R10 沿用既有檔：複製

    func testCopyKeepsOriginalVideoAndSubtitles() throws {
        // E5：沿用的 A.mp4 保留，產生 B.mp4
        let video = try makeFile("A.mp4")
        try makeFile("A.en.srt")

        let newPath = try OutputFileRenamer.apply(videoPath: video, newName: "B", subtitleLanguages: ["en"], mode: .copy)

        XCTAssertEqual(newPath, path("B.mp4"))
        XCTAssertEqual(try fileNames(), ["A.mp4", "A.en.srt", "B.mp4", "B.en.srt"])
        XCTAssertEqual(contents("B.mp4"), "A.mp4")
    }

    // MARK: - R11 失敗

    func testMissingVideoThrowsSourceMissing() {
        XCTAssertThrowsError(
            try OutputFileRenamer.apply(videoPath: path("不存在.mp4"), newName: "新", subtitleLanguages: [], mode: .move)
        ) { error in
            XCTAssertEqual(error as? OutputFileRenamer.RenameError, .sourceMissing(path("不存在.mp4")))
        }
    }

    func testNameTooLongForFileSystemThrowsAndKeepsOriginal() throws {
        // E11：APFS 檔名上限為 255 個 Unicode 字元
        let video = try makeFile("舊.mp4")

        XCTAssertThrowsError(
            try OutputFileRenamer.apply(videoPath: video, newName: String(repeating: "長", count: 300), subtitleLanguages: [], mode: .move)
        )
        XCTAssertEqual(try fileNames(), ["舊.mp4"])
    }

    func testFailedSubtitleCopyRemovesCopiesAlreadyMade() throws {
        // 字幕複製失敗時，已複製出的影片要移除，原檔維持原狀
        let video = try makeFile("A.mp4")
        let subtitle = try makeFile("A.en.srt")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: subtitle)

        XCTAssertThrowsError(
            try OutputFileRenamer.apply(videoPath: video, newName: "B", subtitleLanguages: ["en"], mode: .copy)
        )
        XCTAssertEqual(try fileNames(), ["A.mp4", "A.en.srt"])
    }

    func testFailedSubtitleMoveMovesVideoBack() throws {
        // 字幕改名失敗時，已改名的影片要改回原名。在第 2 個操作（字幕）前建立同名目標，
        // 模擬衝突檢查之後目標才被其他程式佔用的競態。
        let video = try makeFile("A.mp4")
        try makeFile("A.en.srt")

        XCTAssertThrowsError(
            try OutputFileRenamer.apply(
                videoPath: video,
                newName: "B",
                subtitleLanguages: ["en"],
                mode: .move,
                beforeEachOperation: { [self] index in
                    if index == 1 { _ = try? makeFile("B.en.srt", contents: "競態") }
                }
            )
        )
        XCTAssertEqual(try fileNames(), ["A.mp4", "A.en.srt", "B.en.srt"])
        XCTAssertEqual(contents("B.en.srt"), "競態", "不可覆蓋其他檔案")
    }
}
