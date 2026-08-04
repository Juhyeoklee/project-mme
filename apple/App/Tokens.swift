// 디자인 토큰 — `docs/design-tokens.md`(확정)를 그대로 옮긴 것이다. **여기서 값을 발명하지 않는다.**
//
// 토큰 문서가 어휘와 값까지 정했고 영문 네이밍만 이 세션 몫이라, 이 파일은 번역이지 설계가 아니다.
// 값이 실물에서 어색하면 고칠 곳은 여기가 아니라 그 문서다 — 이름은 크기가 아니라 역할이라
// (토큰 문서 원칙 3) 값이 바뀌어도 이 파일의 이름들은 그대로 산다.

import SwiftUI

/// 회색 4단 + 상수 1 (토큰 §2). 글자 회색은 팔레트 밖 — `label`/`secondaryLabel`에 위임한다.
enum Palette {
    /// 화면 배경.
    static let background = Color(uiColor: .systemBackground)
    /// 셀 배경 — `05-G1`이 fit하고 남긴 여백.
    static let surface = Color(uiColor: .systemGray6)
    /// 사진 자리 · 스켈레톤 (`04-D`). "콘텐츠가 아직 없다"는 한 가지 뜻이라 둘을 합쳤다.
    static let placeholder = Color(uiColor: .systemGray5)
    /// 활성 — 펼침 띠 (`05-G3`) · 선택 카드 (`04-C` iPad).
    /// **첫 조정 레버가 여기다** — 3pt 띠가 안 읽히면 `.systemGray3`으로 한 단 내린다 (토큰 §2).
    static let active = Color(uiColor: .systemGray4)
    /// `06` 배경. 모드를 따르지 않는 고정 상수다 — 사진 뷰어 관례.
    static let viewerBackground = Color.black
}

/// 타이포 4단 (토큰 §3). 텍스트 스타일에 얹었으므로 동적 타입이 공짜로 따라온다.
enum Typography {
    /// `04-N1`. large title → inline 축소는 시스템 동작이라 코드에 없다.
    static let title = Font.largeTitle
    /// `04-B1`. semibold로 올린 것은 스티키 헤더가 카드 시각과 겹쳐 흐를 때
    /// 크기 차(22↔17)만으로는 훑기에서 한 박자 늦기 때문이다.
    static let date = Font.title2.weight(.semibold)
    /// `04-C1` · `05-N2` · `06-N2` · `+N`(`04-C4`).
    static let time = Font.headline
    /// `04-N2` · `04-B2` `04-C2` · `05-N3` · `06-N3` · `04-E1`.
    static let caption = Font.subheadline
}

/// 간격 실측 6개 (토큰 §4). **스케일로 승격하지 않는다** — 레이아웃 계산의 결과지 스케일이 아니다.
enum Spacing {
    /// `05` 그리드 셀 사이.
    static let cellGap: CGFloat = 2
    /// `04` 스트립. 아래 `expandedInset`과 값이 같지만 우연이라 토큰을 나눈다.
    static let thumbnailGap: CGFloat = 3
    /// `05-G3` 펼친 셀의 사진 인셋.
    static let expandedInset: CGFloat = 3
    /// `04` 카드 사이.
    static let momentGap: CGFloat = 8
    /// `04` 좌우.
    static let screenMargin: CGFloat = 16
    /// `04` 날짜 그룹 사이. §5 항목 3의 검증 대상 — 값이 바뀌어도 이름은 유지된다.
    static let dayGap: CGFloat = 32
}

/// 반경 (토큰 §5). 층위 따라 줄어든다 — 훑기(`04`)만 둥글고 보기(`05`)부터는 0.
enum Radius {
    static let thumbnail: CGFloat = 6
    static let badge: CGFloat = 4
    /// `05-G1`은 **명시적 직각**이다. 토큰 없이 0을 쓴다.
}

/// 화면설계서 §1.2가 확정한 레이아웃 상수. 토큰 문서 밖이지만 값이 확정돼 있어 여기 모은다.
enum Layout {
    /// `04-C3` 썸네일 한 변. 정사각 중앙 크롭.
    static let thumbnail: CGFloat = 118
    /// 스트립 최대 행 수. **규칙은 행이지 장수가 아니다** (화면설계서 §2.3) —
    /// *"행으로 써두면 폭이 장수를 정하고, 목록 폭을 바꿔도 규칙이 안 깨진다."*
    static let stripRows = 2

    /// 주어진 폭에 들어가는 썸네일 수. **상수로 박으면 안 되는 값이다.**
    ///
    /// 확정 표(§1.2)의 `3장`은 iPhone 361pt와 iPad **가로** pane 374pt에서 나온 결과지 전제가 아니다.
    /// iPad **세로**에서는 같은 34%가 252pt가 되어 3장이 안 들어간다 — 상수로 두면 셋째 칸이
    /// 그대로 잘려 나간다(2026-08-04 실기기에서 그렇게 나왔다).
    static func thumbnailsPerRow(inWidth width: CGFloat) -> Int {
        max(1, Int((width + Spacing.thumbnailGap) / (thumbnail + Spacing.thumbnailGap)))
    }

    /// 스트립이 담는 칸 수. 이보다 장면이 많으면 마지막 칸이 `+N`이 된다.
    static func stripCapacity(inWidth width: CGFloat) -> Int {
        thumbnailsPerRow(inWidth: width) * stripRows
    }

    /// iPad 2단의 목록 pane 비율. 34%가 iPhone과 같은 3장/행을 만든다 (화면설계서 §1.2).
    static let listPaneFraction: CGFloat = 0.34

    /// `05` 최대 열 수. 접힌 장면 수가 이보다 적으면 열 수를 장면 수에 맞춘다.
    static let detailColumnsCompact = 3
    static let detailColumnsRegular = 4
    /// `05-G1` 셀 비율. 정사각이 아닌 이유는 대다수인 가로 사진에 여백을 덜 물리기 때문이다.
    static let detailCellAspect: CGFloat = 4.0 / 3.0
}
