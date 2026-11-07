import SwiftUI

/// 下載項目的改名視窗（rename-download-title R2、R3）
struct RenameTitleView: View {
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isNameFieldFocused: Bool

    init(currentName: String, onConfirm: @escaping (String) -> Void) {
        self.onConfirm = onConfirm
        _name = State(initialValue: currentName)
    }

    /// 去掉前後空白後是空字串時不能確認；與原名相同由 DownloadManager 視為沒有變更
    static func canConfirm(_ input: String) -> Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("輸入新的檔案名稱：")

            TextField("檔案名稱", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 360)
                .focused($isNameFieldFocused)
                .accessibilityLabel("檔案名稱")

            HStack {
                Spacer()

                // Esc 對應 cancelAction、Enter 對應 defaultAction；按鈕停用時 Enter 不會觸發
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("重新命名") {
                    onConfirm(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!Self.canConfirm(name))
            }
        }
        .padding(20)
        .onAppear {
            isNameFieldFocused = true
        }
    }
}

#Preview {
    RenameTitleView(currentName: "觸控屏 Macbook，最大的優點竟然是... | 大耳朵 TV") { _ in }
}
