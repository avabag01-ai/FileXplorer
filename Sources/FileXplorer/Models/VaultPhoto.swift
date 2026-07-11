import Foundation

/// 보관함에 저장된 사진 한 장.
/// 파일명 앞부분에 epoch millis를 담아 촬영시각을 결정적으로 복원한다.
struct VaultPhoto: Identifiable, Hashable {
    let id: String        // 파일 경로
    let url: URL
    let category: String
    let createdAt: Date

    init(url: URL, category: String) {
        self.id = url.path
        self.url = url
        self.category = category
        // 파일명 "<millis>_<uuid>.jpg" 에서 millis 파싱, 실패 시 파일 수정일 사용.
        let name = url.deletingPathExtension().lastPathComponent
        if let millisPart = name.split(separator: "_").first, let millis = Double(millisPart) {
            self.createdAt = Date(timeIntervalSince1970: millis / 1000)
        } else {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            self.createdAt = mod ?? .distantPast
        }
    }
}
