// 유리 머리의 조각들. 머리를 직접 그리는 화면들이 나눠 쓴다.
//
// ⚠️ **머리는 콘텐츠 위에 겹쳐 뜬다** — 나란히 쌓으면 아래로 지나갈 것이 없어 유리가
// 비출 것도 없다. 첫 화면에서 안 가려지는 것은 목록의 상단 여백이 맡는다.

import SwiftUI

extension View {
    /// 머리 아래 요약 줄 — 접히면 닫힌다.
    /// ⚠️ 앞 절반에서 다 사라진다. 타이틀 교차와 겹치면 둘 다 어중간하다.
    func collapsingSummary(_ collapse: Double) -> some View {
        opacity(1 - min(collapse * 2, 1))
            .frame(height: 21 * (1 - collapse), alignment: .top)
            .clipped()
    }

    /// 펼친 자리의 큰 타이틀 — 접히면 자리를 통째로 내준다.
    ///
    /// ⚠️ **활자 크기를 보간하지 않는다** — 늘어났다 줄어드는 글자는 어색하고, 무엇보다
    /// 접힌 타이틀은 **자리가 다르다.** 둘을 교차시키는 것이 그 이동을 표현하는 방법이다.
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

    /// 머리 뒤의 가림막.
    ///
    /// ⚠️ **면을 깔지 않는다** — 유리 캡슐은 자기 자리만 덮으므로 그 위(상태 표시줄)가 비고,
    /// 밝은 사진이 지나가면 시각·배터리가 안 읽힌다. 위에서 아래로 사라지는 것이라
    /// 지면은 그대로 비친다.
    func headerScrim() -> some View {
        background {
            LinearGradient(stops: Scrim.stops, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// 유리 캡슐.
    ///
    /// **콘텐츠가 아래로 지나가는 크롬이 자기 자리를 갖는 방법이다** — 면을 통째로 깔지 않고
    /// 글자와 아이콘만 유리로 띄운다. 지면은 그 사이로 계속 보인다.
    func glassCapsule(padding: CGFloat = 12) -> some View {
        self.padding(.horizontal, padding)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }
}

/// 머리 뒤 가림막의 감쇠 곡선.
private enum Scrim {
    /// ⚠️ **직선으로 0까지 가면 끝이 잘린 듯 보인다** — 기울기가 그 지점에서 꺾이고 눈이
    /// 그 선을 찾아낸다. **양 끝의 기울기가 0인 곡선**이라야 시작도 끝도 안 걸린다
    /// (사용자 판정 2026-08-11). 높이는 머리 전체를 쓴다 — 줄이면 그 자리가 다시 선이 된다.
    static let stops: [Gradient.Stop] = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
        // smoothstep을 뒤집은 것 — 1에서 시작해 0으로, 양 끝이 평평하다.
        Gradient.Stop(color: Palette.background.opacity(1 - $0 * $0 * (3 - 2 * $0)),
                      location: $0)
    }
}
