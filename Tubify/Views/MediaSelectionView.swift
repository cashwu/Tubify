import SwiftUI

func clearSelectedSubtitles(_ selectedLanguages: inout Set<String>) {
    selectedLanguages.removeAll()
}

/// 媒體選項選擇視窗（字幕 + 音軌）
struct MediaSelectionView: View {
    let videoTitle: String?  // 單一影片標題，播放清單為 nil
    let videoCount: Int      // 影片數量（播放清單用）
    let availableSubtitles: [SubtitleTrack]
    let availableAudioTracks: [AudioTrack]
    let parentWindowHeight: CGFloat  // 主視窗高度，視窗高度依此比例計算
    let onSelect: (SubtitleSelection?, AudioSelection?) -> Void

    @State private var selectedSubtitleIDs: Set<String> = []
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

    /// 是否有任何可選項目（音軌需要超過 1 個才算有選項）
    private var hasOptions: Bool {
        !filteredSubtitles.isEmpty || filteredAudioTracks.count > 1
    }

    /// 視窗高度為主視窗的 75%，主視窗過矮時至少 250
    private var windowHeight: CGFloat {
        max(parentWindowHeight * 0.75, 250)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題欄
            HStack {
                Text("選擇下載選項")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // 影片資訊
            HStack {
                if let title = videoTitle {
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("\(videoCount) 部影片")
                        .font(.callout)
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
                    Section {
                        ForEach(filteredSubtitles) { track in
                            Toggle(isOn: Binding(
                                get: { selectedSubtitleIDs.contains(track.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedSubtitleIDs.insert(track.id)
                                    } else {
                                        selectedSubtitleIDs.remove(track.id)
                                    }
                                }
                            )) {
                                HStack(spacing: 4) {
                                    Text(track.displayName)
                                    Text("(\(track.languageCode))")
                                        .foregroundStyle(.tertiary)
                                        .font(.caption)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    } header: {
                        HStack {
                            Text("字幕（可多選）")
                            Spacer()
                            Button("全部取消") {
                                clearSelectedSubtitles(&selectedSubtitleIDs)
                            }
                            .buttonStyle(.borderless)
                            .font(.callout)
                        }
                    }
                }

                // 音軌區塊（只有超過 1 個音軌時才顯示選擇）
                if filteredAudioTracks.count > 1 {
                    Section("音軌（單選）") {
                        Picker("", selection: $selectedAudioLanguage) {
                            Text("預設音軌").tag(nil as String?)
                            ForEach(filteredAudioTracks) { track in
                                HStack(spacing: 4) {
                                    Text(track.languageName)
                                    Text("(\(track.languageCode))")
                                        .foregroundStyle(.tertiary)
                                        .font(.caption)
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
                    let subtitleSelection = SubtitleSelection(
                        tracks: filteredSubtitles.filter { selectedSubtitleIDs.contains($0.id) }
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
            // 預設選擇所有過濾後的上傳字幕；自動字幕需由使用者主動勾選
            selectedSubtitleIDs = Set(filteredSubtitles.filter { !$0.isAutomatic }.map(\.id))
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
            SubtitleTrack(languageCode: "en"),
            SubtitleTrack(languageCode: "ja"),
            .automatic(.traditionalChinese, captionKey: "zh-Hant-en", kind: .translated)
        ],
        availableAudioTracks: [
            AudioTrack(languageCode: "ja"),
            AudioTrack(languageCode: "en")
        ],
        parentWindowHeight: 600,
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
        parentWindowHeight: 600,
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
        parentWindowHeight: 600,
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
        parentWindowHeight: 600,
        onSelect: { _, _ in }
    )
}
