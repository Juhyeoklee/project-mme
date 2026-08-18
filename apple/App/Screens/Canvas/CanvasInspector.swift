// `11-I` 선택 인스펙터 — 요소를 고르면 팔레트 자리에 뜬다.

import SwiftUI

/// 고른 요소에 거는 것들. **자리와 높이가 팔레트와 같다** — 손이 기억한 위치가 안 흔들린다.
///
/// ⚠️ **삭제는 `···` 안에만 있다.** 인라인 파괴 버튼을 만들지 않는다 — `08`·`09`의 더보기와
/// 같은 문법이라 어휘가 안 는다.
struct CanvasInspector: View {
    let session: CanvasSession
    let elementID: UUID
    let ink: InkColor
    let onInkTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CanvasBottomBar {
            order(Glyph.bringToFront, name: Wording.bringToFront, toFront: true)
            order(Glyph.sendToBack, name: Wording.sendToBack, toFront: false)
            CanvasBarDivider()
            InkChip(ink: ink, action: onInkTap)
            CanvasBarDivider()
            more
        }
    }

    /// `11-I4` — 관례가 약해 한 번 배워야 하는 개념이라, 배울 자리(`···`의 글자)를 같은
    /// 바 안에 둔다.
    private func order(_ glyph: String, name: String, toFront: Bool) -> some View {
        CanvasBarButton(glyph: glyph, name: name) { session.move(elementID, toFront: toFront) }
    }

    private var more: some View {
        Menu {
            Button(Wording.bringToFront) { session.move(elementID, toFront: true) }
            Button(Wording.sendToBack) { session.move(elementID, toFront: false) }
            Button(Wording.delete, role: .destructive, action: onDelete)
        } label: {
            CanvasBarGlyph(glyph: Glyph.more)
        }
        .accessibilityLabel(Wording.moreActions)
    }
}
