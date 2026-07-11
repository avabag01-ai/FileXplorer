import XCTest
@testable import FileXplorer

final class ArchiveServiceTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fx-zip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testZipSingleFileAndListContents() throws {
        let file = tmp.appendingPathComponent("hello.txt")
        try "hello world".write(to: file, atomically: true, encoding: .utf8)
        let zip = tmp.appendingPathComponent("out.zip")

        try ArchiveService.createZip(from: [FileItem(url: file)], to: zip)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path))

        let entries = try ArchiveService.listContents(of: zip)
        XCTAssertEqual(entries, ["hello.txt"])
    }

    func testZipDirectoryThenExtractRoundTrip() throws {
        // 폴더 구조 생성: folder/{a.txt, nested/b.txt}
        let folder = tmp.appendingPathComponent("folder", isDirectory: true)
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "AAA".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "BBB".write(to: nested.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let zip = tmp.appendingPathComponent("folder.zip")
        try ArchiveService.createZip(from: [FileItem(url: folder)], to: zip)

        let entries = try ArchiveService.listContents(of: zip)
        XCTAssertTrue(entries.contains { $0.hasSuffix("a.txt") }, "엔트리: \(entries)")
        XCTAssertTrue(entries.contains { $0.hasSuffix("b.txt") }, "엔트리: \(entries)")

        // 해제 후 내용 검증
        let dest = tmp.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try ArchiveService.extract(archive: zip, to: dest)

        let a = dest.appendingPathComponent("folder/a.txt")
        let b = dest.appendingPathComponent("folder/nested/b.txt")
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "AAA")
        XCTAssertEqual(try String(contentsOf: b, encoding: .utf8), "BBB")
    }

    func testZipMultipleFiles() throws {
        let f1 = tmp.appendingPathComponent("one.txt")
        let f2 = tmp.appendingPathComponent("two.txt")
        try "1".write(to: f1, atomically: true, encoding: .utf8)
        try "2".write(to: f2, atomically: true, encoding: .utf8)
        let zip = tmp.appendingPathComponent("multi.zip")

        try ArchiveService.createZip(from: [FileItem(url: f1), FileItem(url: f2)], to: zip)
        let entries = Set(try ArchiveService.listContents(of: zip))
        XCTAssertEqual(entries, ["one.txt", "two.txt"])
    }
}

final class HexDumpTests: XCTestCase {
    func testKnownBytesProduceExpectedLine() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x01, 0x7F]) // "Hello" + non-printables
        let lines = HexDump.lines(from: data)
        XCTAssertEqual(lines.count, 1)
        let line = lines[0]
        XCTAssertTrue(line.hasPrefix("00000000  "), "주소 프리픽스: \(line)")
        XCTAssertTrue(line.contains("48 65 6C 6C 6F 00 01 7F"), "16진수: \(line)")
        XCTAssertTrue(line.hasSuffix("Hello..."), "ASCII 컬럼(비출력 문자는 '.'): \(line)")
    }

    func testWrapsEvery16Bytes() {
        let data = Data(repeating: 0x41, count: 20) // 20 x 'A'
        let lines = HexDump.lines(from: data)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasPrefix("00000010  "), "두 번째 줄은 오프셋 0x10부터")
        XCTAssertTrue(lines[1].hasSuffix("AAAA"))
    }

    func testRespectsByteLimit() {
        let data = Data(repeating: 0, count: 100)
        let lines = HexDump.lines(from: data, limit: 16)
        XCTAssertEqual(lines.count, 1, "limit=16이면 한 줄만 나와야 한다")
    }
}
