import XCTest
@testable import FileXplorer

final class VaultServiceTests: XCTestCase {
    var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-tests-\(UUID().uuidString)")
        VaultService.rootOverride = tmpRoot
        try VaultService.ensureRoot()
    }

    override func tearDownWithError() throws {
        VaultService.rootOverride = nil
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    private func jpeg(_ label: String) -> Data {
        // 실제 JPEG일 필요는 없음 — 저장/조회 경로만 검증.
        Data("fake-jpeg-\(label)".utf8)
    }

    func testSaveLandsInSandboxNotPhotos() throws {
        let photo = try VaultService.saveJPEG(jpeg("a"), category: "고객사A", date: Date(timeIntervalSince1970: 1_000))
        XCTAssertTrue(FileManager.default.fileExists(atPath: photo.url.path))
        // 저장 경로가 보관함 루트(앱 샌드박스) 하위인지 확인
        XCTAssertTrue(photo.url.path.hasPrefix(tmpRoot.path), "사진은 반드시 보관함 루트 안에 있어야 한다")
        XCTAssertEqual(photo.category, "고객사A")
    }

    func testRealRootIsUnderApplicationSupport() {
        VaultService.rootOverride = nil
        defer { VaultService.rootOverride = tmpRoot }
        // 실제 저장 위치는 Application Support 하위의 Vault (Documents 아님 → 파일공유 미노출)
        XCTAssertTrue(VaultService.root.path.contains("Application Support"), VaultService.root.path)
        XCTAssertEqual(VaultService.root.lastPathComponent, "Vault")
        XCTAssertFalse(VaultService.root.path.contains("/Documents/"), "Documents에 두면 Files 앱에 노출될 수 있다")
    }

    func testCategoriesAndCounts() throws {
        try VaultService.saveJPEG(jpeg("1"), category: "현장1", date: Date(timeIntervalSince1970: 10))
        try VaultService.saveJPEG(jpeg("2"), category: "현장1", date: Date(timeIntervalSince1970: 20))
        try VaultService.saveJPEG(jpeg("3"), category: "현장2", date: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(VaultService.categories(), ["현장1", "현장2"])
        XCTAssertEqual(VaultService.count(in: "현장1"), 2)
        XCTAssertEqual(VaultService.count(in: "현장2"), 1)
        XCTAssertEqual(VaultService.allPhotos().count, 3)
    }

    func testPhotosSortedNewestFirst() throws {
        try VaultService.saveJPEG(jpeg("old"), category: "c", date: Date(timeIntervalSince1970: 100))
        try VaultService.saveJPEG(jpeg("new"), category: "c", date: Date(timeIntervalSince1970: 999))
        let photos = VaultService.photos(in: "c")
        XCTAssertEqual(photos.count, 2)
        XCTAssertGreaterThan(photos[0].createdAt, photos[1].createdAt, "최신 사진이 먼저 와야 한다")
    }

    func testCreatedAtParsedFromFilename() throws {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let photo = try VaultService.saveJPEG(jpeg("t"), category: "c", date: when)
        // 밀리초 단위 반올림 오차 허용
        XCTAssertEqual(photo.createdAt.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 0.01)
    }

    func testDeleteRemovesPhoto() throws {
        let photo = try VaultService.saveJPEG(jpeg("d"), category: "c", date: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(VaultService.count(in: "c"), 1)
        try VaultService.delete(photo)
        XCTAssertEqual(VaultService.count(in: "c"), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photo.url.path))
    }

    func testInvalidCategoryRejected() {
        XCTAssertThrowsError(try VaultService.createCategory("  "))
        XCTAssertThrowsError(try VaultService.createCategory("a/b"))
    }
}
