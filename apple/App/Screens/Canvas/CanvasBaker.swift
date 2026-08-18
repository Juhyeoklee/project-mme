// `CAN-09` 굽기 — 페이지 한 장이 기록의 이미지 한 장이 된다.

import SwiftUI

/// 캔버스 문서를 기록이 보여줄 이미지로 굽는다.
///
/// **여기가 「결과를 보여주는 자리」라 자른다** — 종이 밖으로 걸쳐 놓은 것은 구운 이미지에
/// 안 남는다. 고치는 화면만 안 자른다.
///
/// ⚠️ **화면과 같은 조각으로 그린다.** 종이·요소 배치를 여기서 다시 짜면 캔버스에서 본 것과
/// 구운 것이 조용히 갈라진다 — 무늬 간격 하나만 어긋나도 사용자는 알아본다.
@MainActor
enum CanvasBaker {
    /// 굽는 배율. **12pt 손글씨가 @2x면 24px에서 뭉갠다**(`CAN-04`는 크기 하한이 없다).
    /// 한 페이지가 341KB · 100ms고 @4x는 56% 무거워진다(2026-08-18 실측).
    static let scale: CGFloat = 3
    /// JPEG 압축률. **무손실은 같은 지면이 1118KB로 3.3배**인데 눈에 안 보인다(2026-08-18 실측).
    static let quality: CGFloat = 0.92
    static let fileExtension = "jpg"

    /// 페이지 전부를 굽는다. **한 장이라도 못 구우면 `nil`이다.**
    /// `bytes`에는 아직 파일이 아닌 사진만 들어오고, 나머지는 기록 디렉터리에서 읽는다.
    static func bake(_ document: CanvasDocument, bytes: [UUID: Data],
                     in store: RecordStore,
                     recordID: UUID) async -> (images: [RecordImage], data: [UUID: Data])? {
        let photos = await bitmaps(of: document, bytes: bytes, in: store, recordID: recordID)
        var images: [RecordImage] = []
        var data: [UUID: Data] = [:]
        for page in document.pages {
            guard let baked = bake(page, strokes: document.strokes[page.id], photos: photos)
            else { return nil }
            let image = RecordImage(id: UUID(), fileExtension: fileExtension, origin: .baked)
            images.append(image)
            data[image.id] = baked
        }
        return (images, data)
    }

    private static func bake(_ page: CanvasPage, strokes: Data?,
                             photos: [UUID: CGImage]) -> Data? {
        let renderer = ImageRenderer(content: CanvasPageContent(page: page) { imageID in
            if let image = photos[imageID] {
                PhotoTile(image: image, fills: true, emptyColor: .clear, matteColor: .clear)
            } else {
                Color.clear
            }
        } strokes: {
            if let strokes { StrokeImage(strokes: strokes, scale: scale) }
        })
        renderer.scale = scale
        return renderer.uiImage?.jpegData(compressionQuality: quality)
    }

    /// 굽기에 쓸 비트맵. ⚠️ **놓인 크기에 맞춰 줄여 읽는다** — 원본 그대로면 페이지 한 장에
    /// 12MP가 여러 장 올라온다.
    private static func bitmaps(of document: CanvasDocument, bytes: [UUID: Data],
                                in store: RecordStore, recordID: UUID) async -> [UUID: CGImage] {
        var sides: [UUID: CGFloat] = [:]
        for element in document.pages.flatMap(\.elements) {
            guard let imageID = element.imageID else { continue }
            sides[imageID] = max(sides[imageID] ?? 0,
                                 max(element.frame.width, element.frame.height))
        }

        var photos: [UUID: CGImage] = [:]
        for source in document.sources {
            guard let side = sides[source.id] else { continue }
            let pixels = Int((side * scale).rounded(.up))
            let data = bytes[source.id]
            let url = store.imageURL(recordID: recordID, image: source)
            photos[source.id] = await Task.detached {
                if let data { return ImageDecoding.thumbnail(data, pixels: pixels) }
                return ImageDecoding.thumbnail(url, pixels: pixels)
            }.value
        }
        return photos
    }
}
