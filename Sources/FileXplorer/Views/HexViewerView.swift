import SwiftUI

struct HexViewerView: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss
    @State private var lines: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .padding(8)
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: item.url, options: .mappedIfSafe) else { return }
        // 성능을 위해 미리보기는 앞부분 64KB로 제한 (HexDump 참고)
        lines = HexDump.lines(from: data)
    }
}
