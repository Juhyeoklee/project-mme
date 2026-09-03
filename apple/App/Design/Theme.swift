// 사용자가 고르는 두 축 — 포인트 컬러 여섯 벌(`SYS-07`)과 화면 모드 3지(`SYS-06`).
// 값은 벌이 정하고 합성·불투명도는 모드가 정한다. **강조 계열은 전부 여기서 파생된다.**

import SwiftUI

/// 강조색 한 벌 — 모드마다 값 하나.
enum AccentSet: String, CaseIterable, Identifiable, Sendable {
    case terracotta, burgundy, navy, olive, ginkgo, rose

    static let `default` = AccentSet.terracotta

    var id: String { rawValue }

    var light: Color {
        switch self {
        case .terracotta: Color(hex: 0xB0552B)
        case .burgundy: Color(hex: 0x942736)
        case .navy: Color(hex: 0x476EBB)
        case .olive: Color(hex: 0x6B7238)
        case .ginkgo: Color(hex: 0xE8B93A)
        case .rose: Color(hex: 0xB8496E)
        }
    }

    var dark: Color {
        switch self {
        case .terracotta: Color(hex: 0xDD8455)
        case .burgundy: Color(hex: 0xCD5551)
        case .navy: Color(hex: 0x7E9BD6)
        case .olive: Color(hex: 0xAFB863)
        case .ginkgo: Color(hex: 0xE8B93A)
        case .rose: Color(hex: 0xD6839E)
        }
    }

    // MARK: - 파생

    var accent: Color { .mode(light: light, dark: dark) }

    var accentTint: Color { accent.opacity(0.20) }

    var highlighter: Color { .mode(light: light.opacity(0.278), dark: dark.opacity(0.38)) }

    /// ⚠️ **`accentTint`와 값이 같아도 합치지 마라** — 한쪽을 고치면 딸려 움직인다.
    var glassHighlighter: Color { accent.opacity(0.20) }

    var selectionFill: Color { .mode(light: light, dark: light) }
}

/// 화면 모드. **기본은 시스템 따름**이고 그때는 앱이 아무것도 강제하지 않는다.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    static let `default` = AppearanceMode.system

    var id: String { rawValue }

    /// ⚠️ **`nil`이 「시스템 따름」이다** — `preferredColorScheme`이 그렇게 읽는다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// 저장 키. 쓰는 곳이 셋이라 여기서 진다.
enum AppearanceStorage {
    static let accentKey = "appearance.accentSet"
    static let modeKey = "appearance.mode"
}

extension EnvironmentValues {
    /// 고른 강조색 벌.
    @Entry var accentSet = AccentSet.default
}
