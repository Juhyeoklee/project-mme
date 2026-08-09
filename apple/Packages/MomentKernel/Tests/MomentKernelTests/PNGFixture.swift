import Foundation

/// 합성 PNG 픽스처. **개인 스크린샷을 저장소에 넣지 않기 위해** 바이트를 직접 만든다.
/// CRC까지 계산하는 것은 커널이 안 봐도 픽스처가 진짜 PNG여야 외부 도구로 확인되기 때문이다.
enum PNGFixture {
    /// 게임이 써넣는 10개 중 커널이 쓰는 4개 + 자주 쓰는 조합.
    static func capture(width: Int = 1600, height: Int = 738,
                        zone: String = "던바튼",
                        cameraPosition: (Double, Double, Double) = (0, 0, 0),
                        cameraRotation: (Double, Double, Double) = (0, 0, 0),
                        fieldOfView: Double = 62.9598,
                        extraText: [(String, String)] = [],
                        omitting: Set<String> = [],
                        compressedKeys: Set<String> = []) -> [UInt8] {
        var entries: [(String, String)] = [
            ("Location Display Name", zone),
            ("Camera Position", vector(cameraPosition)),
            ("Camera Rotation", vector(cameraRotation)),
            ("Camera Fov Degree", "\(fieldOfView)"),
        ]
        // `omitting`은 기본 4개에만 걸린다 — 뺀 자리를 `extraText`로 갈아 끼울 수 있게.
        entries = entries.filter { !omitting.contains($0.0) }
        entries.append(contentsOf: extraText)
        return png(width: width, height: height, text: entries, compressedKeys: compressedKeys)
    }

    static func vector(_ v: (Double, Double, Double)) -> String {
        "<\(v.0), \(v.1), \(v.2)>"
    }

    /// `textAfterIDAT` — 파서가 픽셀 데이터를 건너뛰고도 텍스트를 찾는지 보기 위한 손잡이.
    static func png(width: Int, height: Int,
                    text: [(String, String)],
                    compressedKeys: Set<String> = [],
                    textAfterIDAT: Bool = false,
                    gameStyle: Bool = true) -> [UInt8] {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

        do {
            var header: [UInt8] = []
            header += be32(width)
            header += be32(height)
            header += [8, 2, 0, 0, 0]        // 8bit · truecolor · 표준 압축/필터/비인터레이스
            bytes += chunk("IHDR", header)
        }

        let textChunks = text.map { keyword, value in
            chunk("iTXt", itxt(keyword: keyword, value: value,
                               compressed: compressedKeys.contains(keyword),
                               gameStyle: gameStyle))
        }
        if !textAfterIDAT { textChunks.forEach { bytes += $0 } }
        // 픽셀은 아무 바이트나 — 커널은 디코딩하지 않는다.
        bytes += chunk("IDAT", [0x78, 0x01, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01])
        if textAfterIDAT { textChunks.forEach { bytes += $0 } }
        bytes += chunk("IEND", [])
        return bytes
    }

    /// `gameStyle`이 기본값인 이유 — **실물이 이렇다**(2026-08-03): 번역된 키워드에 키워드를
    /// 되풀이하고 규격에 없는 **종료 NUL을 하나 더** 쓴다. 규격 형태도 읽혀야 해 둘 다 시험한다.
    static func itxt(keyword: String, value: String, compressed: Bool,
                     gameStyle: Bool = true) -> [UInt8] {
        var data: [UInt8] = Array(keyword.utf8)
        data.append(0)                                   // 키워드 끝
        data.append(compressed ? 1 : 0)                  // 압축 플래그
        data.append(0)                                   // 압축 방식
        data.append(0)                                   // 언어 태그 (빈 문자열)
        if gameStyle { data += Array(keyword.utf8) }     // 번역된 키워드 = 키워드
        data.append(0)                                   // 번역된 키워드 끝
        data += Array(value.utf8)
        if gameStyle { data.append(0) }                  // 규격에 없는 종료 NUL
        return data
    }

    static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let typeBytes = Array(type.utf8)
        var body = typeBytes
        body += data
        return be32(data.count) + body + be32(Int(crc32(body)))
    }

    static func be32(_ value: Int) -> [UInt8] {
        let v = UInt32(truncatingIfNeeded: value)
        return [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF),
                UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var c = UInt32(index)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in bytes { c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// `MabinogiMobile_YYYYMMDDHHMMSSff.png` 형태의 이름을 만든다.
func captureName(_ stamp: String) -> String {
    "MabinogiMobile_\(stamp).png"
}
