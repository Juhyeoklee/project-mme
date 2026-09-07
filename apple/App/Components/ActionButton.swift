// 액션 버튼. **파괴는 이 위계에 없다** — 삭제·탈퇴는 시스템 `.destructive` role에 위임한다.

import SwiftUI

/// 주요 — 강조색 면. 한 화면에 하나뿐이다.
struct PrimaryActionStyle: ButtonStyle {
    /// 혼자 서서 누르라고 놓인 자리. 툴바 안 알약은 여전히 내용물 폭이다.
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        Rendered(configuration: configuration, fillsWidth: fillsWidth)
    }

    private struct Rendered: View {
        let configuration: Configuration
        let fillsWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accentSet) private var accentSet

        var body: some View {
            configuration.label
                .foregroundStyle(isEnabled ? Palette.onAccent : Palette.disabled)
                .filledShape(fillsWidth: fillsWidth, pressed: configuration.isPressed)
                // ⚠️ 비활성은 `surface`가 아니라 `innerSurface`다 — 시트 안에 서면 다크에서
                // 시트와 값이 같아 버튼이 통째로 사라진다.
                .background(isEnabled ? accentSet.accent : Palette.innerSurface)
                .clipShape(.rect(cornerRadius: Radius.button))
        }
    }
}

/// 보조 — 면 위에 테두리. **주요와 나란히 설 때 위에 온다**(엄지에 가까운 쪽이 주요다).
struct SecondaryActionStyle: ButtonStyle {
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        Rendered(configuration: configuration, fillsWidth: fillsWidth)
    }

    private struct Rendered: View {
        let configuration: Configuration
        let fillsWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accentSet) private var accentSet

        var body: some View {
            configuration.label
                .foregroundStyle(isEnabled ? accentSet.accent : Palette.disabled)
                .filledShape(fillsWidth: fillsWidth, pressed: configuration.isPressed)
                .background(Palette.innerSurface)
                .clipShape(.rect(cornerRadius: Radius.button))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(Palette.placeholder, lineWidth: 1)
                }
        }
    }
}

/// 평문 — 배경 없음.
///
/// ⚠️ **버튼 문구는 한 활자다** — 네비 평문 버튼만 예외를 두면 같은 화면 안에서 서체가
/// 둘이 된다 (사용자 판정 2026-08-13).
struct PlainActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Rendered(configuration: configuration)
    }

    private struct Rendered: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accentSet) private var accentSet

        var body: some View {
            configuration.label
                .font(Typography.label)
                .foregroundStyle(isEnabled ? accentSet.accent : Palette.disabled)
                .padding(.vertical, 9)
                .padding(.horizontal, 10)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}

// MARK: - 채워진 버튼이 나눠 쓰는 것

private extension View {
    /// 채워진 버튼의 활자·패딩·누름. **주요와 보조가 값이 아니라 구조를 나눠 쓴다** —
    /// 한쪽만 고치면 나란히 선 두 버튼이 조용히 어긋난다.
    func filledShape(fillsWidth: Bool, pressed: Bool) -> some View {
        font(Typography.label)
            .padding(.vertical, fillsWidth ? 16 : 9)
            .padding(.horizontal, fillsWidth ? 24 : 18)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .opacity(pressed ? 0.7 : 1)
    }
}

extension View {
    /// 혼자 서는 액션의 폭 상한. **`01`과 `02`가 나눠 쓴다** — 부르는 쪽이 둘째 프레임을
    /// 빠뜨리면 넓은 지면에서 버튼이 가운데로 안 온다.
    func actionWidth() -> some View {
        frame(maxWidth: Layout.actionButtonMaxWidth)
            .frame(maxWidth: .infinity)
    }
}
