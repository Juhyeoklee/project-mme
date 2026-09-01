// 사용자가 고르는 두 축 — 포인트 컬러 여섯 벌(`SYS-07`)과 화면 모드 3지(`SYS-06`).
// 값은 벌이 정하고 합성·불투명도는 모드가 정한다. **강조 계열은 전부 여기서 파생된다.**

import SwiftUI

/// 강조색 한 벌. **한 벌이 값을 둘 든다** — 모드마다 다른 값이 사용자에게는 한 이름으로 읽힌다.
enum AccentSet: String, CaseIterable, Identifiable, Sendable {
    case terracotta, burgundy, navy, olive, ginkgo, rose

    static let `default` = AccentSet.terracotta

    var id: String { rawValue }

    /// 라이트 값. ⚠️ **모드를 안 타는 자리가 이 값을 직접 쓴다**(`11-C6` 선택 핸들).
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

    /// ⚠️ **은행잎만 라이트와 값이 같다** — 지우고 `light`를 부르면 안 된다.
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

    /// 도구 활성 · 주요 액션 · 입력 캐럿.
    var accent: Color { .mode(light: light, dark: dark) }

    /// 카드 없이 홀로 떠 있는 주요 액션의 유리 틴트. **알파는 여섯 벌 공통이다.**
    var accentTint: Color { accent.opacity(0.20) }

    /// 배경 위 형광펜.
    var highlighter: Color { .mode(light: light.opacity(0.278), dark: dark.opacity(0.38)) }

    /// 유리 위 형광펜.
    /// ⚠️ **`accentTint`와 값이 같아도 합치면 안 된다** — 한쪽을 고치면 딸려 움직인다.
    var glassHighlighter: Color { accent.opacity(0.20) }

    /// `11-C6` 선택 핸들 채움. ⚠️ **모드 고정이다** — 캔버스 위에 얹히므로 모드를 타면 안 된다.
    var selectionFill: Color { light }
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

/// 저장 자리. **기기마다 따로 저장한다** — 동기화하지 않는다.
/// ⚠️ **키를 쓰는 곳이 셋이라 여기서 진다** — 뿌리 · `13` · `13-A`.
enum AppearanceStorage {
    static let accentKey = "appearance.accentSet"
    static let modeKey = "appearance.mode"
}

extension EnvironmentValues {
    /// 고른 강조색 벌. **강조 계열을 쓰는 화면은 전부 이것을 읽는다.**
    @Entry var accentSet = AccentSet.default
}
