// 액션 버튼. **파괴는 이 위계에 없다** — 삭제·탈퇴는 시스템 `.destructive` role에 위임한다.

import SwiftUI

/// 주요 — 강조색 면. 한 화면에 하나뿐이다.
struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Rendered(configuration: configuration)
    }

    private struct Rendered: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Typography.label)
                .foregroundStyle(isEnabled ? Palette.onAccent : Palette.disabled)
                .padding(.vertical, 9)
                .padding(.horizontal, 18)
                .background(isEnabled ? Palette.accent : Palette.surface)
                .clipShape(.rect(cornerRadius: Radius.button))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// 평문 — 배경 없음.
///
/// ⚠️ **떠 있는 툴바 안에서는 `라벨`을 쓴다**(14 semibold). 옆에 선 주요 버튼과 활자가 갈리면
/// 두 버튼이 다른 층위로 읽힌다. 네비 바의 평문 버튼은 그쪽 관례대로 `본문` 16이다.
struct PlainActionStyle: ButtonStyle {
    var font: Font = Typography.label

    func makeBody(configuration: Configuration) -> some View {
        Rendered(configuration: configuration, font: font)
    }

    private struct Rendered: View {
        let configuration: Configuration
        let font: Font
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(font)
                .foregroundStyle(isEnabled ? Palette.accent : Palette.disabled)
                .padding(.vertical, 9)
                .padding(.horizontal, 10)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
