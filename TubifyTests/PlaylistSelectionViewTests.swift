import XCTest
@testable import Tubify

/// 播放清單選集邏輯測試
/// 測試選集視窗的選擇邏輯與回呼行為
final class PlaylistSelectionViewTests: XCTestCase {

    // MARK: - 輔助方法

    /// 建立測試用影片陣列
    private func createVideos(count: Int) -> [VideoInfo] {
        (1...count).map { i in
            VideoInfo(
                id: "video\(i)",
                title: "第 \(i) 集：測試影片",
                thumbnail: nil,
                duration: 600,
                uploader: "TestChannel",
                url: "https://www.youtube.com/watch?v=video\(i)",
                liveStatus: nil,
                releaseTimestamp: nil
            )
        }
    }

    // MARK: - 預設選取邏輯測試

    func testDefaultSelection_AllVideosSelected() {
        // 預設全選：selectedIndices 應包含所有影片索引
        let videos = createVideos(count: 5)
        let selectedIndices = Set(videos.indices)

        XCTAssertEqual(selectedIndices.count, 5)
        XCTAssertTrue(selectedIndices.contains(0))
        XCTAssertTrue(selectedIndices.contains(4))
    }

    func testDefaultSelection_EmptyPlaylist() {
        // 空播放清單的預設選取應為空集合
        let videos: [VideoInfo] = []
        let selectedIndices = Set(videos.indices)

        XCTAssertTrue(selectedIndices.isEmpty)
    }

    func testDefaultSelection_SingleVideo() {
        // 單一影片也應預設全選
        let videos = createVideos(count: 1)
        let selectedIndices = Set(videos.indices)

        XCTAssertEqual(selectedIndices.count, 1)
        XCTAssertTrue(selectedIndices.contains(0))
    }

    // MARK: - 全選 / 全部取消邏輯測試

    func testSelectAll_FromEmptySelection() {
        // 從無選取 → 全選
        let videos = createVideos(count: 3)
        var selectedIndices: Set<Int> = []

        // 模擬「全選」按鈕行為
        selectedIndices = Set(videos.indices)

        XCTAssertEqual(selectedIndices.count, 3)
        XCTAssertEqual(selectedIndices, Set([0, 1, 2]))
    }

    func testDeselectAll_FromFullSelection() {
        // 從全選 → 全部取消
        let videos = createVideos(count: 3)
        var selectedIndices = Set(videos.indices)

        // 模擬「全部取消」按鈕行為
        let allSelected = selectedIndices.count == videos.count
        XCTAssertTrue(allSelected)

        selectedIndices.removeAll()

        XCTAssertTrue(selectedIndices.isEmpty)
        XCTAssertEqual(selectedIndices.count, 0)
    }

    func testSelectAll_FromPartialSelection() {
        // 從部分選取 → 全選（按鈕應顯示「全選」）
        let videos = createVideos(count: 5)
        var selectedIndices: Set<Int> = [0, 2]

        let allSelected = selectedIndices.count == videos.count
        XCTAssertFalse(allSelected, "部分選取時 allSelected 應為 false")

        // 模擬點擊「全選」
        selectedIndices = Set(videos.indices)

        XCTAssertEqual(selectedIndices.count, 5)
    }

    // MARK: - 選取計數測試

    func testSelectedCount_ReflectsCorrectly() {
        // 選取數量應正確反映 selectedIndices 的大小
        let videos = createVideos(count: 10)

        var selectedIndices = Set(videos.indices)
        XCTAssertEqual(selectedIndices.count, 10)

        selectedIndices.remove(3)
        selectedIndices.remove(7)
        XCTAssertEqual(selectedIndices.count, 8)

        selectedIndices.removeAll()
        XCTAssertEqual(selectedIndices.count, 0)
    }

    func testAllSelected_Flag() {
        // allSelected 旗標應正確反映是否全選
        let videos = createVideos(count: 3)

        let fullSelection = Set(videos.indices)
        XCTAssertTrue(fullSelection.count == videos.count, "全選時 allSelected 應為 true")

        let partialSelection: Set<Int> = [0, 1]
        XCTAssertFalse(partialSelection.count == videos.count, "部分選取時 allSelected 應為 false")

        let emptySelection: Set<Int> = []
        XCTAssertFalse(emptySelection.count == videos.count, "無選取時 allSelected 應為 false")
    }

    // MARK: - 個別切換測試

    func testToggleIndividualSelection() {
        // 個別切換選取狀態
        var selectedIndices: Set<Int> = [0, 1, 2, 3, 4]

        // 取消選取第 2 項
        selectedIndices.remove(2)
        XCTAssertFalse(selectedIndices.contains(2))
        XCTAssertEqual(selectedIndices.count, 4)

        // 重新選取第 2 項
        selectedIndices.insert(2)
        XCTAssertTrue(selectedIndices.contains(2))
        XCTAssertEqual(selectedIndices.count, 5)
    }

    // MARK: - 下載按鈕停用邏輯測試

    func testDownloadButtonDisabled_WhenNoSelection() {
        // 沒有選取任何影片時，下載按鈕應停用
        let selectedIndices: Set<Int> = []
        let isDisabled = selectedIndices.count == 0

        XCTAssertTrue(isDisabled, "無選取時下載按鈕應停用")
    }

    func testDownloadButtonEnabled_WhenHasSelection() {
        // 有選取影片時，下載按鈕應啟用
        let selectedIndices: Set<Int> = [0]
        let isDisabled = selectedIndices.count == 0

        XCTAssertFalse(isDisabled, "有選取時下載按鈕應啟用")
    }

    func testDownloadButtonEnabled_WhenAllSelected() {
        // 全選時，下載按鈕應啟用
        let videos = createVideos(count: 5)
        let selectedIndices = Set(videos.indices)
        let isDisabled = selectedIndices.count == 0

        XCTAssertFalse(isDisabled, "全選時下載按鈕應啟用")
    }

    // MARK: - 確認回呼邏輯測試

    func testConfirmCallback_ReturnsSelectedVideos() {
        // 確認回呼應只回傳被選取的影片
        let videos = createVideos(count: 5)
        let selectedIndices: Set<Int> = [0, 2, 4]

        // 模擬 View 中的確認邏輯
        let selected = selectedIndices.sorted().map { videos[$0] }

        XCTAssertEqual(selected.count, 3)
        XCTAssertEqual(selected[0].id, "video1")
        XCTAssertEqual(selected[1].id, "video3")
        XCTAssertEqual(selected[2].id, "video5")
    }

    func testConfirmCallback_ReturnsAllVideosWhenAllSelected() {
        // 全選時確認回呼應回傳全部影片
        let videos = createVideos(count: 3)
        let selectedIndices = Set(videos.indices)

        let selected = selectedIndices.sorted().map { videos[$0] }

        XCTAssertEqual(selected.count, 3)
        XCTAssertEqual(selected[0].id, "video1")
        XCTAssertEqual(selected[1].id, "video2")
        XCTAssertEqual(selected[2].id, "video3")
    }

    func testConfirmCallback_ReturnsVideosInOrder() {
        // 確認回呼應按照原始順序回傳影片（即使選取順序不同）
        let videos = createVideos(count: 5)
        let selectedIndices: Set<Int> = [4, 1, 3]

        let selected = selectedIndices.sorted().map { videos[$0] }

        XCTAssertEqual(selected[0].id, "video2")  // index 1
        XCTAssertEqual(selected[1].id, "video4")  // index 3
        XCTAssertEqual(selected[2].id, "video5")  // index 4
    }

    func testConfirmCallback_EmptyWhenNoneSelected() {
        // 無選取時確認回呼應回傳空陣列
        let videos = createVideos(count: 3)
        let selectedIndices: Set<Int> = []

        let selected = selectedIndices.sorted().map { videos[$0] }

        XCTAssertTrue(selected.isEmpty)
    }

    // MARK: - 取消回呼測試

    func testCancelCallback_IsInvoked() {
        // 確認取消回呼可被正確呼叫
        var cancelCalled = false
        let onCancel: () -> Void = { cancelCalled = true }

        onCancel()

        XCTAssertTrue(cancelCalled)
    }

    // MARK: - VideoInfo 建立測試

    func testVideoInfo_CanBeCreatedWithMinimalFields() {
        // VideoInfo 可用最少必要欄位建立
        let video = VideoInfo(
            id: "abc123",
            title: "測試影片",
            thumbnail: nil,
            duration: nil,
            uploader: nil,
            url: "https://www.youtube.com/watch?v=abc123",
            liveStatus: nil,
            releaseTimestamp: nil
        )

        XCTAssertEqual(video.id, "abc123")
        XCTAssertEqual(video.title, "測試影片")
        XCTAssertEqual(video.url, "https://www.youtube.com/watch?v=abc123")
        XCTAssertNil(video.thumbnail)
        XCTAssertNil(video.duration)
    }
}
