// 기록에 드는 사진 한 칸. `09`와 `10`이 같은 것을 쓴다.

import SwiftUI

/// **또렷함 = 이 기록에 들어 있다.**
///
/// ⚠️ **두 화면이 같은 축을 써야 한다** — `10`은 `09` 위에 뜨는 시트라 둘이 겹쳐 보인다.
/// 같은 픽셀이 반대 뜻이면 배울 것이 둘이 된다.
struct RecordPhotoTile<Photo: View>: View {
    let isIncluded: Bool
    @ViewBuilder var photo: Photo

    var body: some View {
        photo
            .clipShape(.rect(cornerRadius: Radius.thumbnail))
            .overlay { if !isIncluded { veil } }
    }

    private var veil: some View {
        RoundedRectangle(cornerRadius: Radius.thumbnail)
            .fill(Palette.veil)
            .overlay(alignment: .bottomTrailing) { badge }
    }

    /// **우하단 = 수량·액션.** 좌상단은 상태 정보(연사 장수)가 쓰는 자리라 겹치지 않는다.
    private var badge: some View {
        Circle()
            .fill(Palette.badgeSurface)
            .frame(width: Layout.badgeDiameter, height: Layout.badgeDiameter)
            .overlay {
                GlyphIcon(Glyph.add, size: 13)
                    .foregroundStyle(Palette.background)
            }
            .padding(6)
    }
}
