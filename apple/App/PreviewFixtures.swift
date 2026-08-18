// 프리뷰 데이터. **DEBUG에만 있다 — 출시 바이너리에 들어가지 않는다.**
//
// 사진도 분류도 합성한다. 다만 **분류는 진짜 커널이 한다** — 여기서 만드는 것은
// (파일명, 바이트)뿐이다. 목업 구조를 손으로 만들면 커널과 어긋난 채로 예뻐 보인다.

#if DEBUG
import CoreGraphics
import ImageIO
import MomentKernel
import PhotoSource
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum Fixture {
    // ⚠️ **전부 `static let`이다** — 매번 새로 만들면 `store`의 객체 신원이 갱신마다 바뀌어
    // `.task` → 상태 변경 → 갱신의 무한 루프가 된다(2026-08-04 실측).
    static let inputs = makeInputs()
    static let classification = Classifier.classify(inputs)
    /// 화소 크기는 **커널이 `IHDR`에서 읽은 값을 되쓴다** — 실물에서는 라이브러리가 주는
    /// 값이라 출처가 다르지만, 합성 데이터에서 둘을 따로 적으면 배치와 그림이 어긋난다.
    static let assets = inputs.enumerated().map { index, input in
        let signals = classification.readings[index].signals
        return SourceAsset(id: "preview-\(index)", filename: input.filename,
                           pixelWidth: signals?.pixelWidth ?? 0,
                           pixelHeight: signals?.pixelHeight ?? 0)
    }
    static let store = makeStore()

    /// 저장이 요구하는 원본 바이트. **화소 크기는 자산이 말한 그대로다** — 저장된 파일이 곧
    /// 「원본」이라 줄이면 거짓이 된다.
    static let originalBytes: OriginalBytesLoader = { asset in
        // ⚠️ 진짜 어댑터를 태우면 안 된다 — 합성 자산의 `id`가 PhotoKit에 없어 던지고,
        // `-fixture`로는 저장 경로를 한 번도 못 밟게 된다(2026-08-14에 겪었다).
        guard let data = await syntheticPNG(pixels: max(asset.pixelWidth, asset.pixelHeight),
                                            aspect: aspect(of: asset),
                                            hue: hue(of: asset.id))
        else { throw NoFixtureBytes() }
        return data
    }
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

    /// 합성 기록 넷. **실제 저장소에 실제 파일로 쓴다** — 화면들이 전부 디스크에서 읽으므로
    /// 메모리 목업으로는 경로가 하나도 안 태워진다.
    static let records = makeRecords()

    /// 격자가 그리는 세 갈래를 한 화면에 올린다 — 앨범 자산 · 가져온 바이트 · 저장된 파일.
    /// 발생일시가 합성 앨범에 없는 날이라 **`10`도 빈 상태로 열린다.**
    static let mixedDraft: RecordDraft? = {
        guard let record = records.records.first, let moment = allMoments.first else { return nil }
        let draft = RecordDraft.editing(record)
        let candidates = RecordDraft.photos(at: moment.scenes.map(\.representative),
                                            library: library)
        draft.apply(includedAssets: Set(candidates.compactMap { $0.asset?.id }),
                    candidates: candidates)
        if let data = syntheticPNG(pixels: 900, aspect: 1.4, hue: 0.55) {
            draft.addImported(data, fileExtension: "png")
        }
        return draft
    }()

    /// `11`을 글이 놓인 채로 연다 — 글꼴 2종과 인스펙터를 눌러보지 않고 관측하는 문.
    @MainActor
    static func canvasWithText(day: CalendarDay) -> CanvasSession? {
        let draft = RecordDraft.from(moment: momentWithBurst, day: day, library: library)
        guard let first = draft.included.first else { return nil }
        var handwriting = CanvasText(face: .handwriting, ink: .sumi)
        handwriting.string = "그날의 노을"
        var serif = CanvasText(face: .serif, ink: .navy)
        serif.string = "해가 지는 걸 보려고 계속 달렸다. 도착한 곳은 아무것도 없는 모래 언덕이었다."
        // 첫 요소가 진입 직후 선택된다 — 손글씨를 앞에 두어 `11-I`가 그 상태로 열린다.
        let page = CanvasPage(paper: .dots, elements: [
            CanvasElement(content: .text(handwriting),
                          frame: handwriting.box(at: CGPoint(x: 600, y: 400), width: 300)),
            CanvasElement(content: .photo(imageID: first.id),
                          frame: CGRect(x: 74, y: 32, width: 483, height: 349), rotation: -2.4),
            CanvasElement(content: .text(serif),
                          frame: serif.box(at: CGPoint(x: 74, y: 430), width: 520)),
        ])
        return CanvasSession(draft: draft, entry: .promotion,
                             document: CanvasDocument(pages: [page]),
                             store: records.store)
    }

    private static func makeRecords() -> RecordLibrary {
        let root = URL.cachesDirectory.appending(path: "FixtureRecords")
        try? FileManager.default.removeItem(at: root)
        let library = RecordLibrary(store: RecordStore(root: root))

        let plans: [(month: Int, day: Int, images: Int, caption: String, status: Record.Status)] = [
            (8, 3, 5, "사막 끝까지 가봤다. 해가 지는 걸 보려고 계속 달렸는데, 도착한 곳은 "
                + "아무것도 없는 모래 언덕이었다. 그게 좋았다.", .published),
            (8, 1, 3, "", .draft),
            (7, 29, 2, "비 오는 날의 던바튼. 광장에 아무도 없었다.", .published),
            (7, 12, 1, "혼자 낚시.", .published),
        ]
        for (index, plan) in plans.enumerated() {
            guard let occurredAt = WallClock(year: 2026, month: plan.month, day: plan.day,
                                             hour: 18, minute: 5, second: 0, hundredth: 0)
            else { continue }
            var images: [RecordImage] = []
            var bytes: [UUID: Data] = [:]
            for slot in 0..<plan.images {
                let id = UUID()
                let portrait = (index + slot) % 3 == 2
                images.append(RecordImage(id: id, fileExtension: "png", origin: .imported))
                // ⚠️ **`PNG.capture`를 쓰면 안 된다** — 그것은 커널이 읽을 신호만 담은 껍데기라
                // 화소가 없고, 디스크에서 다시 디코딩하는 이 경로에서는 회색 칸으로만 나온다.
                bytes[id] = syntheticPNG(pixels: 900,
                                         aspect: portrait ? 738.0 / 1600 : 1600.0 / 738,
                                         hue: Double((index * 3 + slot) % 12) / 12) ?? Data()
            }
            let record = Record(id: UUID(), occurredAt: occurredAt,
                                images: images, caption: plan.caption, status: plan.status,
                                updatedAt: Date(timeIntervalSince1970: 0))
            try? library.store.save(record, imageData: bytes)
        }
        library.reload()
        return library
    }

    /// 표본을 닮은 한 세션. 날짜 2개 · 연사 있음/없음 · 1장짜리 · 7장면 초과가 섞이도록 짰다 —
    /// `04`가 실제로 마주치는 모양을 한 화면에 다 올리는 것이 목적이다.
    private static func makeInputs() -> [PhotoInput] {
        var photos: [(stamp: String, zone: String, position: (Double, Double, Double), portrait: Bool)] = []

        func add(_ stamp: String, _ zone: String, _ x: Double, portrait: Bool = false) {
            photos.append((stamp, zone, (x, 40, -20), portrait))
        }

        // 7월 26일 18:05 — 12장 · 8장면
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

    private static func makeStore() -> ImageStore {
        ImageStore(loader: { asset, pixels, _ in
            synthetic(pixels: pixels, aspect: aspect(of: asset), hue: hue(of: asset.id))
        })
    }

    /// ⚠️ **종횡비는 자산이 말하는 화소 크기 그대로다** — 어림수를 쓰면 셀 높이를 정한 값과
    /// 그 안을 채우는 그림이 어긋나 배치가 틀린 채로 맞아 보인다.
    private static func aspect(of asset: SourceAsset) -> Double {
        asset.pixelHeight > 0 ? Double(asset.pixelWidth) / Double(asset.pixelHeight) : 1
    }

    /// 색상환 위 자리. **`id`의 순번이 정한다** — 그래야 같은 사진이 화면마다 같은 색이다.
    private static func hue(of assetID: String) -> Double {
        Double((Int(assetID.split(separator: "-").last ?? "") ?? 0) % 12) / 12
    }

    /// 사진 자리에 들어갈 합성 그림. 사진이 아니라 **사진 크기의 무늬**다 —
    /// 크롭·여백·정렬을 보는 데는 충분하고, "봐서 생각이 나는가"는 실기기가 답한다.
    static func synthetic(pixels: Int, aspect: Double, hue: Double) -> CGImage? {
        let long = max(pixels, 8)
        let short = max(8, Int(Double(long) / max(aspect, 1 / aspect)))
        let width = aspect >= 1 ? long : short
        let height = aspect >= 1 ? short : long

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

    /// 위 무늬를 파일로 쓸 수 있게 인코딩한다. 기록은 바이트를 **복사해 두므로** 저장소에
    /// 넣으려면 진짜 파일이어야 한다.
    static func syntheticPNG(pixels: Int, aspect: Double, hue: Double) -> Data? {
        guard let image = synthetic(pixels: pixels, aspect: aspect, hue: hue) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

/// 합성 바이트를 못 구웠다. 프리뷰와 `-fixture`에서만 나온다.
private struct NoFixtureBytes: Error {}

/// 합성 PNG. 커널 테스트 `PNGFixture`의 축약이다 — 실패 경로용 손잡이가 없다.
/// 실물이 규격에 없는 종료 NUL을 쓴다는 것까지는 따라간다.
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
