// 프리뷰 데이터. **DEBUG에만 있다 — 출시 바이너리에 들어가지 않는다.**
//
// 개인 스크린샷을 저장소에 넣지 않으므로(`CLAUDE.md` 경계 규칙) 사진도 분류도 합성한다.
// 다만 **분류는 진짜 커널이 한다** — 여기서 만드는 것은 (파일명, 바이트)뿐이다. 목업 구조를
// 손으로 만들면 프리뷰가 커널과 어긋난 채로 예뻐 보인다.

#if DEBUG
import CoreGraphics
import MomentKernel
import PhotoSource
import SwiftUI

@MainActor
enum Fixture {
    // **전부 `static let`이다 — 프리뷰에서 이건 정확성 문제다.** 매번 새로 만들면 `store`의
    // 객체 신원이 갱신마다 바뀌어 캐시가 늘 비고, `.task` → 상태 변경 → 갱신의 무한 루프가
    // 된다 (2026-08-04에 겪었다. 렌더가 10분을 넘겨도 스냅샷이 안 나왔다).
    static let inputs = makeInputs()
    static let classification = Classifier.classify(inputs)
    static let assets = inputs.enumerated().map { index, input in
        SourceAsset(id: "preview-\(index)", filename: input.filename)
    }
    static let store = makeStore()
    static let library = MomentLibrary.preview(classification, assets: assets)
    /// 첫 분류 진행 중 — `04-A1` 진행바가 뜨고 부제 숫자가 올라가는 상태.
    static let working = MomentLibrary.preview(classification, assets: assets,
                                               phase: .readingRemote, progress: 0.42)
    static let emptyLibrary = MomentLibrary.preview(Classifier.classify([]), assets: [])

    /// 배지·펼침이 붙는 자리를 본다.
    static let momentWithBurst = allMoments.first { moment in
        moment.scenes.contains { $0.isFolded }
    } ?? allMoments[0]
    /// 열 수를 장면 수에 맞추는 규칙이 실제로 화면 폭 한 장이 되는지.
    static let singlePhotoMoment = allMoments.first { $0.photoCount == 1 } ?? allMoments[0]

    private static let allMoments = classification.days.flatMap(\.moments)

    /// 표본을 닮은 한 세션. 날짜 2개 · 연사 있음/없음 · 1장짜리 · 7장면 초과가 섞이도록 짰다 —
    /// `04`가 실제로 마주치는 모양을 한 화면에 다 올리는 것이 목적이다.
    private static func makeInputs() -> [PhotoInput] {
        var photos: [(stamp: String, zone: String, position: (Double, Double, Double), portrait: Bool)] = []

        func add(_ stamp: String, _ zone: String, _ x: Double, portrait: Bool = false) {
            photos.append((stamp, zone, (x, 40, -20), portrait))
        }

        // 7월 26일 18:05 — 12장 · 8장면 (설계서의 그 문구가 나오도록)
        add("20260726180500", "던바튼", 0)
        add("20260726180503", "던바튼", 0.2)          // 연사 (같은 장면)
        add("20260726180506", "던바튼", 0.3)          // 연사
        add("20260726180530", "던바튼", 4, portrait: true)
        add("20260726180612", "던바튼", 6)
        add("20260726180640", "던바튼", 8)
        add("20260726180643", "던바튼", 8.2)          // 연사
        add("20260726180710", "던바튼", 10)
        add("20260726180805", "던바튼", 12, portrait: true)
        add("20260726180902", "던바튼", 14)
        add("20260726181030", "던바튼", 16)
        add("20260726181120", "던바튼", 18)

        // 같은 날 저녁 — 다른 장소로 옮겨서 순간이 갈린다
        add("20260726203000", "이멘마하", 300)
        add("20260726203040", "이멘마하", 302)

        // 1장짜리 순간 — `04`의 우측 여백이 빈칸으로 보이는지
        add("20260726224500", "티르코네일", 700, portrait: true)

        // 전날 — 장면이 많아 `+N`이 나오는 순간 (7장면 이상)
        for (offset, x) in [0.0, 3, 6, 9, 12, 15, 18, 21, 24].enumerated() {
            add(String(format: "202607251%02d000", offset + 40), "던바튼", x)
        }

        return photos.map { photo in
            PhotoInput(filename: "MabinogiMobile_\(photo.stamp)00.png",
                       bytes: PNG.capture(width: photo.portrait ? 738 : 1600,
                                          height: photo.portrait ? 1600 : 738,
                                          zone: photo.zone,
                                          position: photo.position))
        }
    }

    /// 합성 이미지를 먹이는 저장소. 세로 사진이 섞여 있어야
    /// 정사각 크롭과 세로 셀 여백이 프리뷰에서도 눈에 보인다.
    private static func makeStore() -> ImageStore {
        // 세로 여부는 의도가 아니라 커널이 읽은 `IHDR`로 판정한다 — 어긋나면 티가 난다.
        let portraitIDs = Set(zip(assets, classification.readings).compactMap { asset, reading in
            guard let signals = reading.signals else { return nil as String? }
            return signals.pixelHeight > signals.pixelWidth ? asset.id : nil
        })
        var index = 0
        var hueOf: [String: Double] = [:]
        for asset in assets {
            hueOf[asset.id] = Double(index % 12) / 12
            index += 1
        }
        return ImageStore(loader: { asset, pixels, _ in
            synthetic(pixels: pixels,
                      portrait: portraitIDs.contains(asset.id),
                      hue: hueOf[asset.id] ?? 0)
        })
    }

    /// 사진 자리에 들어갈 합성 그림. 사진이 아니라 **사진 크기의 무늬**다 —
    /// 크롭·여백·정렬을 보는 데는 충분하고, "봐서 생각이 나는가"는 실기기가 답한다.
    static func synthetic(pixels: Int, portrait: Bool, hue: Double) -> CGImage? {
        let long = max(pixels, 8)
        let short = Int(Double(long) / 1.294)
        let width = portrait ? short : long
        let height = portrait ? long : short

        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let base = UIColor(hue: hue, saturation: 0.35, brightness: 0.55, alpha: 1)
        context.setFillColor(base.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // 가장자리와 중앙을 구별할 무늬 — 중앙 크롭이 무엇을 잘라내는지 보이게 한다.
        context.setFillColor(UIColor(hue: hue, saturation: 0.5, brightness: 0.85, alpha: 1).cgColor)
        let inset = Double(min(width, height)) * 0.18
        context.fillEllipse(in: CGRect(x: Double(width) / 2 - inset, y: Double(height) / 2 - inset,
                                       width: inset * 2, height: inset * 2))
        context.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
        let corner = Double(min(width, height)) * 0.12
        context.fill(CGRect(x: 0, y: 0, width: corner, height: corner))
        context.fill(CGRect(x: Double(width) - corner, y: Double(height) - corner,
                            width: corner, height: corner))

        return context.makeImage()
    }
}

/// 합성 PNG. 커널 테스트의 `PNGFixture`와 같은 일을 하지만 **복사가 아니라 축약이다** —
/// 여기서 필요한 것은 커널이 신호를 읽어내는 것뿐이라 실패 경로용 손잡이가 없다.
/// (실물이 규격에 없는 종료 NUL을 쓴다는 것까지는 따라간다 — 커널이 그것을 떼도록 만들어졌다.)
private enum PNG {
    static func capture(width: Int, height: Int, zone: String,
                        position: (Double, Double, Double)) -> [UInt8] {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += chunk("IHDR", be32(width) + be32(height) + [8, 2, 0, 0, 0])
        bytes += chunk("IDAT", [0x78, 0x01, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01])
        for (keyword, value) in [
            ("Location Display Name", zone),
            ("Camera Position", "<\(position.0), \(position.1), \(position.2)>"),
            ("Camera Rotation", "<0.0, 90.0, 0.0>"),
            ("Camera Fov Degree", "62.9598"),
        ] {
            bytes += chunk("iTXt", itxt(keyword: keyword, value: value))
        }
        bytes += chunk("IEND", [])
        return bytes
    }

    private static func itxt(keyword: String, value: String) -> [UInt8] {
        var data = Array(keyword.utf8)
        data += [0, 0, 0, 0]                 // 키워드 끝 · 비압축 · 압축방식 · 빈 언어태그
        data += Array(keyword.utf8)          // 번역된 키워드 = 키워드 (실물이 그렇다)
        data.append(0)
        data += Array(value.utf8)
        data.append(0)                       // 규격에 없는 종료 NUL — 실물 211/211 (2026-08-03)
        return data
    }

    private static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let body = Array(type.utf8) + data
        return be32(data.count) + body + be32(Int(crc32(body)))
    }

    private static func be32(_ value: Int) -> [UInt8] {
        let v = UInt32(truncatingIfNeeded: value)
        return [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF),
                UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var c = UInt32(index)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in bytes { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
#endif
