// 확정된 치수. **`Tokens.swift`와 갈라 둔다** — 갱신 방아쇠가 다르다(토큰은 값이 개정될 때,
// 여기는 화면이 다시 확정되거나 재측정할 때).

import SwiftUI

/// 레이아웃 상수와 그 파생값.
enum Layout {
    /// 탭 대상 한 변의 하한. 플랫폼 규칙이다.
    static let hitTarget: CGFloat = 44

    /// 제본 쪽 여백. **iPad 2단에는 제본이 없어 대칭이다.**
    static func leadingMargin(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? Spacing.bindingMargin : Spacing.screenMargin
    }

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
    /// 떠 있는 툴바와 탭 바의 높이. **둘이 한 값을 쓴다** — 같은 화면에 나란히 서는 자리가
    /// 있어 몇 pt만 어긋나도 그대로 보인다(2026-08-13 실기기).
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

    // MARK: - `01` 온보딩

    /// 주요 액션 버튼의 폭 상한 — **iPhone에서 여백을 뺀 폭이 그대로 상한이다.**
    /// 넓은 지면에서는 여기서 멈춰 가운데 선다.
    static let actionButtonMaxWidth: CGFloat = 360
    /// 머리글 한 줄이 차지하는 높이. 손글씨 36의 1.45배다.
    static let onboardingLineHeight: CGFloat = 52
    /// 첫 덩어리가 시작하는 자리. iPad는 지면 안이라 값이 다르다.
    static let onboardingTopInset: CGFloat = 150
    static let onboardingPadTopInset: CGFloat = 110
    /// iPad 지면 안쪽 좌우 여백.
    static let onboardingPadMargin: CGFloat = 44
    /// `01-S` 견본 카드의 폭 상한. iPhone에서는 본문 폭이 이보다 좁아 안 걸린다.
    static let sampleCardMaxWidth: CGFloat = 480

    // MARK: - `02` 소스 지정

    /// 타일 하나가 셀간격까지 먹는 폭. **타일 크기가 고정이고 칸 수가 폭을 따라간다** —
    /// iPhone은 사진 2 + `+N`, iPad는 5 + `+N`이 된다.
    static let sourceTileSpan: CGFloat = 120
    /// 스트립의 칸 수 하한. 사진 둘과 `+N`.
    static let sourceStripMinimum = 3
    static func sourceCells(inWidth width: CGFloat) -> Int {
        max(sourceStripMinimum, Int((width + Spacing.cellGap) / sourceTileSpan))
    }

    /// 후보 사이. **행 안(6)보다 훨씬 넓다** — 어느 스트립이 어느 이름의 것인지가 여기서 갈린다.
    static let sourceRowGap: CGFloat = 20
    /// iPhone 시트 높이. **갈래마다 담을 것이 달라 높이도 다르다** — 목록 · 한 줄 · 안내뿐.
    /// 목록 판만 스크롤한다.
    static func sourceSheetHeight(hasList: Bool, hasCandidates: Bool) -> CGFloat {
        guard hasList else { return 430 }
        return hasCandidates ? 646 : 520
    }
    /// iPad는 창 가운데 떠 있는 판이다. ⚠️ **`13`(시스템 폼 540)보다 넓다.**
    static let sourcePadSheet = CGSize(width: 750, height: 560)
    /// 후보마다 들고 올 사진 수. 가장 넓은 판(iPad 6칸)이 다섯을 그린다.
    static let sourcePreviewLimit = 6

    /// 사진 위에 얹히는 원형 배지.
    static let badgeDiameter: CGFloat = 22
    /// `05-T` 우하단에 뜨는 원형 액션.
    static let floatingActionDiameter: CGFloat = 56

    // MARK: - `11` 캔버스

    /// 캔버스 지면. **4:3이고 이 값이 좌표계다** — 요소의 자리도 저장된 값도 여기 기준이라
    /// 창 크기가 달라져도 문서가 안 흔들린다.
    static let canvasSize = CGSize(width: 920, height: 690)
    /// `11-N` 상단바. 떠 있는 바(50)와 값이 다르다 — 이쪽은 화면에 붙은 바다.
    static let canvasTopBar: CGFloat = 52
    /// `11-T` 도구 팔레트의 높이. ⚠️ **떠 있는 바(50)와 다른 값이다** — `11`에는 나란히 설
    /// 탭 바가 없고, 여기는 44 탭 대상 위아래로 8씩을 준 값이다.
    static let canvasPaletteHeight: CGFloat = 56
    /// `11-P` 페이지 레일의 폭과 그 안 썸네일 한 변.
    static let canvasRailWidth: CGFloat = 88
    static let canvasThumbnailWidth: CGFloat = 72

    /// 승격 직후 놓이는 첫 사진. 캔버스 폭의 57%이고, 아래로 230을 비워 글 자리를 남긴다.
    static let canvasEntryPhotoSize = CGSize(width: 520, height: 361)
    static var canvasEntryPhotoCenter: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: 96 + canvasEntryPhotoSize.height / 2)
    }

    /// `CAN-03` 드롭·붙여넣기로 들어온 이미지가 처음 차지하는 상자. **승격 사진보다 작다** —
    /// 스티커로 얹는 자리라 지면을 덮으면 안 된다.
    static let canvasDropSize = CGSize(width: 300, height: 300)

    /// 두 손가락 핀치의 범위. 100%가 캔버스를 화면에 맞춘 배율이다.
    static let canvasZoomRange: ClosedRange<CGFloat> = 0.5...4

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
