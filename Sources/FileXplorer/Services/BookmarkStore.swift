import Foundation

struct SavedBookmark: Identifiable, Codable {
    var id: UUID = UUID()
    var displayName: String
    var bookmarkData: Data
}

/// 사용자가 UIDocumentPicker로 선택한 외부 폴더(예: iCloud Drive, 다른 앱의 문서 폴더)에
/// 앱을 재시작해도 계속 접근할 수 있도록 security-scoped bookmark로 저장/복원한다.
/// iOS 샌드박스 정책상 사용자가 명시적으로 선택한 폴더에만 접근 가능하며,
/// 안드로이드처럼 전체 파일시스템을 자유롭게 스캔하는 것은 불가능하다.
final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var bookmarks: [SavedBookmark] = []

    private let defaultsKey = "com.filexplorer.bookmarks"

    init() {
        load()
    }

    func add(url: URL, displayName: String? = nil) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let entry = SavedBookmark(displayName: displayName ?? url.lastPathComponent, bookmarkData: data)
            bookmarks.append(entry)
            persist()
        } catch {
            print("Bookmark creation failed: \(error)")
        }
    }

    func remove(_ bookmark: SavedBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        persist()
    }

    func resolve(_ bookmark: SavedBookmark) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark.bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return url
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([SavedBookmark].self, from: data) {
            bookmarks = decoded
        }
    }
}
