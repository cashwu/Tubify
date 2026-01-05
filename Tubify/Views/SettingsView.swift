import SwiftUI

/// 設定視圖
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKeys.downloadCommand)
    private var downloadCommand: String = AppSettingsDefaults.downloadCommand

    @AppStorage(AppSettingsKeys.downloadFolder)
    private var downloadFolder: String = AppSettingsDefaults.downloadFolder

    @AppStorage(AppSettingsKeys.maxConcurrentDownloads)
    private var maxConcurrentDownloads: Int = AppSettingsDefaults.maxConcurrentDownloads

    @AppStorage(AppSettingsKeys.autoRemoveCompleted)
    private var autoRemoveCompleted: Bool = AppSettingsDefaults.autoRemoveCompleted

    @State private var showingFolderPicker = false
    @State private var ytdlpStatus: YTDLPStatus = .checking
    @State private var ffmpegStatus: FFmpegStatus = .checking
    @State private var fullDiskAccessStatus: FullDiskAccessStatus = .checking

    enum YTDLPStatus {
        case checking
        case found(String)
        case notFound
    }

    enum FFmpegStatus {
        case checking
        case found(String)
        case notFound
    }

    enum FullDiskAccessStatus {
        case checking
        case granted
        case notGranted
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題
            HStack {
                Text("設定")
                    .font(.system(size: 33, weight: .semibold))

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
                        Text("ffmpeg 狀態")
                        Spacer()
                        ffmpegStatusView
                    }

                    HStack {
                        Text("完整磁碟存取")
                        Spacer()
                        fullDiskAccessStatusView
                    }
                } header: {
                    Text("系統")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if case .notFound = ffmpegStatus {
                            Text("ffmpeg 用於合併高畫質影音串流、格式轉換及後製處理。安裝指令：brew install ffmpeg")
                                .font(.system(size: 18))
                                .foregroundStyle(.orange)
                        }
                        if case .notGranted = fullDiskAccessStatus, PermissionService.shared.commandUsesSafariCookies(downloadCommand) {
                            Text("使用 Safari cookies 需要完整磁碟存取權限。請在系統設定 > 隱私與安全性 > 完整磁碟存取 中加入 Tubify。")
                                .font(.system(size: 18))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // 下載設定
                Section {
                    // 下載指令
                    VStack(alignment: .leading, spacing: 4) {
                        Text("下載指令")
                        TextEditor(text: $downloadCommand)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60, maxHeight: 100)
                            .padding(4)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            }

                        Text("使用 $youtubeUrl 作為 URL 佔位符")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)

                        Button("重置為預設值") {
                            downloadCommand = AppSettingsDefaults.downloadCommand
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 18))
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

                    // 同時下載數量
                    HStack {
                        Text("同時下載數量")
                        Spacer()

                        Picker("", selection: $maxConcurrentDownloads) {
                            ForEach(1...5, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }

                    Text("同時進行下載的最大任務數量")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    // 自動移除已完成的下載
                    Toggle("下載完成後自動從列表移除", isOn: $autoRemoveCompleted)
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
            .font(.system(size: 20)) // Apply base font size to form
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await checkYTDLP()
            await checkFFmpeg()
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
                Button("前往安裝") {
                    if let url = URL(string: "https://github.com/yt-dlp/yt-dlp") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 18))
            }
        }
    }

    // MARK: - ffmpeg 狀態視圖

    @ViewBuilder
    private var ffmpegStatusView: some View {
        switch ffmpegStatus {
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
                    .foregroundStyle(.orange)
                Text("未安裝（選用）")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - 完整磁碟存取狀態視圖

    @ViewBuilder
    private var fullDiskAccessStatusView: some View {
        switch fullDiskAccessStatus {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("檢查中...")
                    .foregroundStyle(.secondary)
            }
        case .granted:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("已授權")
                    .foregroundStyle(.secondary)
            }
        case .notGranted:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("前往授權") {
                    PermissionService.shared.openFullDiskAccessSettings()
                }
                .buttonStyle(.link)
                .font(.system(size: 18))
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

    // MARK: - 檢查 ffmpeg

    private func checkFFmpeg() async {
        // 先檢查已知的 Homebrew 安裝路徑
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",      // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",          // Intel Homebrew
            "/usr/bin/ffmpeg"                 // 系統安裝
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegStatus = .found(path)
                return
            }
        }

        // 後備方案：嘗試使用 which 指令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    ffmpegStatus = .found(path)
                    return
                }
            }
        } catch {}

        ffmpegStatus = .notFound
    }

    // MARK: - 檢查完整磁碟存取權限

    private func checkFullDiskAccess() {
        fullDiskAccessStatus = PermissionService.shared.hasFullDiskAccess() ? .granted : .notGranted
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
