// `11-I` 선택 인스펙터 — 요소를 고르면 팔레트 자리에 뜬다.

import SwiftUI

/// 고른 요소에 거는 것들. **자리와 높이가 팔레트와 같다** — 손이 기억한 위치가 안 흔들린다.
///
/// ⚠️ **여기서만 삭제가 바 위에 선다** (사용자 판정 2026-08-18). 「인라인 파괴 버튼을 만들지
/// 않는다」가 지키는 것은 **되돌릴 수 없는 파괴**인데, 캔버스 요소는 `11-N2`가 받는다 —
/// 기록 삭제(`08`)처럼 디스크에서 사라지는 일이 아니다.
struct CanvasInspector: View {
    let session: CanvasSession
    let elementID: UUID
    let onInkTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CanvasBottomBar { controls }
    }

    @ViewBuilder
    private var controls: some View {
        if let text = session.element(elementID)?.text {
            faces(text)
            CanvasBarDivider()
            weights(text)
            CanvasBarDivider()
            CanvasValueSlider(value: text.size, range: CanvasText.sizeRange,
                              name: Wording.textSize) { size in
                session.restyle(elementID) { $0.size = size }
            }
            CanvasBarDivider()
        }
        order(Glyph.bringToFront, name: Wording.bringToFront, toFront: true)
        order(Glyph.sendToBack, name: Wording.sendToBack, toFront: false)
        CanvasBarDivider()
        // ⚠️ **색 칩은 글에서만 뜬다** — 사진에는 색이라는 속성이 없어서, 자리를 지키려고
        // 남기면 「이 사진 색을 바꾸는 것」으로 읽힌다.
        if let text = session.element(elementID)?.text {
            InkChip(ink: text.ink, action: onInkTap)
            CanvasBarDivider()
        }
        more
        CanvasBarDivider()
        CanvasBarButton(glyph: Glyph.delete, name: Wording.delete, action: onDelete)
    }

    /// `11-I1` — 각 칸이 자기 서체로 선다.
    @ViewBuilder
    private func faces(_ text: CanvasText) -> some View {
        CanvasBarSegment(label: Wording.handwritingFace,
                         font: Typography.canvasSegment(.handwriting),
                         isActive: text.face == .handwriting) {
            session.setFace(.handwriting, of: elementID)
        }
        CanvasBarSegment(label: Wording.serifFace,
                         font: Typography.canvasSegment(.serif),
                         isActive: text.face == .serif) { session.setFace(.serif, of: elementID) }
    }

    /// `11-I2` — **손글씨를 고르면 자리를 두고 비활성이다.** 사라지면 오른쪽이 통째로 밀리고,
    /// 굵기가 원래 있는 기능인지조차 배울 기회가 없다.
    @ViewBuilder
    private func weights(_ text: CanvasText) -> some View {
        CanvasBarSegment(label: Wording.regularWeight, font: Typography.label,
                         isActive: text.face.hasWeights && !text.isBold,
                         isEnabled: text.face.hasWeights) { setBold(false) }
        CanvasBarSegment(label: Wording.boldWeight, font: Typography.label,
                         isActive: text.face.hasWeights && text.isBold,
                         isEnabled: text.face.hasWeights) { setBold(true) }
    }

    private func setBold(_ isBold: Bool) {
        session.restyle(elementID) { $0.isBold = isBold }
    }

    /// `11-I4` — 관례가 약해 한 번 배워야 하는 개념이라, 배울 자리(`···`의 글자)를 같은
    /// 바 안에 둔다.
    private func order(_ glyph: String, name: String, toFront: Bool) -> some View {
        CanvasBarButton(glyph: glyph, name: name) { session.move(elementID, toFront: toFront) }
    }

    /// `11-I6` — **겹침 아이콘을 배우는 자리다.** 삭제는 옆에 자기 아이콘으로 서 있다.
    private var more: some View {
        Menu {
            Button(Wording.bringToFront) { session.move(elementID, toFront: true) }
            Button(Wording.sendToBack) { session.move(elementID, toFront: false) }
        } label: {
            CanvasBarGlyph(glyph: Glyph.more)
        }
        .accessibilityLabel(Wording.moreActions)
    }
}
