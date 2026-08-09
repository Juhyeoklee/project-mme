// 디자인 토큰 — 토큰 문서의 번역이지 설계가 아니다. **여기서 값을 발명하지 않는다.**
// 이름은 크기가 아니라 역할이라, 값이 바뀌어도 이 파일의 이름들은 산다.
//
// ⚠️ 값은 `M1` 판이고 토큰 문서는 `M2` 앞에서 재작성됐다. **재도색은 `M2` 구현 세션 2 몫이다.**

import SwiftUI

/// 회색 4단 + 상수 1. 글자 회색은 팔레트 밖 — `label`/`secondaryLabel`에 위임한다.
enum Palette {
    static let background = Color(uiColor: .systemBackground)
    /// 셀 배경 — fit하고 남긴 여백.
    static let surface = Color(uiColor: .systemGray6)
    /// 사진 자리 · 스켈레톤. "콘텐츠가 아직 없다"는 한 가지 뜻이라 둘을 합쳤다.
    static let placeholder = Color(uiColor: .systemGray5)
    /// 펼침 띠 · 선택 카드. **첫 조정 레버가 여기다** — 안 읽히면 `.systemGray3`으로 한 단.
    static let active = Color(uiColor: .systemGray4)
    /// `06` 배경. 모드를 따르지 않는 고정 상수다 — 사진 뷰어 관례.
    static let viewerBackground = Color.black
}

/// 타이포 4단. 텍스트 스타일에 얹었으므로 동적 타입이 공짜로 따라온다.
enum Typography {
    static let title = Font.largeTitle
    /// semibold로 올린 것은 스티키 헤더가 카드 시각과 겹쳐 흐를 때
    /// 크기 차(22↔17)만으로는 훑기에서 한 박자 늦기 때문이다.
    static let date = Font.title2.weight(.semibold)
    static let time = Font.headline
    static let caption = Font.subheadline
}

/// 간격 실측 6개. **스케일로 승격하지 않는다** — 레이아웃 계산의 결과지 스케일이 아니다.
enum Spacing {
    static let cellGap: CGFloat = 2
    /// `expandedInset`과 값이 같은 것은 우연이라 토큰을 나눈다.
    static let thumbnailGap: CGFloat = 3
    static let expandedInset: CGFloat = 3
    static let momentGap: CGFloat = 8
    static let screenMargin: CGFloat = 16
    static let dayGap: CGFloat = 32
}

/// 반경. 층위 따라 줄어든다 — 훑기만 둥글고 보기부터는 **명시적 직각**이라 토큰 없이 0을 쓴다.
enum Radius {
    static let thumbnail: CGFloat = 6
    static let badge: CGFloat = 4
}

/// 확정된 레이아웃 상수. 토큰 문서 밖이지만 값이 확정돼 있어 여기 모은다.
enum Layout {
    /// `04-C3` 썸네일 한 변. 정사각 중앙 크롭.
    static let thumbnail: CGFloat = 118
    /// **규칙은 행이지 장수가 아니다** — 행으로 써두면 폭이 장수를 정한다.
    static let stripRows = 2

    /// **상수로 박으면 안 되는 값이다** — `3장`은 특정 폭의 결과지 전제가 아니고,
    /// iPad 세로(252pt)에서는 3장이 안 들어간다(2026-08-04 실기기).
    static func thumbnailsPerRow(inWidth width: CGFloat) -> Int {
        max(1, Int((width + Spacing.thumbnailGap) / (thumbnail + Spacing.thumbnailGap)))
    }

    /// 이보다 장면이 많으면 마지막 칸이 `+N`이 된다.
    static func stripCapacity(inWidth width: CGFloat) -> Int {
        thumbnailsPerRow(inWidth: width) * stripRows
    }

    /// 34%가 iPhone과 같은 3장/행을 만든다.
    static let listPaneFraction: CGFloat = 0.34

    /// 접힌 장면 수가 이보다 적으면 열 수를 장면 수에 맞춘다.
    static let detailColumnsCompact = 3
    static let detailColumnsRegular = 4
    /// 정사각이 아닌 이유는 대다수인 가로 사진에 여백을 덜 물리기 때문이다.
    static let detailCellAspect: CGFloat = 4.0 / 3.0
}
