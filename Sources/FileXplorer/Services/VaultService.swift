import Foundation

/// 영업/현장 사진을 아이폰 기본 "사진" 앱과 완전히 분리해 보관하는 저장소.
///
/// 핵심 설계:
/// - 저장 위치를 **Application Support/Vault** 로 둔다. 앱 샌드박스라 Photos 라이브러리에
///   절대 나타나지 않고, `UIFileSharingEnabled`(Documents만 노출)로도 보이지 않는다.
/// - 이 서비스는 Photos 프레임워크(PHPhotoLibrary 등)를 **일절 사용하지 않는다.**
///   따라서 여기에 저장된 사진이 기본 사진앱에 유출될 경로 자체가 없다.
enum VaultService {
    enum VaultError: LocalizedError {
        case cannotLocateStorage
        case invalidCategoryName
        var errorDescription: String? {
            switch self {
            case .cannotLocateStorage: return "보관함 저장 위치를 찾을 수 없습니다"
            case .invalidCategoryName: return "카테고리 이름이 올바르지 않습니다"
            }
        }
    }

    static let defaultCategory = "미분류"

    /// 저장 루트. 테스트에서 격리하기 위해 override 가능.
    static var rootOverride: URL?

    static var root: URL {
        if let rootOverride { return rootOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Vault", isDirectory: true)
    }

    // MARK: - 카테고리

    @discardableResult
    static func ensureRoot() throws -> URL {
        let r = root
        try FileManager.default.createDirectory(at: r, withIntermediateDirectories: true)
        return r
    }

    static func categories() -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @discardableResult
    static func createCategory(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { throw VaultError.invalidCategoryName }
        let dir = root.appendingPathComponent(trimmed, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return trimmed
    }

    // MARK: - 사진 저장/조회

    /// JPEG 데이터를 지정 카테고리에 저장한다. (카메라·가져오기 공통 진입점)
    @discardableResult
    static func saveJPEG(_ data: Data, category: String = defaultCategory, date: Date) throws -> VaultPhoto {
        let cat = try createCategory(category)
        let dir = root.appendingPathComponent(cat, isDirectory: true)
        let millis = Int(date.timeIntervalSince1970 * 1000)
        let filename = "\(millis)_\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return VaultPhoto(url: fileURL, category: cat)
    }

    static func photos(in category: String) -> [VaultPhoto] {
        let dir = root.appendingPathComponent(category, isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .map { VaultPhoto(url: $0, category: category) }
            .sorted { $0.createdAt > $1.createdAt }   // 최신 먼저
    }

    static func allPhotos() -> [VaultPhoto] {
        categories().flatMap { photos(in: $0) }.sorted { $0.createdAt > $1.createdAt }
    }

    static func count(in category: String) -> Int {
        photos(in: category).count
    }

    static func delete(_ photo: VaultPhoto) throws {
        try FileManager.default.removeItem(at: photo.url)
    }
}
