// 유리 크롬의 문법 — **머리와 떠 있는 것이 나눠 쓴다.** 재질의 값은 `Chrome`이 갖고 여기는 쓰임이다.
//
// ⚠️ **크롬은 콘텐츠 위에 겹쳐 뜬다** — 나란히 쌓으면 아래로 지나갈 것이 없어 유리가
// 비출 것도 없다. 첫 화면에서 안 가려지는 것은 목록의 상단 여백이 맡는다.

import SwiftUI

extension View {
    /// 스크롤 양을 머리의 접힘(0…1)으로 옮긴다. **탭 대상 한 변만큼 올리면 다 접힌다.**
    func tracksHeaderCollapse(_ collapse: Binding<Double>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            collapse.wrappedValue = min(max(offset / Layout.hitTarget, 0), 1)
        }
    }

    /// 머리 아래 요약 줄 — 접히면 닫힌다.
    /// ⚠️ 앞 절반에서 다 사라진다. 타이틀 교차와 겹치면 둘 다 어중간하다.
    func collapsingSummary(_ collapse: Double) -> some View {
        opacity(1 - min(collapse * 2, 1))
            .frame(height: 21 * (1 - collapse), alignment: .top)
            .clipped()
    }

    /// 펼친 자리의 큰 타이틀 — 접히면 자리를 통째로 내준다.
    /// ⚠️ **크기를 보간하지 않는다** — 접힌 타이틀과 자리가 달라 둘을 교차시켜야 한다.
    func collapsingLargeTitle(_ collapse: Double) -> some View {
        opacity(1 - min(collapse * 2, 1))
            .frame(height: 48 * (1 - collapse), alignment: .top)
            .clipped()
    }

    /// 접힌 자리의 작은 타이틀 — 앞 절반이 지난 뒤에 나온다.
    /// 둘이 반투명하게 겹치는 구간을 두지 않는다. 겹치면 글자가 탁해진다.
    func collapsingInlineTitle(_ collapse: Double) -> some View {
        opacity(max(collapse * 2 - 1, 0))
    }

    /// 머리 뒤의 가림막이자 **자기 자리를 통째로 막는 층** — 네비 바가 원래 스크롤을 안 받는다.
    /// ⚠️ iPad는 가림막을 안 깔아 통째로 투명했고, 타이틀 옆 탭이 뒤로 샜다(2026-08-13 로그).
    func headerScrim() -> some View {
        modifier(HeaderScrim()).contentShape(.rect)
    }

    /// 떠 있는 크롬이 **자기 둘레까지** 탭을 삼킨다 — 캡슐 옆 투명 여백은 히트 테스트를 안 잡는다.
    /// ⚠️ 띠 전체를 막으면 그 자리에서 **스크롤이 죽는다** — 머리와 갈리는 자리다(2026-08-13 실물).
    func blocksNearbyTaps(halo: CGFloat = 8) -> some View {
        padding(halo).contentShape(.rect).padding(-halo)
    }

    /// 유리 캡슐 — 글자와 아이콘만 띄우고 지면은 그 사이로 계속 보인다.
    func glassCapsule(padding: CGFloat = 12) -> some View {
        self.padding(.horizontal, padding)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }
}

/// ⚠️ **iPad 지면에서는 가림막을 안 깐다** (사용자 판정 2026-08-12). 지면이 반경과 여백으로
/// 이미 경계를 갖고 있어 색이 사라지는 띠가 하나 더 생기면 경계가 둘로 읽히고, **무엇보다
/// 뒤에 지나갈 것을 가려 버리면 유리가 할 일이 없어진다.**
///
/// 가림막이 필요한 이유는 iPhone에만 있다 — 유리 캡슐 위쪽의 **상태 표시줄**이 비어서,
/// 밝은 사진이 지나가면 시각·배터리가 안 읽힌다. iPad 지면은 상태 표시줄 아래에 있다.
private struct HeaderScrim: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.background {
            if sizeClass == .compact {
                LinearGradient(stops: Scrim.stops, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }
}

/// 머리 뒤 가림막의 감쇠 곡선.
private enum Scrim {
    /// ⚠️ **양 끝 기울기가 0이어야 하고 높이는 머리 전체를 쓴다** — 직선으로 0까지 가거나
    /// 높이를 줄이면 그 자리가 잘린 선으로 보인다 (2026-08-11 실물).
    static let stops: [Gradient.Stop] = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
        // smoothstep을 뒤집은 것 — 1에서 시작해 0으로, 양 끝이 평평하다.
        Gradient.Stop(color: Palette.background.opacity(1 - $0 * $0 * (3 - 2 * $0)),
                      location: $0)
    }
}
