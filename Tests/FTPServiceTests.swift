import XCTest
@testable import FileXplorer

/// 로컬 pyftpdlib 서버(127.0.0.1:2121)를 대상으로 하는 통합 테스트.
/// 서버가 없으면 XCTSkip으로 건너뛴다. 서버 기동:
///   scratchpad/ftpvenv/bin/python scratchpad/ftp_server.py
final class FTPServiceTests: XCTestCase {
    let creds = FTPService.Credentials(
        host: "127.0.0.1", port: 2121, username: "tester", password: "testpass"
    )

    private func makeConnectedService() async throws -> FTPService {
        let svc = FTPService()
        do {
            try await svc.connect(creds)
        } catch {
            throw XCTSkip("로컬 FTP 서버(127.0.0.1:2121)에 연결 불가 — 서버 미기동으로 스킵: \(error)")
        }
        return svc
    }

    func testConnectAndList() async throws {
        let svc = try await makeConnectedService()
        defer { svc.disconnect() }

        let entries = try await svc.listDirectory(path: "/")
        let names = Set(entries.map(\.name))
        XCTAssertTrue(names.contains("welcome.txt"), "목록: \(names)")
        XCTAssertTrue(names.contains("docs"), "목록: \(names)")
        XCTAssertTrue(entries.first { $0.name == "docs" }?.isDirectory ?? false, "docs는 디렉토리여야 한다")
    }

    func testDownload() async throws {
        let svc = try await makeConnectedService()
        defer { svc.disconnect() }

        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-\(UUID().uuidString).txt")
        try await svc.download(remotePath: "/welcome.txt", to: local)
        defer { try? FileManager.default.removeItem(at: local) }

        let text = try String(contentsOf: local, encoding: .utf8)
        XCTAssertEqual(text, "hello from ftp")
    }

    func testUploadThenListShowsFile() async throws {
        let svc = try await makeConnectedService()
        defer { svc.disconnect() }

        let name = "uploaded-\(Int.random(in: 1000...9999)).txt"
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try "uploaded body".write(to: local, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: local) }

        try await svc.upload(localURL: local, remotePath: "/\(name)")

        let names = Set(try await svc.listDirectory(path: "/").map(\.name))
        XCTAssertTrue(names.contains(name), "업로드 후 목록에 있어야 한다: \(names)")

        // 정리: 원격 파일 삭제
        try await svc.delete(remotePath: "/\(name)")
        let after = Set(try await svc.listDirectory(path: "/").map(\.name))
        XCTAssertFalse(after.contains(name), "삭제 후 목록에서 사라져야 한다")
    }

    func testMakeDirectory() async throws {
        let svc = try await makeConnectedService()
        defer { svc.disconnect() }

        let dir = "d-\(Int.random(in: 1000...9999))"
        try await svc.makeDirectory(remotePath: "/\(dir)")
        let names = Set(try await svc.listDirectory(path: "/").map(\.name))
        XCTAssertTrue(names.contains(dir), "생성한 디렉토리가 보여야 한다: \(names)")
    }
}
