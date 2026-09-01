// `13-A 테마` — 화면 모드(`SYS-06`)와 포인트 컬러(`SYS-07`)를 한 목록에서 고른다.
//
// ⚠️ **이 화면은 자기가 고르는 색과 모드로 자기가 칠해진다** — 고른 결과를 그 자리에서 본다.

import SwiftUI

struct ThemeScreen: View {
    /// iPad 시트 안에서 뜨는가. **모양만 가른다** — 되돌아가는 길은 두 경우 다 네비다.
    var isInSheet = false

    @AppStorage(AppearanceStorage.accentKey) private var accentSet = AccentSet.default
    @AppStorage(AppearanceStorage.modeKey) private var mode = AppearanceMode.default

    var body: some View {
        if isInSheet {
            SettingsSheet(title: Wording.themeRow) { SettingsBackButton() } content: { groups }
        } else {
            SettingsPage(title: Wording.themeRow) { groups }
        }
    }

    private var groups: some View {
        VStack(alignment: .leading, spacing: 24) {
            group(Wording.appearanceModeSection) {
                SettingsGroup(rows: AppearanceMode.allCases.map { candidate in
                    SettingsRow(label: Wording.appearanceMode(candidate),
                                isChecked: candidate == mode,
                                action: { mode = candidate })
                })
            }
            group(Wording.accentSection) { chips }
        }
    }

    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.note)
                .foregroundStyle(Palette.secondaryLabel)
                .padding(.horizontal, 4)
            content()
        }
    }

    /// ⚠️ **이름을 안 쓴다** — 고르는 것이 눈이라 낱말이 하는 일이 없다.
    private var chips: some View {
        HStack(spacing: 0) {
            ForEach(AccentSet.allCases) { candidate in
                Button { accentSet = candidate } label: {
                    Circle()
                        .fill(candidate.accent)
                        .frame(width: Self.chip, height: Self.chip)
                        .frame(width: Self.chipRing, height: Self.chipRing)
                        // ⚠️ **링은 문자색이다** — 고르는 대상과 같은 축이면 ΔE가 0이 된다.
                        .overlay {
                            if candidate == accentSet {
                                Circle().strokeBorder(Palette.label, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Wording.accentLabel(candidate))
                .accessibilityAddTraits(candidate == accentSet ? [.isSelected] : [])
                if candidate != AccentSet.allCases.last { Spacer(minLength: 0) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Palette.listSurface)
        .clipShape(.rect(cornerRadius: Radius.card))
    }

    private static let chip: CGFloat = 30
    private static let chipRing: CGFloat = 40
}
