import SwiftUI

/// 空白狀態視圖
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            // 下載圖示
            Image(systemName: "arrow.down.to.line.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("拖放或貼上影片連結")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("支援單一影片和播放清單")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 500, height: 400)
}
