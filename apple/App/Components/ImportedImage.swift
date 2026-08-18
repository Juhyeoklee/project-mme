// `REC-10`으로 가져온 사진을 그린다. `09`와 `10`이 함께 쓴다.

import CoreGraphics
import SwiftUI

/// 앨범 식별자가 없어 캐시를 못 태우는 사진. **바이트에서 바로 그린다.**
struct ImportedImage: View {
    let data: Data?
    /// 긴 변의 화소 상한.
    let pixels: Int
    /// 사진이 **아직 없을 때**의 바탕과, fit하고 남는 자리의 바탕.
    var emptyColor: Color = Palette.placeholder
    var matteColor: Color = Palette.surface

    @State private var image: CGImage?

    var body: some View {
        PhotoTile(image: image, fills: true, emptyColor: emptyColor, matteColor: matteColor)
            .task(id: data) {
                guard let data else { return }
                let pixels = pixels
                image = await Task.detached { ImageDecoding.thumbnail(data, pixels: pixels) }.value
            }
    }
}
