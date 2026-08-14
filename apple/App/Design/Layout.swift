// 확정된 치수. **디자인 토큰이 아니다** — 출처가 화면설계서·pen·실측이고, 낡는 조건도
// 다르다(토큰은 토큰 문서가 개정될 때, 여기는 화면이 다시 확정되거나 재측정할 때).
//
// 갱신 방아쇠가 다른 값을 한 집에 두면 어느 쪽이 움직였는지가 안 보인다. `Tokens.swift`가
// *"여기서 값을 발명하지 않는다"* 를 지킬 수 있는 것도 이 파일이 갈라져 있기 때문이다.

import CoreGraphics

/// 레이아웃 상수와 그 파생값.
enum Layout {
    /// 탭 대상 한 변의 하한. 플랫폼 규칙이라 화면이 정하지 않는다.
    static let hitTarget: CGFloat = 44

    /// 크롬 아이콘 한 변. 44 탭 대상 안에 놓이는 그림의 크기다.
    static let glyph: CGFloat = 20

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

    /// `05` 벽돌쌓기의 열 수. 넓어져도 열이 아니라 셀이 커진다 — 사진 한 장인 순간만 한 열이다.
    static let detailColumns = 2
    /// 화소 크기를 모르는 자산의 셀 비율. 이 앨범 대다수의 모양이다.
    static let detailCellAspect: CGFloat = 4.0 / 3.0

    /// 본문 폭의 상한. 값은 iPad 2단의 상세 지면 폭이다.
    /// ⚠️ **안 걸면 넓은 지면에서 머리·툴바·밑줄이 전부 화면 끝까지 늘어난다**(2026-08-11 실측).
    static let readableWidth: CGFloat = 750

    /// `09` 사진 격자의 열 수 — 폭이 정한다.
    /// ⚠️ 2를 박으면 넓은 지면에서 타일 하나가 화면 절반이 된다(2026-08-11 실측).
    static func editorColumns(inWidth width: CGFloat) -> Int {
        max(2, Int(width / 380))
    }

    /// `10` 사진 더하기의 열 수. 후보를 **훑는** 화면이라 타일이 `04` 썸네일 층위로 작다.
    static func pickerColumns(inWidth width: CGFloat) -> Int {
        max(3, Int(width / 130))
    }
    /// 떠 있는 툴바·도구 팔레트·탭 바의 높이. **셋이 한 값을 쓴다** — 같은 화면에 나란히
    /// 서는 자리가 있어 몇 pt만 어긋나도 그대로 보인다(2026-08-13 실기기).
    static let floatingBarHeight: CGFloat = 50
    /// 그 툴바의 폭 상한. ⚠️ **본문 폭을 그대로 쓰면 안 된다** — 넓은 지면에서 세 버튼이
    /// 양 끝으로 벌어져 한 묶음으로 안 읽힌다. iPhone 본문(357)보다 커서 거기서는 안 걸린다.
    static let floatingBarMaxWidth: CGFloat = 420
    /// `04` 머리를 펼쳤을 때의 높이 — 위 14 + 줄 44 + 사이 2 + 요약 21 + 아래 10.
    static let listHeaderHeight: CGFloat = 91
    /// `05`·`09` 머리 — 위 12 + 버튼 줄 44 + 사이 2 + 큰 타이틀 48 + 사이 2 + 부제 21 + 아래 10.
    /// **두 화면의 머리가 같은 구조다** — 줄 하나, 큰 타이틀, 부제.
    static let largeTitleHeaderHeight: CGFloat = 139
    /// `07-C4` 대표 이미지의 종횡비. **훑는 화면이라 자른다** — 세로 사진(0.461)을 원본
    /// 비율로 두면 카드 하나가 781pt가 되어 화면을 넘는다.
    static let recordCoverAspect: CGFloat = 4.0 / 3.0

    /// `08-G1` 사진 한 장의 높이 상한. **자르지 않는 대신 이 값에서 멈춘다** — 세로 사진이
    /// 본문 폭 357에서 774가 되어 한 화면(가용 ≈750)을 넘는다.
    static let recordPhotoMaxHeight: CGFloat = 480

    /// 사진 위에 얹히는 원형 배지.
    static let badgeDiameter: CGFloat = 22
    /// `05-T` 우하단에 뜨는 원형 액션.
    static let floatingActionDiameter: CGFloat = 56

    // MARK: - 화소 상한

    /// 썸네일 층위의 칸. 위 `thumbnail`의 3배.
    static let thumbnailPixels = 354
    /// 격자 셀. iPad 4열의 셀 폭(194pt)이 상한이라 그 3배.
    static let gridPixels = 600
    /// `06`. 표본 원본이 1680×1167이라(2026-08-03) 그 위로는 늘려봐야 소용이 없다.
    static let fullPixels = 2400
    /// `07-C4`. 카드 폭 전체라 썸네일보다 훨씬 크다.
    static let recordCoverPixels = 1200
    /// `08-G1`. 위 `recordPhotoMaxHeight`의 3배.
    static let recordPhotoPixels = 1440
}
