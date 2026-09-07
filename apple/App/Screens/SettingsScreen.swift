// `13` 설정 — 소스와 외형을 바꾸고 약관·버전을 확인한다 (`SYS-03`).

import SwiftUI

struct SettingsScreen: View {
    /// 지금 읽고 있는 앨범 이름. `nil`이면 소스 미지정이라 값 자리가 빈다.
    let sourceName: String?
    /// iPad 시트에서만 채운다 — iPhone은 네비가 되돌아갈 길을 진다.
    var onClose: (() -> Void)?
    /// 뎁스로 가는 길. **뼈대가 진다** — iPhone은 밀고 들어가고 iPad는 시트 안에서 갈린다.
    var onOpen: (SettingsDestination) -> Void = { _ in }
    /// `소스` 행 — **`02` 시트로 곧장 간다**(`SRC-04`). 설정 안의 뎁스가 아니다.
    var onChangeSource: () -> Void = {}

    @Environment(\.accentSet) private var accentSet

    var body: some View {
        if onClose != nil {
            SettingsSheet(title: Wording.settingsTitle) { closeButton } content: { groups }
        } else {
            SettingsPage(title: Wording.settingsTitle) { groups }
        }
    }

    private var closeButton: some View {
        Button { onClose?() } label: {
            Text(Wording.close)
                .font(Typography.label)
                .foregroundStyle(accentSet.accent)
        }
        .buttonStyle(.plain)
    }

    private var groups: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsGroup(rows: [SettingsRow(label: Wording.signInRow, isEnabled: false)])
                accountSlot
            }
            SettingsGroup(rows: [
                SettingsRow(label: Wording.sourceRow, value: sourceName,
                            showsChevron: true, action: onChangeSource),
                SettingsRow(label: Wording.themeRow, showsAccentDot: true,
                            showsChevron: true, action: { onOpen(.theme) }),
                SettingsRow(label: Wording.termsRow, showsChevron: true,
                            action: { onOpen(.terms) }),
                SettingsRow(label: Wording.privacyRow, showsChevron: true,
                            action: { onOpen(.privacy) }),
                SettingsRow(label: Wording.versionRow, value: Self.version),
            ])
        }
    }

    /// `13-F` — **`13`의 유일한 가변 슬롯이다.** 계정 상태가 바뀌면 이 자리의 줄이 바뀐다.
    private var accountSlot: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Wording.accountUnavailable, id: \.self) { line in
                Text(line)
                    .font(Typography.note)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private static let version =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
}

/// `13`이 여는 뎁스. **뼈대가 실제 경로로 옮긴다** — 화면은 어디로 가는지만 말한다.
enum SettingsDestination {
    case theme
    case terms
    case privacy
}
