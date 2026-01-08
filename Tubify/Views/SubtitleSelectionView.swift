import SwiftUI

/// 字幕選擇視窗
struct SubtitleSelectionView: View {
    let videoTitle: String?  // 單一影片標題，播放清單為 nil
    let videoCount: Int      // 影片數量（播放清單用）
    let availableSubtitles: [SubtitleTrack]
    let onSelect: (SubtitleSelection?) -> Void

    @State private var selectedLanguages: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    /// 過濾只顯示英文、日文、中文字幕
    private var filteredSubtitles: [SubtitleTrack] {
        availableSubtitles.filter { SubtitleTrack.isSupportedLanguage($0.languageCode) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題欄
            HStack {
                Text("選擇字幕")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding()

            Divider()

            // 影片資訊
            HStack {
                if let title = videoTitle {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("\(videoCount) 部影片")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // 字幕列表
            Form {
                Section("可用字幕") {
                    ForEach(filteredSubtitles) { track in
                        Toggle(isOn: Binding(
                            get: { selectedLanguages.contains(track.languageCode) },
                            set: { isSelected in
                                if isSelected {
                                    selectedLanguages.insert(track.languageCode)
                                } else {
                                    selectedLanguages.remove(track.languageCode)
                                }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Text(track.languageName)
                                Text("(\(track.languageCode))")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(size: 10))
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // 按鈕
            HStack {
                Button("跳過") {
                    onSelect(nil)
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("下載") {
                    let selection = SubtitleSelection(
                        selectedLanguages: Array(selectedLanguages)
                    )
                    onSelect(selection)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(selectedLanguages.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 350, height: 400)
        .onAppear {
            // 預設選擇所有過濾後的字幕
            selectedLanguages = Set(filteredSubtitles.map { $0.languageCode })
        }
    }
}

#Preview {
    SubtitleSelectionView(
        videoTitle: "測試影片標題",
        videoCount: 1,
        availableSubtitles: [
            SubtitleTrack(languageCode: "zh-TW"),
            SubtitleTrack(languageCode: "en"),
            SubtitleTrack(languageCode: "ja")
        ],
        onSelect: { _ in }
    )
}
