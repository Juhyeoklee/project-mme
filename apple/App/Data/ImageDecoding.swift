// 이미지 바이트를 화면에 쓸 크기로 읽는 한 자리.

import CoreGraphics
import Foundation
import ImageIO

/// 축소 디코딩. **바이트에서든 파일에서든 같은 방식으로 읽는다.**
///
/// ⚠️ **방향 변환을 빼면 안 된다** — 같은 사진이 저장 전에는 바이트에서, 저장 뒤에는 파일에서
/// 그려지므로 한쪽만 빼면 **저장을 건너는 순간 사진이 돌아간다**(2026-08-14 실물). 읽는 길이
/// 하나여야 그 어긋남이 원리적으로 안 생긴다.
///
/// ⚠️ **원본을 통째로 디코딩하지 않는다** — 기록에 든 것은 게임 스크린샷 원본이라 목록 칸에
/// 4천 화소가 들어온다. 축소는 디코딩과 **같이** 일어나야 값이 있다(폰 사진 12MP 한 장이
/// 주 액터에서 86ms, 축소해 읽으면 0.4ms — 2026-08-14 실측).
enum ImageDecoding {
    /// 아직 파일이 아닌 바이트에서.
    static func thumbnail(_ data: Data, pixels: Int) -> CGImage? {
        thumbnail(CGImageSourceCreateWithData(data as CFData, nil), pixels: pixels)
    }

    /// 저장된 파일에서.
    static func thumbnail(_ url: URL, pixels: Int) -> CGImage? {
        thumbnail(CGImageSourceCreateWithURL(url as CFURL, nil), pixels: pixels)
    }

    /// 디코딩 없이 헤더만 읽는 화소 크기. **방향까지 반영한다** — 세로로 찍힌 사진은 폭과
    /// 높이가 파일 안에서 뒤바뀐 채 있고, 안 돌리면 놓인 상자가 90도 틀어진 비율이 된다.
    static func pixelSize(_ data: Data) -> CGSize? {
        pixelSize(CGImageSourceCreateWithData(data as CFData, nil))
    }

    static func pixelSize(_ url: URL) -> CGSize? {
        pixelSize(CGImageSourceCreateWithURL(url as CFURL, nil))
    }

    private static func thumbnail(_ source: CGImageSource?, pixels: Int) -> CGImage? {
        guard let source else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ] as CFDictionary)
    }

    private static func pixelSize(_ source: CGImageSource?) -> CGSize? {
        guard let source,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let turned = (5...8).contains(orientation)
        return CGSize(width: turned ? height : width, height: turned ? width : height)
    }
}
