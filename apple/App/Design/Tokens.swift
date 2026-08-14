// 디자인 토큰 — 값의 출처는 디자인 문서고 여기는 번역이다. **여기서 값을 발명하지 않는다** —
// 화면설계서·실측에서 온 치수는 `Layout.swift`가 따로 든다. 이름은 크기가 아니라 역할이다.
//
// 층이 둘인데 **비대칭이다** — 뉴트럴만 원시값 램프를 갖고 강조색은 시맨틱이 값을 직접 든다.
// 뉴트럴은 계단이 본체라 램프 없이 라이트/다크 값을 각각 적으면 표류한다.

import CoreText
import SwiftUI

/// 원시값 — 「종이」 램프 12단 + 램프 밖 상수 하나.
///
/// 하는 일은 색을 더하는 것이 아니라 **iOS 기본 회색의 푸른 기미를 빼는 것**이다.
/// ⚠️ **라이트와 다크가 같은 램프를 반대 방향에서 읽는다** — 바탕과 글자가 2 ↔ 12로 자리를
/// 맞바꾼다. 두 벌을 따로 관리하지 않는다.
enum Paper {
    static let step1 = Color(hex: 0xFFFFFF)
    static let step2 = Color(hex: 0xFBF8F3)
    static let step3 = Color(hex: 0xF2EDE4)
    static let step4 = Color(hex: 0xE6DFD3)
    static let step5 = Color(hex: 0xD3CBBC)
    static let step6 = Color(hex: 0xAFA89A)
    /// 라이트 `보조 글자`. `면` 위 4.5:1이 하한이고 이 값은 4.93이다.
    static let step7 = Color(hex: 0x6C655B)
    static let step8 = Color(hex: 0x57514A)
    static let step9 = Color(hex: 0x3E3A35)
    static let step10 = Color(hex: 0x2C2925)
    static let step11 = Color(hex: 0x201D1A)
    static let step12 = Color(hex: 0x141210)
    /// 램프 밖 고정 상수 — `06` 뷰어.
    static let black = Color(hex: 0x000000)
}

/// 시맨틱 색. **위계는 단조롭다** — 라이트에서는 진해질수록, 다크에서는 밝아질수록 활성.
enum Palette {
    static let background = mode(light: Paper.step2, dark: Paper.step12)
    /// 셀 배경 · 담는 칸 · 시트 안.
    static let surface = mode(light: Paper.step3, dark: Paper.step11)
    /// 사진 자리 · 스켈레톤 · 구분선 · 진행 트랙.
    static let placeholder = mode(light: Paper.step4, dark: Paper.step10)
    /// ⚠️ **쓰는 곳이 없다** — 연사 펼침 띠는 `05`에서 빠졌고(펼치기가 `06`으로 갔다) 선택
    /// 카드는 형광펜이 대신한다. 토큰 문서가 아직 자리를 갖고 있어 지우지 않았다.
    static let active = mode(light: Paper.step5, dark: Paper.step9)

    /// ⚠️ **`background`와 이름을 합치면 안 되는 자리다.** 라이트에서는 값이 같지만 다크에서는
    /// `background`·`surface`가 **뒤바뀐다** — 규칙은 「지면은 바깥보다 밝다」이고 두 모드에서 같다.
    static let pane = mode(light: Paper.step2, dark: Paper.step11)
    static let paneOutside = mode(light: Paper.step3, dark: Paper.step12)
    /// 실 제본. 다크에서 `active`를 쓰면 지면 위에서 안 읽혀 한 단 올렸다.
    static let binding = mode(light: Paper.step5, dark: Paper.step8)

    static let label = mode(light: Paper.step12, dark: Paper.step2)
    /// ⚠️ **한 단 어긋난다** — 다크에서 `종이-7`은 바탕 대비 3.25:1로 본문 기준에 못 미친다.
    static let secondaryLabel = mode(light: Paper.step7, dark: Paper.step6)
    static let disabled = mode(light: Paper.step6, dark: Paper.step8)

    /// 긴 텍스트 입력의 하단 선. ⚠️ **구분선(`placeholder`)과 값이 다르다** — 하는 일이
    /// *"여기서 나뉜다"* 가 아니라 *"여기에 쓴다"* 라 보여야 한다. 구분선 값은 다크에서 1.19:1이다.
    static let inputUnderline = mode(light: Paper.step5, dark: Paper.step8)

    /// 베일이 씌워진 사진은 그 기록에 없다.
    /// ⚠️ **`opacity`가 아니라 오버레이다** — `opacity`는 자식 배지까지 흐리게 만든다.
    static let veil = mode(light: Paper.step2.opacity(0.65), dark: Paper.step12.opacity(0.65))
    /// 베일 위 작은 칩. 글리프는 `background`.
    static let badgeSurface = mode(light: Paper.step12.opacity(0.75),
                                   dark: Paper.step2.opacity(0.85))
    /// `05-G2` 연사 배지의 바탕. ⚠️ **모드를 따르지 않는다** — 사진 위에 얹히므로 바탕이
    /// 지면이 아니라 사진이다. 글자는 `Paper.step1`.
    static let photoBadge = Paper.black.opacity(0.45)

    /// `04-C1` 형광펜. 앱이 **자기가 준 도구**로 자기 상태를 말한다 — 새 어휘가 0이다.
    /// ⚠️ 합성 모드가 모드마다 다르다(라이트 곱하기 · 다크 일반) — 그건 `Highlighter`가 안다.
    static let highlighter = mode(light: Color(hex: 0xB0552B).opacity(0.28),
                                  dark: Color(hex: 0xDD8455).opacity(0.38))

    /// 강조색 — 테라코타. 도구 활성 · 주요 액션 · 입력 캐럿.
    static let accent = mode(light: Color(hex: 0xB0552B), dark: Color(hex: 0xDD8455))
    /// 강조색 면 위의 글자.
    static let onAccent = mode(light: Paper.step1, dark: Paper.step12)

    /// `06` — 모드를 따르지 않는 고정 상수다.
    static let viewerBackground = Paper.black
}

/// 재질 — 떠 있는 크롬과 지면.
///
/// ⚠️ **떠 있는 것은 자기가 뜬 면보다 밝다.** 두 모드에서 같은 규칙이고, 라이트에서 정한
/// 매핑을 다크에 그대로 넣으면 크롬이 지면 아래로 가라앉는다.
enum Chrome {
    /// 툴바 · 도구 팔레트. 배경 블러 위에 얹는다.
    static let floating = mode(light: Paper.step2.opacity(0.9), dark: Paper.step10.opacity(0.9))
    static let floatingBorder = mode(light: Paper.step1, dark: Paper.step1.opacity(0.15))
    /// 네비 · 스티키 구분 헤더. 지면 위에 얹히므로 한 단만 올린다.
    static let header = mode(light: Paper.step2.opacity(0.9), dark: Paper.step11.opacity(0.9))

    /// 카드 없이 홀로 떠 있는 주요 액션의 유리 틴트. ⚠️ **글리프 색과 묶여 있다** —
    /// 올리면 같은 강조색 글리프가 원판에 섞인다(2026-08-12 실측: 0.5에서 탁해졌다).
    static let accentTint = Palette.accent.opacity(0.2)

    /// 떠 있는 것의 그림자. 색은 팔레트 밖이다 — 그림자는 색이 아니라 빛의 부재다.
    static let shadowColor = Color.black.opacity(0.2)
    static let shadowRadius: CGFloat = 16
    static let shadowOffset: CGFloat = 4
}

/// 타이포 7단 + 액센트.
///
/// ⚠️ **값이 시스템 서체 기준보다 한 단씩 작다** — 자면율이 0.951이라 같은 크기로 보이는
/// 값이다(Apple SD Gothic Neo 0.848 ÷ Plex 0.892). **서체를 바꾸면 이 표를 통째로 다시 잰다.**
enum Typography {
    static let title = plex(.bold, 32, relativeTo: .largeTitle)
    static let date = plex(.semiBold, 21, relativeTo: .title2)
    static let time = plex(.semiBold, 16, relativeTo: .headline)
    /// 네비 바 버튼도 겸한다. 16은 iOS 관례 17보다 작지만 Plex로 찍으면 같은 크기로 읽힌다.
    static let body = plex(.regular, 16, relativeTo: .body)
    static let subtitle = plex(.regular, 14, relativeTo: .subheadline)
    /// 목록을 끊는 구분 머리 — `10-B`. ⚠️ **`label`과 갈라 둔다** — 한때 둘이 한 토큰이었는데
    /// 버튼이 손글씨로 가면서 구분 머리까지 18로 끌려갔다(2026-08-13 pen 대조에서 잡았다).
    static let sectionLabel = plex(.semiBold, 14, relativeTo: .subheadline)
    /// 버튼 문구. **네비 평문 버튼도 겸한다** — 한 화면에 서체가 둘이 되지 않게.
    static let label = accent(18, relativeTo: .subheadline)
    static let note = plex(.regular, 12, relativeTo: .caption)

    /// 펼친 머리의 활자. 접히면 `time`으로 교차한다 — **크기를 보간하지 않는다.**
    static let headerLarge: CGFloat = 32

    /// 머리의 큰 타이틀. **액센트 서체가 서는 가장 큰 자리다.**
    static func accentTitle(_ size: CGFloat) -> Font {
        accent(size, relativeTo: .largeTitle)
    }

    /// `09-N2` 머리 — 날짜라 액센트가 아니라 UI 서체다(액센트는 숫자 폭이 안 맞는다).
    static func plexTitle(_ size: CGFloat) -> Font {
        plex(.bold, size, relativeTo: .largeTitle)
    }
    /// 빈 상태 — **아무것도 없는 화면에서 앱이 말을 거는 유일한 자리**라 액센트가 톤을 진다.
    static let emptyState = accent(21, relativeTo: .title2)
    /// 최상위 탭의 낱말. 두 탭 이름이 머리 타이틀과 같은 서체라 어휘가 안 는다.
    static let tabLabel = accent(18, relativeTo: .title2)

    // MARK: - 서체

    /// 번들 서체를 프로세스에 등록한다. **첫 렌더 전에 불러야 한다.**
    /// ⚠️ `GENERATE_INFOPLIST_FILE` 프로젝트라 `UIAppFonts` 자리가 없어 런타임 등록으로 간다.
    static func register() {
        for name in faceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// 시스템 네비 바가 쓰는 활자를 번들 서체로 바꾼다.
    ///
    /// ⚠️ **활자만 준다.** iOS 26의 유리 바는 `UINavigationBarAppearance`의 배경과 색을
    /// 무시하고, 배경색을 주면 large title을 통째로 안 그린다(2026-08-11 탐침으로 확정).
    /// 그래서 large title이 있는 화면은 머리를 직접 그리고, 여기 값은 inline 타이틀만 받는다.
    @MainActor
    static func applyNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let inline = UIFont(name: "IBMPlexSansKR-SemiBold", size: 16) {
            appearance.titleTextAttributes = [.font: inline]
        }
        // ⚠️ **네 자리를 모두 채운다** — 하나라도 비면 그 상태에서만 시스템 활자가 들어와
        // 스크롤 도중 서체가 바뀐다.
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
    }

    /// 번들에 실린 여섯 벌. 캔버스용 둘(`GowunBatang`)은 `11`이 쓴다.
    static let faceNames = [
        "IBMPlexSansKR-Regular", "IBMPlexSansKR-SemiBold", "IBMPlexSansKR-Bold",
        "PoorStory-Regular",
        "GowunBatang-Regular", "GowunBatang-Bold",
    ]

    enum Weight: String {
        case regular = "Regular"
        case semiBold = "SemiBold"
        case bold = "Bold"
    }

    private static func plex(_ weight: Weight, _ size: CGFloat,
                             relativeTo style: Font.TextStyle) -> Font {
        .custom("IBMPlexSansKR-\(weight.rawValue)", size: size, relativeTo: style)
    }

    /// ⚠️ **18 아래로 쓰지 않는다** — 푸어스토리의 세로획이 Plex보다 26% 얇아
    /// 작아질수록 급격히 흐려진다(실기기 판정 2026-08-07).
    private static func accent(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("PoorStory-Regular", size: size, relativeTo: style)
    }
}

/// 간격. **스케일로 승격하지 않는다** — 레이아웃 계산의 결과지 스케일이 아니다.
enum Spacing {
    /// 격자 셀 사이. ⚠️ **정사각 격자가 값을 정했다** — 벽돌쌓기는 4로도 됐는데 정사각은
    /// 타일이 딱 맞물려 더 필요했고, 갈라 두는 대신 손실 1pt를 물고 6으로 통일했다.
    static let cellGap: CGFloat = 6
    /// `04` 스트립. **묶음으로 읽혀야 하므로 붙어 있는 것이 목적이라** 위 값을 안 따라온다.
    static let thumbnailGap: CGFloat = 3
    static let expandedInset: CGFloat = 3
    static let momentGap: CGFloat = 8
    /// `07` 기록 카드 사이. ⚠️ **`momentGap`과 값이 달라 묶지 않는다** — 카드가 크고 하나가
    /// 한 기록 전체라 순간 카드보다 더 떨어져야 덩어리로 읽힌다.
    static let recordGap: CGFloat = 12
    /// 우측 여백 전부. `04`는 좌우 둘 다 쓴다.
    static let screenMargin: CGFloat = 16
    /// **좌측(제본 쪽) 여백 — iPhone 한정.** 제본이 왼쪽에만 있어 대칭으로 두면 거기서만
    /// 사진과 부딪힌다. 일기장에서도 안쪽 여백이 바깥보다 넓다.
    static let bindingMargin: CGFloat = 20
    /// ⚠️ **`04`만 좌 17이다** — `118×3 + 3×2 = 360`이라 총 여백 33이 천장이고,
    /// 20/16(=36)이면 스트립이 3장/행에서 2장/행으로 깨진다.
    static let listLeading: CGFloat = 17
    static let dayGap: CGFloat = 32
    /// iPad 지면 바깥 여백이자 지면 사이 간격.
    static let paneGap: CGFloat = 12
    /// 카드 자기 패딩 — 선택 배경이 들어갈 자리.
    static let cardInset: CGFloat = 6
}

/// 반경. **격자 안의 타일인가, 몰입 층위인가**를 말한다. 동심으로 겹친다 — 카드 12 > 버튼 8 > 타일 6.
///
/// ★ 반경이 간격을 대신 벌어준다 — 모서리의 실효 여백이 `간격 + 반경 × 2`가 된다.
enum Radius {
    static let thumbnail: CGFloat = 6
    static let badge: CGFloat = 4
    static let button: CGFloat = 8
    static let card: CGFloat = 12
    /// iPad 2단의 지면. **두 장의 종이가 나란히 놓인다** — 분할선이 아니라 여백이 가른다.
    static let pane: CGFloat = 22
}

/// 번들 아이콘 이름. **관례가 강한 개념만 아이콘으로 말한다** — 약한 것은 글자가 진다.
///
/// ⚠️ **시스템 심볼이 아니라 `App/Design/Icons`의 lucide 벡터다.** 새 글리프도 거기서 찾는다 —
/// 없다고 SF Symbol을 섞으면 한 캡슐 안에 두 계열이 산다(README에 근거).
enum Glyph {
    static let back = "chevron-left"
    static let more = "ellipsis"
    static let settings = "settings"
    static let add = "plus"
    static let close = "x"
    /// `05-G2` 연사 배지. 숫자가 옆에 서므로 아이콘 혼자 뜻을 다 지지 않는다.
    static let burst = "copy"
    static let createRecord = "pen-line"
    /// `09-T` iPhone. 만들기가 펜이면 확정은 체크고, `확정`이 쓰는 개념과 같아 어휘가 안 는다.
    static let save = "check"
}

// MARK: - 조각

/// 모드마다 다른 값을 하나로 묶는다.
private func mode(light: Color, dark: Color) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(traits.userInterfaceStyle == .dark ? dark : light)
    })
}

private extension Color {
    /// `0xRRGGBB`.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
