import SwiftUI

/// 設定視圖
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKeys.downloadCommand)
    private var downloadCommand: String = AppSettingsDefaults.downloadCommand

    @AppStorage(AppSettingsKeys.downloadFolder)
    private var downloadFolder: String = AppSettingsDefaults.downloadFolder

    @AppStorage(AppSettingsKeys.downloadInterval)
    private var downloadInterval: Double = AppSettingsDefaults.downloadInterval

    @State private var showingFolderPicker = false
    @State private var ytdlpStatus: YTDLPStatus = .checking
    @State private var hasFullDiskAccess: Bool = false

    enum YTDLPStatus {
        case checking
        case found(String)
        case notFound
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題
            HStack {
                Text("設定")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()

            Divider()

            // 設定內容
            Form {
                // 系統狀態
                Section {
                    HStack {
                        Text("yt-dlp 狀態")
                        Spacer()
                        ytdlpStatusView
                    }

                    HStack {
                        Text("完整磁碟存取")
                        Spacer()
                        fullDiskAccessStatusView
                    }
                } header: {
                    Text("系統")
                } footer: {
                    if !hasFullDiskAccess && PermissionService.shared.commandUsesSafariCookies(downloadCommand) {
                        Text("使用 Safari cookies 需要完整磁碟存取權限")
                            .foregroundStyle(.orange)
                    }
                }

                // 下載設定
                Section {
                    // 下載指令
                    VStack(alignment: .leading, spacing: 4) {
                        Text("下載指令")
                        TextEditor(text: $downloadCommand)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            }

                        Text("使用 $youtubeUrl 作為 URL 佔位符")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("重置為預設值") {
                            downloadCommand = AppSettingsDefaults.downloadCommand
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }

                    // 下載資料夾
                    HStack {
                        Text("下載資料夾")
                        Spacer()
                        Text(downloadFolderDisplay)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button("選擇...") {
                            selectDownloadFolder()
                        }
                    }

                    // 下載間隔
                    HStack {
                        Text("下載間隔")
                        Spacer()

                        TextField("", value: $downloadInterval, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)

                        Text("秒")
                            .foregroundStyle(.secondary)
                    }

                    Text("每個下載完成後，等待指定秒數再開始下一個")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("下載")
                }

                // 關於
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("日誌位置")
                        Spacer()
                        Button("打開") {
                            openLogsFolder()
                        }
                        .buttonStyle(.link)
                    }
                } header: {
                    Text("關於")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await checkYTDLP()
            checkFullDiskAccess()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 當 App 重新獲得焦點時，重新檢查權限（用戶可能剛從系統設定回來）
            checkFullDiskAccess()
        }
    }

    // MARK: - yt-dlp 狀態視圖

    @ViewBuilder
    private var ytdlpStatusView: some View {
        switch ytdlpStatus {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("檢查中...")
                    .foregroundStyle(.secondary)
            }
        case .found(let path):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(path)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .notFound:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("未安裝")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 完整磁碟存取狀態視圖

    @ViewBuilder
    private var fullDiskAccessStatusView: some View {
        if hasFullDiskAccess {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("已授權")
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("前往授權") {
                    PermissionService.shared.openFullDiskAccessSettings()
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - 下載資料夾顯示

    private var downloadFolderDisplay: String {
        let path = downloadFolder
        if path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) {
            return path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: "~"
            )
        }
        return path
    }

    // MARK: - 選擇下載資料夾

    private func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "選擇"
        panel.message = "選擇下載資料夾"

        if let currentURL = URL(string: downloadFolder) {
            panel.directoryURL = currentURL
        }

        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url.path
        }
    }

    // MARK: - 檢查 yt-dlp

    private func checkYTDLP() async {
        if let path = await YTDLPService.shared.findYTDLPPath() {
            ytdlpStatus = .found(path)
        } else {
            ytdlpStatus = .notFound
        }
    }

    // MARK: - 檢查完整磁碟存取權限

    private func checkFullDiskAccess() {
        hasFullDiskAccess = PermissionService.shared.hasFullDiskAccess()
    }

    // MARK: - 打開日誌資料夾

    private func openLogsFolder() {
        let url = LogFileManager.shared.currentLogFileURL.deletingLastPathComponent()
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    SettingsView()
}
