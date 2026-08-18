// `11`의 하단 바 — 도구 팔레트와 선택 인스펙터가 같은 껍데기를 쓴다.

import SwiftUI

/// 하단 바의 껍데기.
///
/// **자리와 높이가 둘 다 같아야 한다** — 팔레트와 인스펙터가 같은 자리에서 갈아끼워지므로,
/// 몇 pt만 어긋나도 손이 기억한 위치가 흔들린다. 그래서 그 값을 부르는 쪽에 안 맡긴다.
struct CanvasBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.horizontal, 12)
            .frame(height: Layout.canvasPaletteHeight)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
            .blocksNearbyTaps()
    }
}

/// 하단 바 안의 글리프 버튼. **팔레트의 도구와 인스펙터의 겹침 순서가 같은 칸을 쓴다.**
struct CanvasBarButton: View {
    let glyph: String
    let name: String
    var isActive = false
    let action: () -> Void

    static let width: CGFloat = 44
    static let height: CGFloat = 40
    static let glyphSize: CGFloat = 22

    var body: some View {
        Button(action: action) {
            CanvasBarGlyph(glyph: glyph, isActive: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

/// 버튼 안의 그림. **활성은 테라코타 채움 + 온강조 글리프다.**
/// ⚠️ `Menu`는 `Button`이 아니라 이 조각만 쓴다.
struct CanvasBarGlyph: View {
    let glyph: String
    var isActive = false

    var body: some View {
        GlyphIcon(glyph, size: CanvasBarButton.glyphSize)
            .foregroundStyle(isActive ? Palette.onAccent : Palette.label)
            .frame(width: CanvasBarButton.width, height: CanvasBarButton.height)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Radius.button).fill(Palette.accent)
                }
            }
    }
}

/// 하단 바 안의 칸 구분.
struct CanvasBarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.placeholder)
            .frame(width: 1, height: 24)
    }
}

/// 현재 잉크 색. **팔레트와 인스펙터에서 자리가 같다** — 오른쪽에서 둘째다.
struct InkChip: View {
    let ink: InkColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(ink.color)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Palette.placeholder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ink.name)
    }
}
