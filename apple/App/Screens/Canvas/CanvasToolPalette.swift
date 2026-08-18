// `11-T` 도구 팔레트 — 8칸. 캔버스를 안 가리도록 지면 위에 뜬다.

import SwiftUI

/// 캔버스의 도구 여덟.
///
/// ⚠️ **`선택`이 없으면 사진을 못 옮긴다** — 그리기 도구가 켜져 있으면 드래그가 획이 되므로
/// 모드가 갈려야 한다.
enum CanvasTool: String, CaseIterable, Hashable {
    case select
    case pen
    case marker
    case eraser
    case text
    case photo
    case paper

    /// 그리는 도구인가. 획을 받는 층이 켜지는지를 이것이 정한다.
    var draws: Bool { self == .pen || self == .marker || self == .eraser }

    /// 캔버스 위에서 손을 쓰는 도구인가 — 획을 긋거나 글 상자를 놓는다.
    /// **아닌 도구에서는 요소를 집고 옮긴다**(`11-T1`).
    var usesCanvas: Bool { draws || self == .text }

    /// 고르는 순간 옵션이 함께 열리는가. **캔버스에서 하는 일이 없는 도구가 그렇다** —
    /// 「다시 눌러 옵션」은 모드를 가진 도구의 관례다.
    var showsOptionsWhenPicked: Bool { self == .photo || self == .paper }

    /// 잉크 색을 쓰는 도구인가. **지우개는 비우는 도구라 색이 아무 일도 안 한다.**
    var usesInk: Bool { self != .eraser }

    /// 굵기의 범위와 기본값. **도구마다 다르다** — 펜은 가늘고 마커는 두껍다.
    var widthRange: ClosedRange<CGFloat> {
        switch self {
        case .pen: 1...20
        case .marker: 8...60
        case .eraser: 8...80
        default: 1...20
        }
    }

    var defaultWidth: CGFloat { self == .pen ? 3 : 24 }

    var glyph: String {
        switch self {
        case .select: Glyph.pointer
        case .pen: Glyph.createRecord
        case .marker: Glyph.marker
        case .eraser: Glyph.eraser
        case .text: Glyph.text
        case .photo: Glyph.image
        case .paper: Glyph.notebook
        }
    }

    var name: String {
        switch self {
        case .select: "선택"
        case .pen: "펜"
        case .marker: "마커"
        case .eraser: "지우개"
        case .text: "글자"
        case .photo: "사진"
        case .paper: "종이"
        }
    }
}

/// 도구 팔레트 한 줄. **활성 도구는 테라코타 채움 + 온강조 글리프다.**
struct CanvasToolPalette: View {
    @Binding var tool: CanvasTool
    let ink: InkColor
    /// 같은 도구를 다시 눌렀다 — 옵션 팝오버를 여는 자리다.
    let onReselect: (CanvasTool) -> Void
    let onInkTap: () -> Void

    var body: some View {
        CanvasBottomBar {
            item(.select)
            CanvasBarDivider()
            ForEach([CanvasTool.pen, .marker, .eraser], id: \.self) { item($0) }
            CanvasBarDivider()
            ForEach([CanvasTool.text, .photo, .paper], id: \.self) { item($0) }
            CanvasBarDivider()
            InkChip(ink: ink, action: onInkTap)
        }
    }

    private func item(_ candidate: CanvasTool) -> some View {
        CanvasBarButton(glyph: candidate.glyph, name: candidate.name,
                        isActive: tool == candidate) {
            if tool == candidate { onReselect(candidate) } else { tool = candidate }
        }
    }
}
