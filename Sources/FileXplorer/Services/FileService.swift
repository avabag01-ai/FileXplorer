import Foundation

enum FileServiceError: LocalizedError {
    case operationFailed(String)
    var errorDescription: String? {
        switch self {
        case .operationFailed(let msg): return msg
        }
    }
}

/// 앱 샌드박스 내부 및 사용자가 명시적으로 연결(bookmark)한 외부 폴더에 대한 파일 CRUD.
/// 루트 권한이 필요한 시스템 영역 접근이나 다른 앱 소유의 파일 접근은 iOS 정책상 불가능하다.
struct FileService {
    static func contents(of directory: URL) throws -> [FileItem] {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls.map { FileItem(url: $0) }
    }

    static func createFolder(named name: String, in directory: URL) throws {
        let target = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    }

    static func rename(_ item: FileItem, to newName: String) throws {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: item.url, to: newURL)
    }

    static func delete(_ items: [FileItem]) throws {
        for item in items {
            try FileManager.default.removeItem(at: item.url)
        }
    }

    static func copy(_ items: [FileItem], to destination: URL) throws {
        for item in items {
            let target = destination.appendingPathComponent(item.name)
            var finalTarget = target
            var counter = 1
            while FileManager.default.fileExists(atPath: finalTarget.path) {
                let base = target.deletingPathExtension().lastPathComponent
                let ext = target.pathExtension
                let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                finalTarget = destination.appendingPathComponent(newName)
                counter += 1
            }
            try FileManager.default.copyItem(at: item.url, to: finalTarget)
        }
    }

    static func move(_ items: [FileItem], to destination: URL) throws {
        for item in items {
            let target = destination.appendingPathComponent(item.name)
            try FileManager.default.moveItem(at: item.url, to: target)
        }
    }

    static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    static func search(query: String, in directory: URL, recursive: Bool) -> [FileItem] {
        guard !query.isEmpty else { return [] }
        var results: [FileItem] = []
        if recursive {
            if let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            ) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent.localizedCaseInsensitiveContains(query) {
                        results.append(FileItem(url: url))
                    }
                }
            }
        } else {
            let items = (try? contents(of: directory)) ?? []
            results = items.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return results
    }
}
