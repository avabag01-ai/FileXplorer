import Foundation

struct FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?

    init(url: URL) {
        self.url = url
        self.id = url.path
        self.name = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.modificationDate = values?.contentModificationDate
    }

    var fileExtension: String { url.pathExtension.lowercased() }

    enum Kind {
        case folder, image, video, audio, archive, text, pdf, other
    }

    var kind: Kind {
        if isDirectory { return .folder }
        let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "bmp", "webp"]
        let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]
        let audioExts: Set<String> = ["mp3", "m4a", "wav", "flac", "aac"]
        let archiveExts: Set<String> = ["zip", "cbz"]
        let textExts: Set<String> = ["txt", "md", "json", "xml", "log", "swift", "c", "h", "py", "js", "html", "css", "yml", "yaml"]

        if imageExts.contains(fileExtension) { return .image }
        if videoExts.contains(fileExtension) { return .video }
        if audioExts.contains(fileExtension) { return .audio }
        if archiveExts.contains(fileExtension) { return .archive }
        if fileExtension == "pdf" { return .pdf }
        if textExts.contains(fileExtension) { return .text }
        return .other
    }

    var systemIconName: String {
        switch kind {
        case .folder: return "folder.fill"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "doc.zipper"
        case .text: return "doc.text"
        case .pdf: return "doc.richtext"
        case .other: return "doc"
        }
    }
}
