import SwiftUI

/// 播放清單選集視窗
struct PlaylistSelectionView: View {
    let playlistTitle: String
    let videos: [VideoInfo]
    let onConfirm: ([VideoInfo]) -> Void
    let onCancel: () -> Void

    @State private var selectedIndices: Set<Int> = []
    @State private var didConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var allSelected: Bool {
        selectedIndices.count == videos.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題欄
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlistTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Text("共 \(videos.count) 集")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            // 全選 / 全部取消
            HStack {
                Button(allSelected ? "全部取消" : "全選") {
                    if allSelected {
                        selectedIndices.removeAll()
                    } else {
                        selectedIndices = Set(videos.indices)
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))

                Spacer()

                Text("已選 \(selectedIndices.count) 集")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // 影片列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                        Toggle(isOn: Binding(
                            get: { selectedIndices.contains(index) },
                            set: { isSelected in
                                if isSelected {
                                    selectedIndices.insert(index)
                                } else {
                                    selectedIndices.remove(index)
                                }
                            }
                        )) {
                            HStack(spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 28, alignment: .trailing)
                                Text(video.title)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                    }
                }
            }

            Divider()

            // 按鈕
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("下載 (\(selectedIndices.count))") {
                    didConfirm = true
                    let selected = selectedIndices.sorted().map { videos[$0] }
                    onConfirm(selected)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndices.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 480)
        .onAppear {
            // 預設全選
            selectedIndices = Set(videos.indices)
        }
        .onDisappear {
            // 若非確認下載而關閉（如按 Esc、點擊外部），自動取消
            if !didConfirm {
                onCancel()
            }
        }
    }
}

#Preview("10 集播放清單") {
    PlaylistSelectionView(
        playlistTitle: "Swift 教學系列",
        videos: (1...10).map { i in
            VideoInfo(
                id: "video\(i)",
                title: "第 \(i) 集：Swift 進階技巧與實戰應用",
                thumbnail: nil,
                duration: nil,
                uploader: nil,
                url: "https://www.youtube.com/watch?v=video\(i)",
                liveStatus: nil,
                releaseTimestamp: nil
            )
        },
        onConfirm: { _ in },
        onCancel: {}
    )
}
