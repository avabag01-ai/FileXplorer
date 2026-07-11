import XCTest
@testable import FileXplorer

final class FileServiceTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fx-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeFile(_ name: String, _ contents: String) throws -> URL {
        let url = tmp.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testCreateFolderAndListSkipsHidden() throws {
        try FileService.createFolder(named: "sub", in: tmp)
        _ = try writeFile("visible.txt", "hi")
        _ = try writeFile(".hidden", "secret")

        let items = try FileService.contents(of: tmp)
        let names = Set(items.map(\.name))
        XCTAssertTrue(names.contains("sub"))
        XCTAssertTrue(names.contains("visible.txt"))
        XCTAssertFalse(names.contains(".hidden"), "숨김 파일은 목록에서 제외돼야 한다")
        XCTAssertTrue(items.first { $0.name == "sub" }!.isDirectory)
    }

    func testCopyCreatesConflictRenamedDuplicate() throws {
        let src = try writeFile("doc.txt", "payload")
        let dest = tmp.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let item = FileItem(url: src)

        try FileService.copy([item], to: dest)
        try FileService.copy([item], to: dest) // 두 번째 복사 → 이름 충돌

        let names = Set(try FileService.contents(of: dest).map(\.name))
        XCTAssertTrue(names.contains("doc.txt"))
        XCTAssertTrue(names.contains("doc (1).txt"), "충돌 시 ' (1)' 접미사가 붙어야 한다")
    }

    func testMoveRemovesFromSource() throws {
        let src = try writeFile("move-me.txt", "x")
        let dest = tmp.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        try FileService.move([FileItem(url: src)], to: dest)

        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("move-me.txt").path))
    }

    func testDeleteRemovesFilesAndFolders() throws {
        let f = try writeFile("gone.txt", "x")
        try FileService.createFolder(named: "goneDir", in: tmp)
        let dirItem = FileItem(url: tmp.appendingPathComponent("goneDir"))

        try FileService.delete([FileItem(url: f), dirItem])

        XCTAssertFalse(FileManager.default.fileExists(atPath: f.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirItem.url.path))
    }

    func testRename() throws {
        let f = try writeFile("old.txt", "x")
        try FileService.rename(FileItem(url: f), to: "new.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("new.txt").path))
    }

    func testRecursiveSearchFindsNested() throws {
        try FileService.createFolder(named: "deep", in: tmp)
        let deep = tmp.appendingPathComponent("deep")
        try "x".write(to: deep.appendingPathComponent("needle-report.log"), atomically: true, encoding: .utf8)
        _ = try writeFile("unrelated.txt", "x")

        let hits = FileService.search(query: "needle", in: tmp, recursive: true)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.name, "needle-report.log")

        let shallow = FileService.search(query: "needle", in: tmp, recursive: false)
        XCTAssertTrue(shallow.isEmpty, "비재귀 검색은 최상위만 봐야 한다")
    }

    func testSortByNameAndDirectionAndFoldersFirst() throws {
        try FileService.createFolder(named: "zeta-dir", in: tmp)
        _ = try writeFile("apple.txt", "x")
        _ = try writeFile("banana.txt", "x")

        let items = try FileService.contents(of: tmp)
        let asc = sortFileItems(items, by: .name, direction: .ascending)
        XCTAssertEqual(asc.first?.name, "zeta-dir", "foldersFirst면 폴더가 먼저 온다")
        XCTAssertEqual(asc.dropFirst().map(\.name), ["apple.txt", "banana.txt"])

        let desc = sortFileItems(items, by: .name, direction: .descending)
        XCTAssertEqual(desc.filter { !$0.isDirectory }.map(\.name), ["banana.txt", "apple.txt"])
    }
}
