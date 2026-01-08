import SwiftUI

/// 媒體選項選擇視窗（字幕 + 音軌）
struct MediaSelectionView: View {
    let videoTitle: String?  // 單一影片標題，播放清單為 nil
    let videoCount: Int      // 影片數量（播放清單用）
    let availableSubtitles: [SubtitleTrack]
    let availableAudioTracks: [AudioTrack]
    let onSelect: (SubtitleSelection?, AudioSelection?) -> Void

    @State private var selectedSubtitleLanguages: Set<String> = []
    @State private var selectedAudioLanguage: String? = nil  // nil 表示預設音軌
    @Environment(\.dismiss) private var dismiss

    /// 過濾只顯示英文、日文、中文字幕
    private var filteredSubtitles: [SubtitleTrack] {
        availableSubtitles.filter { SubtitleTrack.isSupportedLanguage($0.languageCode) }
    }

    /// 過濾只顯示英文、日文、中文音軌
    private var filteredAudioTracks: [AudioTrack] {
        availableAudioTracks.filter { AudioTrack.isSupportedLanguage($0.languageCode) }
    }

    /// 是否有任何可選項目
    private var hasOptions: Bool {
        !filteredSubtitles.isEmpty || !filteredAudioTracks.isEmpty
    }

    /// 動態計算視窗高度
    private var windowHeight: CGFloat {
        var height: CGFloat = 120  // 標題欄 + 影片資訊 + 按鈕區域
        if !filteredSubtitles.isEmpty {
            height += CGFloat(40 + filteredSubtitles.count * 28)  // Section header + items
        }
        if !filteredAudioTracks.isEmpty {
            height += CGFloat(40 + (filteredAudioTracks.count + 1) * 28)  // Section header + items + 預設選項
        }
        return min(max(height, 250), 500)  // 限制在 250-500 之間
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題欄
            HStack {
                Text("選擇下載選項")
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

            // 選項列表
            Form {
                // 字幕區塊
                if !filteredSubtitles.isEmpty {
                    Section("字幕（可多選）") {
                        ForEach(filteredSubtitles) { track in
                            Toggle(isOn: Binding(
                                get: { selectedSubtitleLanguages.contains(track.languageCode) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedSubtitleLanguages.insert(track.languageCode)
                                    } else {
                                        selectedSubtitleLanguages.remove(track.languageCode)
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

                // 音軌區塊
                if !filteredAudioTracks.isEmpty {
                    Section("音軌（單選）") {
                        Picker("", selection: $selectedAudioLanguage) {
                            Text("預設音軌").tag(nil as String?)
                            ForEach(filteredAudioTracks) { track in
                                HStack(spacing: 4) {
                                    Text(track.languageName)
                                    Text("(\(track.languageCode))")
                                        .foregroundStyle(.tertiary)
                                        .font(.system(size: 10))
                                }
                                .tag(track.languageCode as String?)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // 按鈕
            HStack {
                Button("跳過") {
                    onSelect(nil, nil)
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("下載") {
                    let subtitleSelection = selectedSubtitleLanguages.isEmpty ? nil : SubtitleSelection(
                        selectedLanguages: Array(selectedSubtitleLanguages)
                    )
                    let audioSelection = AudioSelection(selectedLanguage: selectedAudioLanguage)
                    onSelect(subtitleSelection, audioSelection)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 350, height: windowHeight)
        .onAppear {
            // 預設選擇所有過濾後的字幕
            selectedSubtitleLanguages = Set(filteredSubtitles.map { $0.languageCode })
            // 音軌預設為「預設音軌」（nil）
            selectedAudioLanguage = nil
        }
    }
}

#Preview("字幕 + 音軌") {
    MediaSelectionView(
        videoTitle: "測試影片標題 - 有多種音軌和字幕的影片",
        videoCount: 1,
        availableSubtitles: [
            SubtitleTrack(languageCode: "zh-TW"),
            SubtitleTrack(languageCode: "en"),
            SubtitleTrack(languageCode: "ja")
        ],
        availableAudioTracks: [
            AudioTrack(languageCode: "ja"),
            AudioTrack(languageCode: "en")
        ],
        onSelect: { _, _ in }
    )
}

#Preview("僅字幕") {
    MediaSelectionView(
        videoTitle: "只有字幕的影片",
        videoCount: 1,
        availableSubtitles: [
            SubtitleTrack(languageCode: "zh-TW"),
            SubtitleTrack(languageCode: "en")
        ],
        availableAudioTracks: [],
        onSelect: { _, _ in }
    )
}

#Preview("僅音軌") {
    MediaSelectionView(
        videoTitle: "只有多音軌的影片",
        videoCount: 1,
        availableSubtitles: [],
        availableAudioTracks: [
            AudioTrack(languageCode: "ja"),
            AudioTrack(languageCode: "en"),
            AudioTrack(languageCode: "zh")
        ],
        onSelect: { _, _ in }
    )
}

#Preview("播放清單") {
    MediaSelectionView(
        videoTitle: nil,
        videoCount: 5,
        availableSubtitles: [
            SubtitleTrack(languageCode: "zh-TW"),
            SubtitleTrack(languageCode: "ja")
        ],
        availableAudioTracks: [
            AudioTrack(languageCode: "ja")
        ],
        onSelect: { _, _ in }
    )
}
