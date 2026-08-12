// 형광펜 획 — 선택/포커스의 언어.
//
// **이 제품 자신의 도구로 앱이 자기 상태를 말한다** — 마커는 `CAN-05`가 캔버스에서 정의한
// 것이고, 그것을 UI가 빌려 쓰므로 새 어휘가 0이다.

import SwiftUI

/// 손으로 그은 형광펜 한 획.
///
/// ⚠️ **시드를 밖에서 받는다.** 획이 카드마다 미세하게 달라야 손으로 그은 티가 나는데,
/// 매 렌더마다 새로 뽑으면 스크롤할 때마다 같은 카드의 획이 바뀐다.
struct HighlighterStroke: Shape {
    let seed: UInt64

    /// 글자 상자보다 얇다 — 글자를 거의 채우되 넘치지 않는다.
    private static let thickness: ClosedRange<CGFloat> = 15...19
    /// 직선은 도장처럼 보인다.
    private static let waveAmplitude: ClosedRange<CGFloat> = 1...1.5
    private static let tiltDegrees: ClosedRange<CGFloat> = 0.6...1.2

    func path(in rect: CGRect) -> Path {
        var random = Splitmix64(seed: seed)
        let thickness = min(random.value(in: Self.thickness), rect.height)
        let amplitude = random.value(in: Self.waveAmplitude)
        let tilt = random.value(in: Self.tiltDegrees) * (random.bool() ? 1 : -1)
        let rise = rect.width * tan(tilt * .pi / 180)

        // 양끝이 서로 다르게 끝난다. 대칭이면 도장처럼 보인다.
        let head = random.value(in: 1...4)
        let tail = random.value(in: 1...4)
        let left = rect.minX - head
        let right = rect.maxX + tail

        // 위아래 가장자리가 각자 물결친다 — 같은 파형을 쓰면 굵기가 일정해 인쇄처럼 보인다.
        let topPhase = random.value(in: 0...(2 * .pi))
        let bottomPhase = random.value(in: 0...(2 * .pi))
        let cycles = random.value(in: 1.5...2.5)

        var path = Path()
        let steps = 24
        func center(_ t: CGFloat) -> CGFloat { rect.midY - rise / 2 + rise * t }
        func wave(_ t: CGFloat, _ phase: CGFloat) -> CGFloat {
            sin(t * cycles * 2 * .pi + phase) * amplitude
        }

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = left + (right - left) * t
            let y = center(t) - thickness / 2 + wave(t, topPhase)
            step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let t = CGFloat(step) / CGFloat(steps)
            let x = left + (right - left) * t
            path.addLine(to: CGPoint(x: x, y: center(t) + thickness / 2 + wave(t, bottomPhase)))
        }
        path.closeSubpath()
        return path
    }

    /// 눌린 자리 — 시작 쪽 약 3분의 1이 한 겹 더 진하다.
    func pressed(in rect: CGRect) -> Path {
        var random = Splitmix64(seed: seed &+ 1)
        let share = random.value(in: 0.28...0.4)
        return path(in: rect).intersection(
            Path(CGRect(x: rect.minX - 4, y: rect.minY,
                        width: rect.width * share, height: rect.height)))
    }
}

/// 형광펜을 요약 줄 뒤에 긋는다.
///
/// ⚠️ **합성 모드가 모드마다 다르다.** 곱하기는 어둡게 만드는 연산이라 다크에서 원리적으로
/// 안 통한다 — 어두운 지면 위에서 획이 사라진다. 스크린은 빛나 보여 네온이 되고 종이
/// 은유를 깬다. 다크는 일반 합성이 잉크에 가장 가깝다.
private struct Highlighted: ViewModifier {
    let isOn: Bool
    let seed: UInt64
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            if isOn {
                GeometryReader { geometry in
                    let rect = CGRect(origin: .zero, size: geometry.size)
                    let stroke = HighlighterStroke(seed: seed)
                    ZStack {
                        stroke.path(in: rect).fill(Palette.highlighter)
                        stroke.pressed(in: rect).fill(Palette.highlighter)
                    }
                    .blendMode(scheme == .dark ? .normal : .multiply)
                }
            }
        }
    }
}

extension View {
    /// 이 줄에 형광펜을 긋는다. **`seed`는 그 줄이 속한 것의 신원이어야 한다.**
    func highlighted(_ isOn: Bool, seed: UInt64) -> some View {
        modifier(Highlighted(isOn: isOn, seed: seed))
    }
}

/// 결정적 난수. **알고리즘을 고르는 자리가 아니라 「같은 시드면 같은 획」을 보장하는 자리다.**
private struct Splitmix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x1234_5678 }

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
    mutating func value(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
    mutating func bool() -> Bool { next() & 1 == 0 }
}
