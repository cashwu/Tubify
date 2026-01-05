import SwiftUI
import AppKit

/// 單個下載項目視圖
struct DownloadItemView: View {
    let task: DownloadTask
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onShowInFinder: () -> Void

    @State private var isHovering = false
    @State private var showDeleteAlert = false

    /// 複製 URL 到剪貼簿
    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(task.url, forType: .string)
    }

    /// 用預設瀏覽器打開 URL
    private func openInBrowser() {
        if let url = URL(string: task.url) {
            NSWorkspace.shared.open(url)
        }
    }

    /// 檢查是否為 Safari cookies 權限相關錯誤
    private var isPermissionError: Bool {
        guard let error = task.errorMessage else { return false }
        // 只有當錯誤訊息明確提到 Safari cookies 時才視為權限問題
        let isCookiesError = error.contains("cookies") || error.contains("Safari") ||
                             error.contains("Cookies.binarycookies")
        let isPermError = error.contains("Operation not permitted") || error.contains("Permission denied")
        return isCookiesError && isPermError
    }

    var body: some View {
        HStack(spacing: 12) {
            // 縮圖
            thumbnailView

            // 資訊
            VStack(alignment: .leading, spacing: 4) {
                // 標題
                Text(task.title)
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // URL
                Text(task.url)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // 進度條和狀態
                HStack(spacing: 8) {
                    if task.status == .downloading {
                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)


                        Text("\(Int(task.progress * 100))%")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        statusBadge
                    }


                }
            }

            Spacer()

            // 操作按鈕
            actionButtons
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .alert("取消下載", isPresented: $showDeleteAlert) {
            Button("繼續下載", role: .cancel) {}
            Button("取消下載", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("確定要取消正在進行的下載嗎？")
        }
        .contextMenu {
            Button {
                copyURL()
            } label: {
                Label("複製連結", systemImage: "doc.on.doc")
            }

            Button {
                openInBrowser()
            } label: {
                Label("在瀏覽器中打開", systemImage: "safari")
            }
        }
    }

    // MARK: - 縮圖視圖

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailURL = task.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    thumbnailPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    thumbnailPlaceholder
                @unknown default:
                    thumbnailPlaceholder
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 120, height: 68)
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 33))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - 狀態標籤

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            switch task.status {
            case .pending:
                Image(systemName: "clock")
                Text("等待中")
            case .fetchingInfo:
                ProgressView()
                    .controlSize(.small)
                Text("獲取資訊中...")
            case .downloading:
                ProgressView()
                    .controlSize(.small)
                Text("下載中")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("完成")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                if isPermissionError {
                    Text("權限不足")
                    Button("前往設定") {
                        PermissionService.shared.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 18))
                } else {
                    Text("失敗")
                }
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("已取消")
            case .scheduled:
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.yellow)
                if let date = task.premiereDate {
                    Text(formatPremiereTime(date))
                } else {
                    Text("尚未首播")
                }
            }
        }
        .font(.system(size: 18))
        .foregroundStyle(.secondary)
    }

    /// 格式化首播時間顯示
    private func formatPremiereTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date) + " 首播 (預計時間)"
    }

    // MARK: - 操作按鈕

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // 在 Finder 中顯示（已完成時）
            if task.status == .completed {
                Button(action: onShowInFinder) {
                    Image(systemName: "folder")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .help("在 Finder 中顯示")
            }

            // 重試按鈕（失敗、取消或首播尚未開始時）
            if task.status == .failed || task.status == .cancelled || task.status == .scheduled {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 21))
                }
                .buttonStyle(.borderless)
                .help("重試")
            }

            // 移除/取消按鈕
            Button(action: {
                if task.status == .downloading {
                    showDeleteAlert = true
                } else {
                    onRemove()
                }
            }) {
                Image(systemName: task.status == .downloading ? "xmark.circle" : "trash")
                    .font(.system(size: 21))
                    .foregroundStyle(task.status == .downloading ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(task.status == .downloading ? "取消下載" : "移除")
        }
        .opacity(isHovering ? 1 : 0.5)
    }
}

#Preview {
    VStack(spacing: 0) {
        DownloadItemView(
            task: DownloadTask(
                url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                title: "Rick Astley - Never Gonna Give You Up",
                thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
                status: .downloading,
                progress: 0.45
            ),
            onRemove: {},
            onRetry: {},
            onShowInFinder: {}
        )

        Divider()

        DownloadItemView(
            task: DownloadTask(
                url: "https://www.youtube.com/watch?v=abc123",
                title: "Some Video Title That Is Very Long And Will Be Truncated",
                status: .pending
            ),
            onRemove: {},
            onRetry: {},
            onShowInFinder: {}
        )

        Divider()

        DownloadItemView(
            task: DownloadTask(
                url: "https://www.youtube.com/watch?v=xyz789",
                title: "Completed Video",
                status: .completed
            ),
            onRemove: {},
            onRetry: {},
            onShowInFinder: {}
        )
    }
    .padding()
    .frame(width: 600)
}
