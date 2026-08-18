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
