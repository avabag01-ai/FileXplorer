import Foundation

/// 바이너리 데이터를 `주소  16진수  ASCII` 형태의 문자열 라인들로 변환한다.
/// 뷰에 박혀 있으면 테스트가 불가능하므로 순수 함수로 분리했다.
enum HexDump {
    static let bytesPerLine = 16

    /// - Parameters:
    ///   - data: 원본 데이터
    ///   - limit: 성능을 위한 미리보기 바이트 상한 (기본 64KB)
    static func lines(from data: Data, limit: Int = 64 * 1024) -> [String] {
        let limited = data.prefix(limit)
        // prefix는 원본 인덱스를 유지하므로 0-기반으로 재인덱싱한다.
        let bytes = Array(limited)
        var result: [String] = []
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + bytesPerLine, bytes.count)
            let chunk = bytes[offset..<end]
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let addr = String(format: "%08X", offset)
            let paddedHex = hex.padding(toLength: bytesPerLine * 3 - 1, withPad: " ", startingAt: 0)
            result.append("\(addr)  \(paddedHex)  \(ascii)")
            offset += bytesPerLine
        }
        return result
    }
}
