import SwiftUI
import UniformTypeIdentifiers

/// 主視窗
struct ContentView: View {
    @State private var downloadManager = DownloadManager.shared
    @State private var isTargeted = false
    @State private var showingSettings = false
    @State private var needsFullDiskAccess = false

    var body: some View {
        VStack(spacing: 0) {
            // 權限提示橫幅
            if needsFullDiskAccess {
                permissionBanner
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    // MARK: - 權限提示橫幅

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("完整磁碟存取")
                    .font(.headline)
                Text("使用 Safari cookies 需要完整磁碟存取權限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("前往授權") {
                PermissionService.shared.openFullDiskAccessSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
                                downloadManager.removeTask(task)
                            },
                            onRetry: {
                                downloadManager.retryTask(task)
                            },
                            onShowInFinder: {
                                downloadManager.showInFinder(task)
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
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("放開以新增下載")
                    .font(.title2)
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
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help("設定")

            Spacer()

            // 任務計數
            Text(taskCountText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // 清除已完成按鈕
            if downloadManager.tasks.contains(where: { $0.status == .completed }) {
                Button(action: {
                    downloadManager.clearCompletedTasks()
                }) {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("清除已完成")
            }

            // 清除全部按鈕
            if !downloadManager.tasks.isEmpty {
                Button(action: {
                    downloadManager.clearAllTasks()
                }) {
                    Image(systemName: "trash")
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

        if total == 0 {
            return "沒有下載任務"
        }

        var parts: [String] = []

        if downloading > 0 {
            parts.append("下載中 \(downloading)")
        }
        if pending > 0 {
            parts.append("等待中 \(pending)")
        }
        if completed > 0 {
            parts.append("已完成 \(completed)")
        }

        return parts.isEmpty ? "\(total) 個任務" : parts.joined(separator: " · ")
    }

    // MARK: - 拖放處理

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // 嘗試載入 URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in
                            downloadManager.addURL(url.absoluteString)
                        }
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            downloadManager.addURL(url.absoluteString)
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

    /// 處理文字輸入（可能包含多個 URL）
    private func processTextInput(_ text: String) {
        // 分割可能的多個 URL
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && (trimmed.contains("youtube.com") || trimmed.contains("youtu.be")) {
                downloadManager.addURL(trimmed)
            }
        }
    }

}

#Preview {
    ContentView()
}
