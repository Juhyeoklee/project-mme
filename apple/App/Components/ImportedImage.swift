// `REC-10`으로 가져온 사진을 그린다. `09`와 `10`이 함께 쓴다.

import CoreGraphics
import ImageIO
import SwiftUI

/// 앨범 식별자가 없어 캐시를 못 태우는 사진. **바이트에서 바로 그린다.**
///
/// ⚠️ **`RecordImageView`와 같은 방식으로 읽어야 한다.** 같은 사진이 저장 전에는 여기서,
/// 저장 뒤에는 저쪽에서 그려지므로 한쪽만 방향 변환을 빼면 **저장을 건너는 순간 사진이
/// 돌아간다** — 시스템 피커가 EXIF를 단 원본 바이트를 그대로 주기 때문이다(2026-08-14 실물).
struct ImportedImage: View {
    let data: Data?
    /// 긴 변의 화소 상한.
    let pixels: Int

    @State private var image: CGImage?

    var body: some View {
        PhotoTile(image: image, fills: true)
            .task(id: data) {
                guard let data else { return }
                let pixels = pixels
                image = await Task.detached { Self.decode(data, pixels: pixels) }.value
            }
    }

    /// ⚠️ **본체에서 떨어져 돈다** — 폰 사진 한 장(12MP)이 주 액터에서 86ms를 먹는다
    /// (2026-08-14 실측. 축소해 읽으면 0.4ms다).
    private nonisolated static func decode(_ data: Data, pixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ] as CFDictionary)
    }
}
