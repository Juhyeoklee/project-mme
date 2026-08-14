// 번들 아이콘 한 칸. 크롬을 가진 화면이 전부 이걸 쓴다.
//
// **시스템 심볼을 안 쓴다** — 근거와 아이콘 추가 절차는 `App/Design/Icons/README-icons.md`.

import SwiftUI

/// 글리프 하나를 정사각 자리에 그린다.
///
/// ⚠️ **`.resizable()`이 필수다.** 자산 이미지는 심볼과 달리 활자 크기를 따라오지 않아
/// 크기를 프레임으로 줘야 하고, **그래서 Dynamic Type도 자동으로 안 온다** —
/// `@ScaledMetric`이 그 자리를 대신한다.
struct GlyphIcon: View {
    let glyph: String
    @ScaledMetric private var side: CGFloat

    init(_ glyph: String, size: CGFloat = Layout.glyph) {
        self.glyph = glyph
        _side = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(glyph)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
    }
}
