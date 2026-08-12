// 형광펜 획 — 선택/포커스의 언어.
//
// **이 제품 자신의 도구로 앱이 자기 상태를 말한다** — 마커는 `CAN-05`가 캔버스에서 정의한
// 것이고, 그것을 UI가 빌려 쓰므로 새 어휘가 0이다.

import SwiftUI

/// 마커로 두 번 그은 자국.
///
/// ⚠️ **가장자리를 절차적으로 흔들지 않는다** — 흔든 사각형은 손맛이 아니라 얼룩이 된다.
/// 손맛은 **획이 곧게 그어지되 두 번이 서로 안 맞는 데서** 나온다. 그래서 미리 그려 둔
/// 패턴을 시드로 고른다: 결정적이면서 카드마다 다르다.
struct HighlighterStroke: Shape {
    let seed: UInt64

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for swipe in Self.patterns[Int(seed % UInt64(Self.patterns.count))] {
            path.addPath(swipe.path(in: rect))
        }
        return path
    }

    /// 한 번의 긋기. 곧은 사각형이되 양끝이 마커 촉처럼 비스듬히 잘린다.
    fileprivate struct Swipe {
        /// 폭에 대한 비율. **1을 넘거나 0 미만이면 글자 밖으로 삐져나온다** — 그게 자연스럽다.
        let from: CGFloat, to: CGFloat
        /// 높이에 대한 비율(중심) · 두께(pt) · 기울기(도)
        let center: CGFloat, thickness: CGFloat, tilt: CGFloat
        /// 촉이 눕는 각. 양끝이 서로 달라야 도장처럼 안 보인다.
        let headCut: CGFloat, tailCut: CGFloat

        func path(in rect: CGRect) -> Path {
            let x0 = rect.minX + rect.width * from
            let x1 = rect.minX + rect.width * to
            let rise = (x1 - x0) * tan(tilt * .pi / 180)
            let y0 = rect.minY + rect.height * center - rise / 2
            let y1 = y0 + rise
            let half = thickness / 2

            var path = Path()
            path.move(to: CGPoint(x: x0 + headCut, y: y0 - half))
            path.addLine(to: CGPoint(x: x1 + tailCut, y: y1 - half))
            path.addLine(to: CGPoint(x: x1 - tailCut, y: y1 + half))
            path.addLine(to: CGPoint(x: x0 - headCut, y: y0 + half))
            path.closeSubpath()
            return path
        }
    }

    /// 손으로 그은 여섯 벌. **두 번씩 긋고, 두 획이 어긋나는 방식이 패턴마다 다르다.**
    ///
    /// ⚠️ **왼쪽은 맞고 오른쪽만 어긋난다** (사용자 판정 2026-08-12) — 형광펜은 시작점을
    /// 글자 왼쪽에 대고 긋고, **어디서 멈추는지가 매번 다르다.** 시작이 들쭉날쭉하면
    /// 그은 것이 아니라 흘린 것으로 보인다. 끝 차이도 10%를 안 넘긴다.
    ///
    /// ⚠️ 값을 고르는 자리가 아니라 **그림**이다 — 늘리려면 눈으로 보고 더한다.
    fileprivate static let patterns: [[Swipe]] = [
        // 아래 획이 조금 더 나가고 더 눕는다
        [Swipe(from: -0.01, to: 0.96, center: 0.36, thickness: 12, tilt: -1.1, headCut: 3, tailCut: 1.5),
         Swipe(from: -0.02, to: 1.03, center: 0.64, thickness: 12, tilt: -2.2, headCut: 2, tailCut: 4)],
        // 위 획이 먼저 멈춘다
        [Swipe(from: -0.02, to: 0.93, center: 0.34, thickness: 12, tilt: 0.8, headCut: 4, tailCut: 2.5),
         Swipe(from: -0.01, to: 1.01, center: 0.62, thickness: 13, tilt: 1.8, headCut: 1.5, tailCut: 3)],
        // 둘 다 올라가되 두 번째가 더 눕고 조금 짧다
        [Swipe(from: -0.01, to: 1.02, center: 0.37, thickness: 12, tilt: -2.0, headCut: 2.5, tailCut: 3.5),
         Swipe(from: -0.02, to: 0.95, center: 0.63, thickness: 12, tilt: -3.0, headCut: 3.5, tailCut: 2)],
        // 첫 획이 굵고 길게, 두 번째가 얇고 짧게
        [Swipe(from: -0.02, to: 1.04, center: 0.44, thickness: 14, tilt: 0.5, headCut: 2, tailCut: 2),
         Swipe(from: -0.01, to: 0.94, center: 0.66, thickness: 11, tilt: -1.4, headCut: 4, tailCut: 4)],
        // 반대로 기울어 오른쪽에서 벌어진다
        [Swipe(from: -0.01, to: 0.98, center: 0.35, thickness: 12, tilt: -1.6, headCut: 3, tailCut: 2),
         Swipe(from: -0.02, to: 1.04, center: 0.63, thickness: 12, tilt: 1.4, headCut: 2, tailCut: 3.5)],
        // 거의 나란하고 끝만 살짝 갈린다
        [Swipe(from: 0.0, to: 0.94, center: 0.40, thickness: 13, tilt: 2.0, headCut: 2.5, tailCut: 4),
         Swipe(from: -0.01, to: 1.0, center: 0.60, thickness: 13, tilt: 0.4, headCut: 3, tailCut: 2)],
    ]
}

/// 형광펜을 요약 줄 뒤에 긋는다.
///
/// ⚠️ **합성 모드가 모드마다 다르다.** 곱하기는 어둡게 만드는 연산이라 다크에서 원리적으로
/// 안 통한다 — 어두운 지면 위에서 획이 사라진다. 스크린은 빛나 보여 네온이 되고 종이
/// 은유를 깬다. 다크는 일반 합성이 잉크에 가장 가깝다.
///
/// **획을 하나씩 따로 칠한다** — 한 `Path`로 합치면 겹친 자리가 안 진해져서, 두 번 그은
/// 티가 사라지고 한 덩어리로 보인다.
private struct Highlighted: ViewModifier {
    let isOn: Bool
    let seed: UInt64
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            if isOn {
                GeometryReader { geometry in
                    let rect = CGRect(origin: .zero, size: geometry.size)
                    let swipes = HighlighterStroke.patterns[
                        Int(seed % UInt64(HighlighterStroke.patterns.count))]
                    ForEach(Array(swipes.enumerated()), id: \.offset) { _, swipe in
                        swipe.path(in: rect)
                            .fill(Palette.highlighter)
                            .blendMode(scheme == .dark ? .normal : .multiply)
                    }
                }
            }
        }
    }
}

extension View {
    /// 이 줄에 형광펜을 긋는다. **`seed`는 그 줄이 속한 것의 신원이어야 한다** —
    /// 매 렌더마다 다시 뽑으면 스크롤할 때마다 같은 카드의 획이 바뀐다.
    func highlighted(_ isOn: Bool, seed: UInt64) -> some View {
        modifier(Highlighted(isOn: isOn, seed: seed))
    }
}
