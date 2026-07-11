import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case name, size, date, kind
    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "이름"
        case .size: return "크기"
        case .date: return "날짜"
        case .kind: return "종류"
        }
    }
}

enum SortDirection {
    case ascending, descending
}

func sortFileItems(_ items: [FileItem], by option: SortOption, direction: SortDirection, foldersFirst: Bool = true) -> [FileItem] {
    items.sorted { a, b in
        if foldersFirst && a.isDirectory != b.isDirectory {
            return a.isDirectory && !b.isDirectory
        }
        let ascending: Bool
        switch option {
        case .name:
            ascending = a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .size:
            ascending = a.size < b.size
        case .date:
            ascending = (a.modificationDate ?? .distantPast) < (b.modificationDate ?? .distantPast)
        case .kind:
            ascending = a.fileExtension < b.fileExtension
        }
        return direction == .ascending ? ascending : !ascending
    }
}
