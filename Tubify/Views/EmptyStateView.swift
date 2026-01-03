import SwiftUI

/// 空白狀態視圖
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            // 下載圖示
            Image(systemName: "arrow.down.to.line.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("拖放 YouTube 連結到這裡")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("支援單一影片和播放清單")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 500, height: 400)
}
