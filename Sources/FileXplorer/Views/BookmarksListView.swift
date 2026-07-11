import SwiftUI
import UniformTypeIdentifiers

/// MiXplorer의 "루트 없이 전체 스토리지 접근"과 가장 가까운 iOS 대안.
/// 사용자가 UIDocumentPicker로 폴더를 직접 골라야만 해당 폴더에 지속 접근할 수 있다.
struct BookmarksListView: View {
    @EnvironmentObject var bookmarkStore: BookmarkStore
    @State private var showingPicker = false

    var body: some View {
        List {
            ForEach(bookmarkStore.bookmarks) { bookmark in
                if let url = bookmarkStore.resolve(bookmark) {
                    NavigationLink(bookmark.displayName) {
                        FileBrowserView(rootURL: url, rootTitle: bookmark.displayName)
                    }
                }
            }
            .onDelete { indexSet in
                indexSet.map { bookmarkStore.bookmarks[$0] }.forEach(bookmarkStore.remove)
            }
        }
        .navigationTitle("연결된 폴더")
        .toolbar {
            Button {
                showingPicker = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                bookmarkStore.add(url: url)
            }
        }
        .overlay {
            if bookmarkStore.bookmarks.isEmpty {
                EmptyStateView(
                    systemImage: "folder.badge.plus",
                    title: "연결된 폴더가 없습니다",
                    message: "+ 버튼을 눌러 iCloud Drive나 다른 앱의 폴더를 연결하세요"
                )
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
