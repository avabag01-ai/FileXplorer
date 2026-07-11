import Foundation
import Network

/// RFC 959 기반의 최소 FTP 클라이언트 (평문 FTP, 패시브 모드만 지원).
/// FTPS/SFTP/SMB는 TLS·SSH·SMB 프로토콜 스택이 추가로 필요해 포함하지 않았다.
/// (SMB는 iOS 공개 API로 서드파티 앱이 구현하기 사실상 불가능 — Files 앱의 "서버에 연결"만 가능)
final class FTPService: ObservableObject {
    struct Credentials {
        var host: String
        var port: UInt16 = 21
        var username: String
        var password: String
    }

    enum FTPError: LocalizedError {
        case connectionFailed
        case loginFailed(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed: return "서버에 연결할 수 없습니다"
            case .loginFailed(let msg): return "로그인 실패: \(msg)"
            case .commandFailed(let msg): return "명령 실패: \(msg)"
            }
        }
    }

    private var controlConnection: NWConnection?
    private let queue = DispatchQueue(label: "ftp.control")

    func connect(_ credentials: Credentials) async throws {
        let connection = NWConnection(
            host: NWEndpoint.Host(credentials.host),
            port: NWEndpoint.Port(rawValue: credentials.port) ?? 21,
            using: .tcp
        )
        controlConnection = connection
        try await start(connection)

        _ = try await readResponse() // welcome banner
        _ = try await sendCommand("USER \(credentials.username)")
        let passResp = try await sendCommand("PASS \(credentials.password)")
        guard passResp.hasPrefix("230") else {
            throw FTPError.loginFailed(passResp)
        }
        _ = try? await sendCommand("TYPE I")
    }

    func disconnect() {
        controlConnection?.cancel()
        controlConnection = nil
    }

    func listDirectory(path: String) async throws -> [FTPEntry] {
        let dataConn = try await enterPassiveMode()
        let resp = try await sendCommand("LIST \(path)")
        guard resp.hasPrefix("150") || resp.hasPrefix("125") else {
            throw FTPError.commandFailed(resp)
        }
        let raw = try await receiveAll(on: dataConn)
        _ = try await readResponse() // 226 transfer complete
        let text = String(data: raw, encoding: .utf8) ?? ""
        // 주의: Swift는 CRLF("\r\n")를 하나의 Character(grapheme)로 합치므로
        // split(separator: "\n")로는 CRLF 줄바꿈이 쪼개지지 않는다.
        // Character.isNewline은 LF·CR·CRLF를 모두 줄바꿈으로 인식한다.
        return text
            .split(whereSeparator: \.isNewline)
            .compactMap { FTPEntry(lsLine: String($0)) }
    }

    func download(remotePath: String, to localURL: URL) async throws {
        let dataConn = try await enterPassiveMode()
        let resp = try await sendCommand("RETR \(remotePath)")
        guard resp.hasPrefix("150") || resp.hasPrefix("125") else {
            throw FTPError.commandFailed(resp)
        }
        let data = try await receiveAll(on: dataConn)
        try data.write(to: localURL)
        _ = try await readResponse()
    }

    func upload(localURL: URL, remotePath: String) async throws {
        let dataConn = try await enterPassiveMode()
        let resp = try await sendCommand("STOR \(remotePath)")
        guard resp.hasPrefix("150") || resp.hasPrefix("125") else {
            throw FTPError.commandFailed(resp)
        }
        let data = try Data(contentsOf: localURL)
        try await send(data, on: dataConn)
        dataConn.cancel()
        _ = try await readResponse()
    }

    func delete(remotePath: String) async throws {
        let resp = try await sendCommand("DELE \(remotePath)")
        guard resp.hasPrefix("250") else { throw FTPError.commandFailed(resp) }
    }

    func makeDirectory(remotePath: String) async throws {
        let resp = try await sendCommand("MKD \(remotePath)")
        guard resp.hasPrefix("257") else { throw FTPError.commandFailed(resp) }
    }

    // MARK: - Low level helpers

    private func enterPassiveMode() async throws -> NWConnection {
        let resp = try await sendCommand("PASV")
        guard let (host, port) = parsePASV(resp) else {
            throw FTPError.commandFailed(resp)
        }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 21, using: .tcp)
        try await start(conn)
        return conn
    }

    /// NWConnection을 시작하고 `.ready`가 될 때까지 기다린다.
    /// ready 이전에 receive를 호출하면 서버가 데이터를 보내고 바로 닫는 경우
    /// ENODATA(POSIX 96)가 발생하므로, 데이터 전송 전에 반드시 준비 완료를 보장한다.
    private func start(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume()
                case .failed(let error), .waiting(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: FTPError.connectionFailed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func parsePASV(_ response: String) -> (String, UInt16)? {
        guard let start = response.firstIndex(of: "("), let end = response.firstIndex(of: ")") else { return nil }
        let numbers = response[response.index(after: start)..<end].split(separator: ",").compactMap { Int($0) }
        guard numbers.count == 6 else { return nil }
        let host = "\(numbers[0]).\(numbers[1]).\(numbers[2]).\(numbers[3])"
        let port = UInt16(numbers[4] * 256 + numbers[5])
        return (host, port)
    }

    @discardableResult
    private func sendCommand(_ command: String) async throws -> String {
        guard let connection = controlConnection else { throw FTPError.connectionFailed }
        try await send("\(command)\r\n".data(using: .utf8)!, on: connection)
        return try await readResponse()
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readResponse() async throws -> String {
        guard let connection = controlConnection else { throw FTPError.connectionFailed }
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                continuation.resume(returning: text)
            }
        }
    }

    private func receiveAll(on connection: NWConnection) async throws -> Data {
        var collected = Data()
        while true {
            let chunk: Data? = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let data = data, !data.isEmpty {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            guard let chunk = chunk else { break }
            collected.append(chunk)
        }
        connection.cancel()
        return collected
    }
}

struct FTPEntry: Identifiable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: Int64

    /// 표준 Unix 스타일 LIST 출력 한 줄을 파싱한다.
    /// 예: "drwxr-xr-x  2 user group  4096 Jan 01 00:00 foldername"
    init?(lsLine: String) {
        let parts = lsLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 9 else { return nil }
        isDirectory = lsLine.first == "d"
        size = Int64(parts[4]) ?? 0
        let name = parts[8...].joined(separator: " ")
        guard !name.isEmpty else { return nil }
        self.name = name
    }
}
