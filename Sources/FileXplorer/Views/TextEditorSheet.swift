import SwiftUI

struct TextEditorSheet: View {
    let item: FileItem
    @State private var text: String = ""
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let loadError {
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        do {
            text = try String(contentsOf: item.url, encoding: .utf8)
        } catch {
            loadError = "파일을 열 수 없습니다: \(error.localizedDescription)"
        }
    }

    private func save() {
        try? text.write(to: item.url, atomically: true, encoding: .utf8)
        dismiss()
    }
}
