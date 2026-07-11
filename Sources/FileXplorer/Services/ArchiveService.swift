import Foundation
// ZIPFoundation은 project.yml에 SPM 의존성으로 등록되어 있다.
// Xcode에서 File > Add Package Dependencies로 https://github.com/weichsel/ZIPFoundation.git 를
// 수동으로 추가해도 된다.
import ZIPFoundation

struct ArchiveService {
    static func extract(archive archiveURL: URL, to destination: URL) throws {
        try FileManager.default.unzipItem(at: archiveURL, to: destination)
    }

    static func createZip(from items: [FileItem], to destinationZip: URL) throws {
        guard let archive = Archive(url: destinationZip, accessMode: .create) else {
            throw FileServiceError.operationFailed("압축 파일을 생성할 수 없습니다")
        }
        for item in items {
            if item.isDirectory {
                try addDirectory(item.url, to: archive, baseURL: item.url.deletingLastPathComponent())
            } else {
                try archive.addEntry(with: item.name, relativeTo: item.url.deletingLastPathComponent())
            }
        }
    }

    private static func addDirectory(_ dirURL: URL, to archive: Archive, baseURL: URL) throws {
        guard let enumerator = FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: nil) else { return }
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
        }
    }

    static func listContents(of archiveURL: URL) throws -> [String] {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw FileServiceError.operationFailed("압축 파일을 열 수 없습니다")
        }
        return archive.map { $0.path }
    }
}
