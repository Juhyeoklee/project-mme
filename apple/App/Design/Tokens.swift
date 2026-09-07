// 디자인 토큰. **여기서 값을 발명하지 않는다** — 이름은 크기가 아니라 역할이고,
// 치수는 `Layout.swift`가 따로 든다. 왜 이 값인가는 토큰 문서가 진다.

import CoreText
import SwiftUI

/// 원시값 — 「종이」 램프 12단.
enum Paper {
    static let step1 = Color(hex: 0xFFFFFF)
    static let step2 = Color(hex: 0xFBF8F3)
    static let step3 = Color(hex: 0xF2EDE4)
    static let step4 = Color(hex: 0xE6DFD3)
    static let step5 = Color(hex: 0xD3CBBC)
    static let step6 = Color(hex: 0xAFA89A)
    static let step7 = Color(hex: 0x6C655B)
    static let step8 = Color(hex: 0x57514A)
    static let step9 = Color(hex: 0x3E3A35)
    static let step10 = Color(hex: 0x2C2925)
    static let step11 = Color(hex: 0x201D1A)
    static let step12 = Color(hex: 0x141210)
}

/// 시맨틱 색. **전부 `Color.mode`다** — 모드를 안 따르는 것도 문법이 아니라
/// **두 슬롯의 같은 값**으로 말한다. 은행잎(`AccentSet`)과 같다.
/// ⚠️ **값이 같은 이름을 합치지 마라** — 하는 일이 다르면 값이 갈리는 날이 온다.
enum Palette {
    static let background = Color.mode(light: Paper.step2, dark: Paper.step12)
    static let surface = Color.mode(light: Paper.step3, dark: Paper.step10)
    static let placeholder = Color.mode(light: Paper.step4, dark: Paper.step10)
    static let active = Color.mode(light: Paper.step5, dark: Paper.step9)

    static let pane = Color.mode(light: Paper.step2, dark: Paper.step11)
    /// ⚠️ **`pane`과 값이 같아도 합치지 마라** — 하는 일이 다르다.
    static let cardSurface = Color.mode(light: Paper.step2, dark: Paper.step10)
    /// ⚠️ **`surface`와 합치지 마라** — 다크에서 `cardSurface`와 값이 같아 통째로 사라진다.
    static let innerSurface = Color.mode(light: Paper.step3, dark: Paper.step9)
    static let paneOutside = Color.mode(light: Paper.step3, dark: Paper.step12)
    /// ⚠️ **`surface`와 값이 같아도 합치지 마라** — 하는 일이 다르다.
    static let listSurface = Color.mode(light: Paper.step3, dark: Paper.step10)

    static let binding = Color.mode(light: Paper.step5, dark: Paper.step8)

    static let label = Color.mode(light: Paper.step12, dark: Paper.step2)
    static let secondaryLabel = Color.mode(light: Paper.step7, dark: Paper.step6)
    static let disabled = Color.mode(light: Paper.step6, dark: Paper.step8)

    /// ⚠️ **`binding`과 값이 같아도 합치지 마라** — 하는 일이 다르다.
    static let inputUnderline = Color.mode(light: Paper.step5, dark: Paper.step8)

    /// ⚠️ **`opacity`가 아니라 오버레이로 얹는다** — `opacity`는 자식 배지까지 흐리게 만든다.
    static let veil = Color.mode(light: Paper.step2.opacity(0.65), dark: Paper.step12.opacity(0.65))
    static let badgeSurface = Color.mode(light: Paper.step12.opacity(0.75),
                                   dark: Paper.step2.opacity(0.85))
    static let photoBadge = Color.mode(light: Color(hex: 0x000000).opacity(0.45),
                                 dark: Color(hex: 0x000000).opacity(0.45))
    static let onPhotoBadge = Color.mode(light: Paper.step1, dark: Paper.step1)

    static let onAccent = Color.mode(light: Paper.step1, dark: Paper.step12)

    static let calloutSurface = Color.mode(light: Paper.step11, dark: Paper.step2)
    /// ⚠️ **`pane`과 값이 같아도 합치지 마라** — 하는 일이 다르다.
    static let onCallout = Color.mode(light: Paper.step2, dark: Paper.step11)

    static let viewerBackground = Color.mode(light: Color(hex: 0x000000), dark: Color(hex: 0x000000))
    static let onViewer = Color.mode(light: Paper.step2, dark: Paper.step2)

    /// ⚠️ **`onPhotoBadge`와 값이 같아도 합치지 마라** — 하는 일이 다르다.
    static let selectionEdge = Color.mode(light: Paper.step1, dark: Paper.step1)
}

/// 재질 — 떠 있는 크롬과 지면.
enum Chrome {
    static let floating = Color.mode(light: Paper.step2.opacity(0.9), dark: Paper.step10.opacity(0.9))
    static let floatingBorder = Color.mode(light: Paper.step1, dark: Paper.step1.opacity(0.15))
    static let header = Color.mode(light: Paper.step2.opacity(0.9), dark: Paper.step11.opacity(0.9))

    static let shadowColor = Color.mode(light: Color.black.opacity(0.2), dark: Color.black.opacity(0.2))
    static let shadowRadius: CGFloat = 16
    static let shadowOffset: CGFloat = 4

    /// ⚠️ **`shadowColor`·`cardShadowColor`와 합치지 마라** — 셋이 서로 다른 깊이다.
    /// ⚠️ **다크가 훨씬 진하다** — 창 바탕이 거의 검어서 라이트 값을 그대로 쓰면 안 보인다.
    static let paneShadowColor = Color.mode(light: Color.black.opacity(0.12),
                                            dark: Color.black.opacity(0.6))
    static let paneShadowRadius: CGFloat = 24
    static let paneShadowOffset: CGFloat = 6

    /// ⚠️ **종이 그림자와 합치지 마라** — 얕고 따뜻하다.
    static let cardShadowColor = Color.mode(light: Color(hex: 0x3A322A).opacity(0.1),
                                            dark: Color(hex: 0x3A322A).opacity(0.1))
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowOffset: CGFloat = 3
}

/// 타이포 7단 + 액센트.
enum Typography {
    static let title = plex(.bold, 32, relativeTo: .largeTitle)
    static let date = plex(.semiBold, 21, relativeTo: .title2)
    static let time = plex(.semiBold, 16, relativeTo: .headline)
    static let body = plex(.regular, 16, relativeTo: .body)
    static let subtitle = plex(.regular, 14, relativeTo: .subheadline)
    /// ⚠️ **`label`과 합치지 마라** — 합치면 버튼 서체가 구분 머리까지 온다.
    static let sectionLabel = plex(.semiBold, 14, relativeTo: .subheadline)
    static let label = accent(18, relativeTo: .subheadline)
    static let note = plex(.regular, 12, relativeTo: .caption)

    static let headerLarge: CGFloat = 32
    /// ⚠️ **`headerLarge`와 합치지 마라** — 값이 가까워도 하는 일이 다르다.
    static let onboardingHeadline: CGFloat = 36

    static func accentTitle(_ size: CGFloat) -> Font {
        accent(size, relativeTo: .largeTitle)
    }

    static func plexTitle(_ size: CGFloat) -> Font {
        plex(.bold, size, relativeTo: .largeTitle)
    }
    static let emptyState = accent(21, relativeTo: .title2)
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

    /// 시스템 네비 바가 쓰는 활자를 번들 서체로 바꾼다. **활자만 준다.**
    @MainActor
    static func applyNavigationBar() {
        #if os(iOS)
        // ⚠️ iOS 26 유리 바는 배경과 색을 무시하고, 배경색을 주면 large title을 통째로 안
        // 그린다(2026-08-11 탐침). large title 화면은 머리를 직접 그리고 여기는 inline만 받는다.
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
        #endif
    }

    /// `11` 캔버스 활자의 서체 이름. ⚠️ 손글씨는 굵기가 1단이라 `bold`가 아무 일도 안 한다.
    static func canvasFace(_ face: CanvasText.Face, bold: Bool) -> String {
        switch face {
        case .handwriting: "PoorStory-Regular"
        case .serif: bold ? "GowunBatang-Bold" : "GowunBatang-Regular"
        }
    }

    /// `11-I1` 글꼴 칸의 활자.
    static func canvasSegment(_ face: CanvasText.Face) -> Font {
        switch face {
        case .handwriting: .custom(canvasFace(.handwriting, bold: false), size: 18)
        case .serif: .custom(canvasFace(.serif, bold: false), size: 15)
        }
    }

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

    /// 하한 18.
    private static func accent(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("PoorStory-Regular", size: size, relativeTo: style)
    }
}

/// 간격. **스케일로 승격하지 않는다** — 레이아웃 계산의 결과지 스케일이 아니다.
enum Spacing {
    static let cellGap: CGFloat = 6
    static let thumbnailGap: CGFloat = 3
    static let expandedInset: CGFloat = 3
    static let momentGap: CGFloat = 8
    static let recordGap: CGFloat = 12
    static let screenMargin: CGFloat = 16
    static let bindingMargin: CGFloat = 20
    static let listLeading: CGFloat = 17
    static let dayGap: CGFloat = 32
    static let paneGap: CGFloat = 12
    static let cardInset: CGFloat = 6
}

/// 반경.
enum Radius {
    static let thumbnail: CGFloat = 6
    static let badge: CGFloat = 4
    static let button: CGFloat = 8
    static let card: CGFloat = 12
    static let pane: CGFloat = 22
    static let canvas: CGFloat = 2
}

/// 번들 아이콘 이름.
/// ⚠️ **시스템 심볼이 아니라 `App/Design/Icons`의 lucide 벡터다.** 없다고 SF Symbol을 섞지 마라.
enum Glyph {
    static let back = "chevron-left"
    static let more = "ellipsis"
    static let settings = "settings"
    static let add = "plus"
    static let subtract = "minus"
    static let close = "x"
    static let burst = "copy"
    static let createRecord = "pen-line"
    static let save = "check"
    /// ⚠️ **`save`와 같은 자산이어도 합치지 마라** — 하는 일이 다르다.
    static let selected = "check"

    // MARK: - `11` 캔버스

    static let pointer = "mouse-pointer-2"
    static let marker = "highlighter"
    static let eraser = "eraser"
    static let text = "type"
    static let image = "image"
    static let notebook = "notebook"
    static let undo = "undo-2"
    static let redo = "redo-2"
    static let bringToFront = "bring-to-front"
    static let sendToBack = "send-to-back"
    static let delete = "trash-2"
}

// MARK: - 조각

extension Color {
    /// 모드마다 다른 값을 하나로 묶는다. 모드를 안 따르는 값은 같은 것을 두 번 넣는다.
    static func mode(light: Color, dark: Color) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
        #endif
    }

    /// `0xRRGGBB`.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
