// 형광펜 획 — 선택/포커스의 언어. 마커는 `CAN-05`의 것을 빌려 쓴다.

import SwiftUI

/// 마커로 두 번 그은 자국.
///
/// ⚠️ **가장자리를 절차적으로 흔들지 않는다** — 흔든 사각형은 얼룩이 된다. 미리 그려 둔
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
        /// 폭에 대한 비율. **1을 넘거나 0 미만이면 글자 밖으로 삐져나온다.**
        let from: CGFloat, to: CGFloat
        /// 높이에 대한 비율(중심) · 두께(pt) · 기울기(도)
        let center: CGFloat, thickness: CGFloat, tilt: CGFloat
        /// 촉이 눕는 각. **양끝이 서로 달라야 한다.**
        let headCut: CGFloat, tailCut: CGFloat

        /// `drawn`이 1보다 작으면 **긋다 만 획**이다 — 시작점은 그대로 두고 끝만 당겨온다.
        func path(in rect: CGRect, drawn: CGFloat = 1) -> Path {
            let x0 = rect.minX + rect.width * from
            let x1 = x0 + (rect.minX + rect.width * to - x0) * drawn
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

    /// 손으로 그은 여섯 벌. ⚠️ **왼쪽 시작은 맞추고 오른쪽만 어긋낸다** — 끝 차이도 10% 안이다.
    /// ⚠️ **값이 아니라 그림이다** — 늘리려면 눈으로 보고 더한다.
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

/// 눈앞에서 그어지는 한 획. **`HighlighterStroke`와 달리 획이 하나다.**
struct HighlighterSweep: Shape {
    /// 0이면 안 그었고 1이면 끝까지 그었다.
    var drawn: CGFloat
    /// 촉의 굵기. **활자가 커지면 같이 굵어져야 한다** — 안 그러면 큰 글자 위에서 밑줄이 된다.
    var thickness: CGFloat = 20
    /// 상자 높이에서 획이 앉는 자리. ⚠️ **손글씨는 어센트가 커서 글자가 상자 아래쪽에 산다** —
    /// 가운데에 그으면 글자 위를 덮는다.
    var center: CGFloat = 0.5

    var animatableData: CGFloat {
        get { drawn }
        set { drawn = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // ⚠️ **0에서 빈 획이어야 한다** — 촉이 비스듬히 잘려 있어 길이를 0으로 줄여도
        // 시작점에 삼각형 조각이 남는다. 안 고른 탭에 얼룩이 하나 붙는다.
        guard drawn > 0.001 else { return Path() }
        return Self.swipe(thickness, center).path(in: rect, drawn: drawn)
    }

    /// 낱말을 덮는 굵은 획. ⚠️ **글자 높이를 안 따라간다** — 마커 촉의 굵기는 활자가 아니라
    /// 펜이 정하는 값이고, 글자에 맞추면 획이 얇아져 배경 칩처럼 읽힌다.
    private static func swipe(_ thickness: CGFloat, _ center: CGFloat) -> HighlighterStroke.Swipe {
        HighlighterStroke.Swipe(from: -0.02, to: 1.02, center: center, thickness: thickness,
                                tilt: -1.5, headCut: 3, tailCut: 2)
    }
}

/// 눈앞에서 그어지는 획. **시간이 아니라 속도를 고정한다** — 손으로 긋는 것은 길이가 달라도
/// 속도가 비슷해서, 짧은 낱말은 짧게 긴 줄은 길게 걸린다.
private struct SweepingHighlight: ViewModifier {
    let isOn: Bool
    let delay: Double
    let center: CGFloat

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accentSet) private var accentSet
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var drawn: CGFloat = 0

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                HighlighterSweep(drawn: isOn ? drawn : 0,
                                 thickness: geometry.size.height * Self.weight,
                                 center: center)
                    .fill(accentSet.highlighter)
                    .blendMode(scheme == .dark ? .normal : .multiply)
                    .onAppear { if isOn { draw(across: geometry.size.width) } }
                    // ⚠️ **지우는 쪽에는 애니메이션이 없다** — 역방향으로 지우면 시선이 왕복한다.
                    .onChange(of: isOn) { _, on in
                        if on { draw(across: geometry.size.width) } else { drawn = 0 }
                    }
            }
        }
    }

    private func draw(across width: CGFloat) {
        guard !reducesMotion else {
            drawn = 1
            return
        }
        let seconds = min(width / Self.speed, Self.longest)
        withAnimation(.easeOut(duration: seconds).delay(delay)) { drawn = 1 }
    }

    /// 글자 상자 높이에 대한 촉의 굵기.
    private static let weight: CGFloat = 0.58
    /// 초당 pt. ⚠️ **실물 판정 전이다** — 눈으로 보고 고친다.
    private static let speed: CGFloat = 700
    /// 긴 줄에서 늘어지지 않게 거는 상한.
    private static let longest: Double = 0.5
}

/// 형광펜을 요약 줄 뒤에 긋는다.
///
/// ⚠️ **합성 모드가 모드마다 다르다** — 곱하기는 어둡게 만드는 연산이라 다크에서 획이 사라진다.
///
/// ⚠️ **획을 하나씩 따로 칠한다** — 한 `Path`로 합치면 겹친 자리가 안 진해진다.
private struct Highlighted: ViewModifier {
    let isOn: Bool
    let seed: UInt64
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accentSet) private var accentSet

    func body(content: Content) -> some View {
        content.background {
            if isOn {
                GeometryReader { geometry in
                    let rect = CGRect(origin: .zero, size: geometry.size)
                    let swipes = HighlighterStroke.patterns[
                        Int(seed % UInt64(HighlighterStroke.patterns.count))]
                    ForEach(Array(swipes.enumerated()), id: \.offset) { _, swipe in
                        swipe.path(in: rect)
                            .fill(accentSet.highlighter)
                            .blendMode(scheme == .dark ? .normal : .multiply)
                    }
                }
            }
        }
    }
}

extension View {
    /// 이 줄에 형광펜이 **그어지는 것을 보인다.** 한 화면에 둘이면 `delay`로 차례를 준다 —
    /// 동시에 그으면 둘 다 놓친다.
    func highlighterSweeps(_ isOn: Bool = true, after delay: Double = 0,
                           center: CGFloat = 0.6) -> some View {
        modifier(SweepingHighlight(isOn: isOn, delay: delay, center: center))
    }

    /// 이 줄에 형광펜을 긋는다. **`seed`는 그 줄이 속한 것의 신원이어야 한다** —
    /// 매 렌더마다 다시 뽑으면 스크롤할 때마다 같은 카드의 획이 바뀐다.
    func highlighted(_ isOn: Bool, seed: UInt64) -> some View {
        modifier(Highlighted(isOn: isOn, seed: seed))
    }
}
