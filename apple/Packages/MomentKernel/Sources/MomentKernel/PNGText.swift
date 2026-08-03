// PNG 컨테이너 최소 파싱 — `IHDR`의 크기와 `iTXt`의 텍스트만 꺼낸다.
//
// **픽셀을 디코딩하지 않는다.** `M1`의 분류 신호 셋(시간·장소·연사)이 전부 파일 내장
// 메타값으로 갈렸으므로(`docs/experiments/burst-signal-2026-08.md`) 커널이 이미지 내용을
// 볼 이유가 없다. `IDAT`는 길이만큼 건너뛴다.
//
// CRC는 검사하지 않는다. 깨진 데이터는 필드 파싱에서 걸리고, CRC 표를 들이는 값이
// 이 모듈에서는 나오지 않는다.

/// PNG에서 꺼낸 날것. 값의 뜻은 모른다.
struct PNGScan {
    var pixelWidth: Int
    var pixelHeight: Int
    /// 비압축 `iTXt`의 키워드 → 텍스트. 같은 키가 겹치면 **처음 것**이 남는다.
    var text: [String: String]
    /// 압축된 `iTXt`를 하나라도 봤는가. ADR 0002 대가 2가 예고한 자리다 —
    /// 만나도 풀지 않는다(zlib은 import 0을 깬다). 필요한 키가 없을 때 이유를 가른다.
    var sawCompressedText: Bool
}

enum PNGScanFailure: Error, Sendable, Hashable {
    case notPNG
    case malformed
}

enum PNGText {
    static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func scan(_ bytes: [UInt8]) -> Result<PNGScan, PNGScanFailure> {
        guard bytes.count >= signature.count,
              Array(bytes[0..<signature.count]) == signature
        else { return .failure(.notPNG) }

        var width = 0
        var height = 0
        var text: [String: String] = [:]
        var sawCompressed = false
        var sawIHDR = false

        var cursor = signature.count
        while cursor + 8 <= bytes.count {
            guard let length = readUInt32(bytes, at: cursor) else { return .failure(.malformed) }
            let type = asciiString(bytes, from: cursor + 4, count: 4)
            let dataStart = cursor + 8
            // 길이 4 + 타입 4 + 데이터 + CRC 4
            guard let chunkEnd = add(dataStart, length), let next = add(chunkEnd, 4),
                  next <= bytes.count
            else { return .failure(.malformed) }

            switch type {
            case "IHDR":
                guard length >= 8,
                      let w = readUInt32(bytes, at: dataStart),
                      let h = readUInt32(bytes, at: dataStart + 4),
                      w > 0, h > 0
                else { return .failure(.malformed) }
                width = w
                height = h
                sawIHDR = true
            case "iTXt":
                if let entry = parseITXt(bytes, from: dataStart, to: chunkEnd) {
                    if entry.compressed {
                        sawCompressed = true
                    } else if text[entry.keyword] == nil {
                        text[entry.keyword] = entry.value
                    }
                }
            default:
                break
            }
            if type == "IEND" { break }
            cursor = next
        }

        guard sawIHDR else { return .failure(.malformed) }
        return .success(PNGScan(pixelWidth: width, pixelHeight: height,
                                text: text, sawCompressedText: sawCompressed))
    }

    // MARK: 조각

    /// `iTXt` 데이터부 — 키워드\0 압축플래그 압축방식 언어태그\0 번역키워드\0 텍스트(UTF-8).
    private static func parseITXt(
        _ bytes: [UInt8], from start: Int, to end: Int
    ) -> (keyword: String, value: String, compressed: Bool)? {
        guard let keywordEnd = indexOfZero(bytes, from: start, to: end) else { return nil }
        let keyword = latin1String(bytes, from: start, to: keywordEnd)
        // 압축 플래그와 압축 방식
        guard keywordEnd + 2 < end else { return nil }
        let compressed = bytes[keywordEnd + 1] != 0
        guard let languageEnd = indexOfZero(bytes, from: keywordEnd + 3, to: end),
              let translatedEnd = indexOfZero(bytes, from: languageEnd + 1, to: end)
        else { return nil }
        let textStart = translatedEnd + 1
        guard textStart <= end else { return nil }
        // 규격상 텍스트는 청크 끝까지고 종료자가 없다. **그런데 실물이 NUL을 하나 더 쓴다**
        // (2026-08-03, 표본 211/211). 안 떼면 값 끝이 `>`가 아니라 파싱이 통째로 실패한다.
        var textEnd = end
        while textEnd > textStart, bytes[textEnd - 1] == 0 { textEnd -= 1 }
        let value = String(decoding: bytes[textStart..<textEnd], as: UTF8.self)
        return (keyword, value, compressed)
    }

    private static func indexOfZero(_ bytes: [UInt8], from start: Int, to end: Int) -> Int? {
        guard start >= 0, end <= bytes.count, start <= end else { return nil }
        var i = start
        while i < end {
            if bytes[i] == 0 { return i }
            i += 1
        }
        return nil
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> Int? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        let value = (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16)
                  | (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
        return Int(value)
    }

    /// 오버플로 없이 더한다. PNG 길이는 최대 2^31-1이라 64bit에서는 넘칠 일이 없지만,
    /// 깨진 파일의 길이 필드를 그대로 믿지 않는다.
    private static func add(_ a: Int, _ b: Int) -> Int? {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? nil : sum
    }

    private static func asciiString(_ bytes: [UInt8], from start: Int, count: Int) -> String {
        guard start >= 0, start + count <= bytes.count else { return "" }
        return latin1String(bytes, from: start, to: start + count)
    }

    private static func latin1String(_ bytes: [UInt8], from start: Int, to end: Int) -> String {
        guard start >= 0, end <= bytes.count, start <= end else { return "" }
        return String(String.UnicodeScalarView(bytes[start..<end].map { Unicode.Scalar($0) }))
    }
}
