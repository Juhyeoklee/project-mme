// `REC-10`으로 가져온 사진을 그린다. `09`와 `10`이 함께 쓴다.

import CoreGraphics
import ImageIO
import SwiftUI

/// 앨범 식별자가 없어 캐시를 못 태우는 사진. **바이트에서 바로 그린다.**
struct ImportedImage: View {
    let data: Data?

    @State private var image: CGImage?

    var body: some View {
        PhotoTile(image: image, fills: true)
            .task(id: data) {
                guard let data else { return }
                image = Self.decode(data)
            }
    }

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
