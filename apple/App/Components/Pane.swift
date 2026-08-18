// 지면의 문법 — 바탕 · 제본 · 본문 폭. **지면을 가진 화면이 전부 나눠 쓴다.**
//
// ⚠️ **여기 있는 것은 전부 「부르는 쪽이 잊으면 어긋나는」 계약이다.**

import SwiftUI

/// 지면이 iPad 2단에서 어느 쪽인가. **제본이 서는지를 이것이 정한다.**
enum PaneSide {
    /// 왼쪽 — 목록.
    case list
    /// 오른쪽 — 상세·작성. iPhone에서는 밀고 들어가거나 덮개로 뜬다.
    case detail
}

extension View {
    /// 지면 바탕. iPad 2단에서는 `지면`, iPhone에서는 `바탕`이다.
    func paneBackground() -> some View {
        modifier(PaneBackground())
    }

    /// 실 제본을 지면 왼쪽에 흘린다.
    func threadBinding(_ side: PaneSide) -> some View {
        modifier(ThreadBindingOverlay(side: side))
    }

    /// 본문 폭을 재서 넘긴다. **좌우 여백을 뺀 값**이라 격자와 사진이 그대로 쓴다.
    func measuresContentWidth(_ width: Binding<CGFloat>) -> some View {
        modifier(ContentWidth(width: width))
    }

    /// 본문 폭을 상한까지만 쓰고 가운데 세운다. **배경은 이 밖에서 깔아야 화면 끝까지 간다.**
    func readableWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Layout.readableWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }

    /// iPad 2단의 지면 한 장 — 배경과 반경만 진다.
    /// ⚠️ **폭을 건드리지 않는다** — `maxWidth`를 걸면 부르는 쪽이 정한 폭이 도로 늘어난다.
    func pane() -> some View {
        frame(maxHeight: .infinity)
            .background(Palette.pane)
            .clipShape(.rect(cornerRadius: Radius.pane))
    }
}

// MARK: - 조각

/// ⚠️ **iPad 2단에서 `바탕`을 칠하면 안 된다** — 다크에서 지면과 바깥이 같은 값이 되어
/// 두 장의 종이가 통째로 안 보인다.
private struct PaneBackground: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.background(sizeClass == .regular ? Palette.pane : Palette.background)
    }
}

/// ⚠️ **iPad 2단에서는 사이드바 안쪽 하나뿐이다** — 떠 있는 사이드바에 분할선이 없어 좌우
/// 대칭을 만들 필요가 없다. 그래서 상세 지면은 iPhone에서만 긋는다.
private struct ThreadBindingOverlay: ViewModifier {
    let side: PaneSide

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if side == .list || sizeClass == .compact { ThreadBinding() }
        }
    }
}

private struct ContentWidth: ViewModifier {
    @Binding var width: CGFloat

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: {
            width = max(1, min($0, Layout.readableWidth)
                - Layout.leadingMargin(sizeClass) - Spacing.screenMargin)
        }
    }
}
