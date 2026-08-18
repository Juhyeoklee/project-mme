// 값 하나를 슬라이더와 스테퍼가 함께 가리킨다 — `11-I3` 글자 크기와 `11-O1` 획 굵기.

import SwiftUI

/// 슬라이더 + 스테퍼. **둘이 같은 값을 가리킨다** — 대충 맞추는 길과 1씩 맞추는 길이 함께 선다.
///
/// ⚠️ **폭이 고정이다** — 값 컨트롤이 여러 줄로 서는 자리(`11-O1`)에서 라벨·슬라이더·스테퍼가
/// 한 격자에 서야 한다. 부르는 쪽이 폭을 정하면 줄마다 어긋난다.
struct CanvasValueSlider: View {
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    /// 낭독 이름이자, 여러 줄로 설 때의 **인라인 라벨**.
    let name: String
    /// 라벨을 함께 보이는가. 바 안에서는 자리가 그 뜻을 지므로 안 보인다.
    var showsLabel = false
    /// 값을 확정한다. ⚠️ **슬라이더는 손을 뗄 때만 부른다** — 끄는 내내 부르면 되돌리기가
    /// 1씩 되감긴다.
    let onChange: (CGFloat) -> Void

    /// 손이 붙어 있는 동안의 값.
    @State private var live: CGFloat?

    private var shown: CGFloat { live ?? value }

    var body: some View {
        HStack(spacing: 8) {
            if showsLabel {
                Text(name)
                    .font(Typography.note)
                    .foregroundStyle(Palette.secondaryLabel)
                    .frame(width: Self.labelWidth, alignment: .leading)
            }
            Slider(value: Binding(get: { shown }, set: { live = $0 }), in: range,
                   onEditingChanged: { editing in
                       guard !editing, let live else { return }
                       onChange(live.rounded())
                       self.live = nil
                   })
                .tint(Palette.accent)
                .frame(width: Self.sliderWidth)
                .accessibilityLabel(name)
                .padding(.trailing, 2)
            stepper
        }
        .frame(height: Self.height)
    }

    static let labelWidth: CGFloat = 44
    static let sliderWidth: CGFloat = 110
    static let height: CGFloat = 30

    private var stepper: some View {
        HStack(spacing: 0) {
            step(Glyph.subtract, by: -1)
            Text("\(Int(shown.rounded()))")
                .font(Typography.subtitle)
                .foregroundStyle(Palette.label)
                .frame(width: Self.cell)
                .monospacedDigit()
            step(Glyph.add, by: 1)
        }
        .frame(height: Self.height)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.button))
    }

    /// 스테퍼 한 칸. **44 하한을 안 지킨다** — 슬라이더가 같은 값에 이르는 넓은 길이라
    /// 여기가 막다른 길이 아니다 (`11-C6` 핸들과 같은 근거).
    private static let cell: CGFloat = 26

    private func step(_ glyph: String, by delta: CGFloat) -> some View {
        Button {
            onChange(min(max(shown.rounded() + delta, range.lowerBound), range.upperBound))
        } label: {
            GlyphIcon(glyph, size: 16)
                .foregroundStyle(Palette.label)
                .frame(width: Self.cell, height: Self.height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? Wording.increase(name) : Wording.decrease(name))
    }
}
