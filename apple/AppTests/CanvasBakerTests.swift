// `CAN-09` 굽기 — 페이지 한 장이 이미지 한 장이 된다는 명세.

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Moanogi

private func store() -> RecordStore {
    RecordStore(root: FileManager.default.temporaryDirectory
        .appending(path: "bake-\(UUID().uuidString)"))
}

/// 크림 종이 위에 사진 한 장을 놓은 문서.
private func document(pages: Int = 1, photo: RecordImage? = nil) -> CanvasDocument {
    let element = photo.map {
        CanvasElement(content: .photo(imageID: $0.id),
                      frame: CGRect(x: 200, y: 150, width: 520, height: 390))
    }
    return CanvasDocument(pages: (0..<pages).map { _ in
        CanvasPage(paper: .dots, elements: element.map { [$0] } ?? [])
    }, sources: photo.map { [$0] } ?? [])
}

/// 구운 바이트에서 그 자리 화소를 읽는다. **파일을 실제로 태운다** — 렌더러가 무엇을 남겼는지
/// 손으로 적은 기대값으로는 알 수 없다.
private func pixel(_ data: Data, atX x: Double, y: Double) throws -> (r: Int, g: Int, b: Int) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let space = CGColorSpaceCreateDeviceRGB()
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8,
                                         bytesPerRow: 4, space: space,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.translateBy(x: -Double(image.width) * x, y: -Double(image.height) * (1 - y))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
}

@Suite("캔버스 굽기")
@MainActor
struct CanvasBakerTests {

    @Test func 페이지마다_이미지가_한_장씩_나온다() async throws {
        let baked = try #require(await CanvasBaker.bake(document(pages: 3), bytes: [:],
                                                        in: store(), recordID: UUID()))

        #expect(baked.images.count == 3)
        #expect(baked.images.allSatisfy { $0.origin == .baked })
        #expect(baked.data.count == 3)
    }

    @Test func 구운_이미지는_캔버스_좌표에_배율을_곱한_화소다() async throws {
        let baked = try #require(await CanvasBaker.bake(document(), bytes: [:],
                                                        in: store(), recordID: UUID()))
        let first = try #require(baked.images.first)
        let data = try #require(baked.data[first.id])
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        #expect(image.width == Int(Layout.canvasSize.width * CanvasBaker.scale))
        #expect(image.height == Int(Layout.canvasSize.height * CanvasBaker.scale))
    }

    /// ⚠️ **종이가 절차적으로 그려지는 것이 굽기에서도 성립하는가** — 무늬는 `Canvas`로 그리고
    /// 굽기는 그것을 다시 렌더한다. 안 나오면 종이 없는 흰 지면이 구워진다.
    @Test func 종이_색이_구운_이미지에_남는다() async throws {
        let baked = try #require(await CanvasBaker.bake(document(), bytes: [:],
                                                        in: store(), recordID: UUID()))
        let first = try #require(baked.images.first)
        let data = try #require(baked.data[first.id])

        let color = try pixel(data, atX: 0.03, y: 0.03)
        #expect(abs(color.r - 0xF7) <= 2)
        #expect(abs(color.g - 0xEE) <= 2)
        #expect(abs(color.b - 0xDA) <= 2)
    }

    @Test func 놓인_사진이_구운_이미지에_남는다() async throws {
        let image = RecordImage(id: UUID(), fileExtension: "png", origin: .imported)
        let bytes = try #require(Fixture.syntheticPNG(pixels: 900, aspect: 4.0 / 3, hue: 0.55))

        let baked = try #require(await CanvasBaker.bake(document(photo: image),
                                                        bytes: [image.id: bytes],
                                                        in: store(), recordID: UUID()))
        let first = try #require(baked.images.first)
        let data = try #require(baked.data[first.id])

        // 요소 한가운데 — 종이가 아니라 사진이 있어야 한다.
        let color = try pixel(data, atX: 460 / Layout.canvasSize.width,
                              y: 345 / Layout.canvasSize.height)
        #expect(color.b > color.r)
    }
}
