import SwiftUI
import UniformTypeIdentifiers

/// 主視窗
@MainActor
struct ContentView: View {
    @State private var downloadManager = DownloadManager.shared
    @State private var isTargeted = false
    @State private var showingSettings = false
    @State private var needsFullDiskAccess = false
    @State private var ytdlpNotInstalled = false
    @State private var urlErrorMessage: String?
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 權限提示橫幅
            if needsFullDiskAccess {
                permissionBanner
            }

            // yt-dlp 安裝提示橫幅
            if ytdlpNotInstalled {
                ytdlpBanner
            }

            // 主要內容區域
            if downloadManager.tasks.isEmpty {
                EmptyStateView()
            } else {
                taskListView
            }

            Divider()

            // 底部工具列
            bottomToolbar
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            // 拖放指示器
            if isTargeted {
                dropOverlay
            }
        }
        .onDrop(of: [.url, .text, .plainText], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            checkPermissions()
            setupPasteShortcut()
            Task {
                await checkYTDLP()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
            Task {
                await checkYTDLP()
            }
        }
        .alert("URL 錯誤", isPresented: Binding(
            get: { urlErrorMessage != nil },
            set: { if !$0 { urlErrorMessage = nil } }
        )) {
            Button("確定") {
                urlErrorMessage = nil
            }
        } message: {
            Text(urlErrorMessage ?? "")
        }
        .alert("清除全部", isPresented: $showDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task {
                    await downloadManager.clearAllTasks()
                }
            }
        } message: {
            Text("確定要清除所有下載任務嗎？此操作無法復原。")
        }
    }

    // MARK: - 權限提示橫幅

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 33))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("完整磁碟存取")
                    .font(.system(size: 26, weight: .bold))
                Text("使用 Safari cookies 需要完整磁碟存取權限")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("前往授權") {
                PermissionService.shared.openFullDiskAccessSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.system(size: 18))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - yt-dlp 安裝提示橫幅

    private var ytdlpBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 33))
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("yt-dlp 未安裝")
                    .font(.system(size: 26, weight: .bold))
                Text("需要安裝 yt-dlp 才能下載影片")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("前往安裝") {
                if let url = URL(string: "https://github.com/yt-dlp/yt-dlp") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.system(size: 18))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - 權限檢查

    private func checkPermissions() {
        let command = UserDefaults.standard.string(forKey: AppSettingsKeys.downloadCommand)
            ?? AppSettingsDefaults.downloadCommand
        let usesSafariCookies = PermissionService.shared.commandUsesSafariCookies(command)
        let hasAccess = PermissionService.shared.hasFullDiskAccess()
        needsFullDiskAccess = usesSafariCookies && !hasAccess
    }

    // MARK: - 檢查 yt-dlp

    private func checkYTDLP() async {
        let path = await YTDLPService.shared.findYTDLPPath()
        ytdlpNotInstalled = (path == nil)
    }

    // MARK: - 貼上快捷鍵設定

    private func setupPasteShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 檢查是否為 ⌘V
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                pasteFromClipboard()
                return nil // 消耗此事件
            }
            return event
        }
    }

    /// 從剪貼簿貼上
    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        processTextInput(string)
    }

    // MARK: - 任務列表

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(downloadManager.tasks) { task in
                    VStack(spacing: 0) {
                        DownloadItemView(
                            task: task,
                            onRemove: {
                                Task {
                                    await downloadManager.removeTask(task)
                                }
                            },
                            onRetry: {
                                downloadManager.retryTask(task)
                            },
                            onShowInFinder: {
                                downloadManager.showInFinder(task)
                            },
                            onPause: {
                                Task {
                                    await downloadManager.pauseTask(task)
                                }
                            },
                            onResume: {
                                downloadManager.resumeTask(task)
                            }
                        )

                        if task != downloadManager.tasks.last {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 拖放覆蓋層

    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.1)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)

                Text("放開以新增下載")
                    .font(.system(size: 33))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10]))
                .foregroundStyle(Color.accentColor)
                .padding(20)
        }
    }

    // MARK: - 底部工具列

    private var bottomToolbar: some View {
        HStack {
            // 設定按鈕
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 21))
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("設定")

            // 暫停全部按鈕
            if downloadManager.tasks.contains(where: { $0.status == .downloading || $0.status == .pending }) {
                Button(action: {
                    Task { await downloadManager.pauseAll() }
                }) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("暫停全部")
            }

            // 繼續全部按鈕
            if downloadManager.tasks.contains(where: { $0.status == .paused }) {
                Button(action: {
                    downloadManager.resumeAll()
                }) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("繼續全部")
            }

            Spacer()

            // 任務計數
            Text(taskCountText)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            Spacer()

            // 清除已完成按鈕
            if downloadManager.tasks.contains(where: { $0.status == .completed }) {
                Button(action: {
                    downloadManager.clearCompletedTasks()
                }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("清除已完成")
            }

            // 清除全部按鈕
            if !downloadManager.tasks.isEmpty {
                Button(action: {
                    showDeleteAllAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("清除全部")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - 任務計數文字

    private var taskCountText: String {
        let total = downloadManager.tasks.count
        let downloading = downloadManager.tasks.filter { $0.status == .downloading }.count
        let completed = downloadManager.tasks.filter { $0.status == .completed }.count
        let pending = downloadManager.tasks.filter { $0.status == .pending }.count
        let paused = downloadManager.tasks.filter { $0.status == .paused }.count
        let scheduled = downloadManager.tasks.filter { $0.status == .scheduled }.count

        if total == 0 {
            return "沒有下載任務"
        }

        var parts: [String] = ["共 \(total) 個"]

        if downloading > 0 {
            parts.append("下載中 \(downloading)")
        }
        if pending > 0 {
            parts.append("等待中 \(pending)")
        }
        if paused > 0 {
            parts.append("暫停 \(paused)")
        }
        if scheduled > 0 {
            parts.append("首播 \(scheduled)")
        }
        if completed > 0 {
            parts.append("已完成 \(completed)")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - 拖放處理

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // 嘗試載入 URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in
                            handleURLValidationResult(downloadManager.addURL(url.absoluteString))
                        }
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            handleURLValidationResult(downloadManager.addURL(url.absoluteString))
                        }
                    }
                }
            }
            // 嘗試載入文字
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let text = item as? String {
                        Task { @MainActor in
                            processTextInput(text)
                        }
                    } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            processTextInput(text)
                        }
                    }
                }
            }
        }
    }

    /// 處理 URL 驗證結果
    private func handleURLValidationResult(_ result: URLValidationResult) {
        switch result {
        case .success, .alreadyExists:
            break
        case .invalidFormat:
            urlErrorMessage = "URL 格式不正確"
        case .notYouTubeURL:
            urlErrorMessage = "僅支援 YouTube 網址"
        }
    }

    /// 處理文字輸入（可能包含多個 URL）
    private func processTextInput(_ text: String) {
        // 分割可能的多個 URL
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 只處理看起來像 URL 的文字
            guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ||
                  trimmed.contains("youtube.com") || trimmed.contains("youtu.be") else {
                continue
            }

            handleURLValidationResult(downloadManager.addURL(trimmed))
        }
    }

}

#Preview {
    ContentView()
}
