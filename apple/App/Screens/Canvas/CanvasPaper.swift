// 캔버스 종이와 잉크 — `11`만 쓰는 값과 그 값을 그리는 법.
//
// ⚠️ **앱 팔레트가 아니다.** 여기 색은 사용자가 고르는 재료라 모드를 따르지 않는다 —
// 종이는 다크에서도 종이여야 한다.

#if os(iOS)
import SwiftUI

/// 종이 색 6종의 값과 이름.
extension PaperColor {
    var color: Color {
        switch self {
        case .white: Color(hex: 0xFFFFFF)
        case .ivory: Color(hex: 0xF7EEDA)
        case .gray: Color(hex: 0xEBEAE6)
        case .navy: Color(hex: 0xE9EBF0)
        case .olive: Color(hex: 0xEBECE3)
        case .rose: Color(hex: 0xF0E9EC)
        }
    }

    var name: String {
        switch self {
        case .white: "흰색"
        case .ivory: "아이보리"
        case .gray: "연회색"
        case .navy: "먹빛남색"
        case .olive: "이끼 올리브"
        case .rose: "장미"
        }
    }
}

/// 종이 무늬 4종의 간격과 이름.
///
/// ⚠️ **무늬는 절차적으로 그린다.** 비트맵 타일을 깔면 확대(`CAN-02`)와 이미지 굽기
/// (`CAN-09`)에서 깨진다.
extension PaperPattern {
    /// 민무늬는 0이다.
    var spacing: CGFloat {
        switch self {
        case .plain: 0
        case .grid: 24
        case .dots: 22
        case .lines: 28
        }
    }

    /// 점의 지름. 나머지 무늬는 1pt 선이라 값이 없다.
    static let dotDiameter: CGFloat = 2.4

    var name: String {
        switch self {
        case .plain: "민무늬"
        case .grid: "모눈"
        case .dots: "점"
        case .lines: "줄"
        }
    }
}

extension PaperStyle {
    /// 무늬 색 — 뉴트럴 램프의 `종이-7`을 알파로 깐 것이다. 새 색을 만들지 않았다.
    ///
    /// ⚠️ **알파를 하나로 통일하지 마라** — 무늬마다 덮는 넓이가, 색마다 밝기가 달라
    /// 같은 알파가 어떤 조합에서는 안 보이고 어떤 조합에서는 격자로 튄다.
    var patternColor: Color { Paper.step7.opacity(patternAlpha) }

    private var patternAlpha: Double {
        switch pattern {
        case .plain: 0
        case .grid:
            switch color {
            case .white: 0.079
            case .ivory: 0.084
            case .gray: 0.090
            case .navy: 0.086
            case .olive: 0.091
            case .rose: 0.088
            }
        case .dots:
            switch color {
            case .white: 0.138
            case .ivory: 0.150
            case .gray: 0.155
            case .navy: 0.153
            case .olive: 0.159
            case .rose: 0.156
            }
        case .lines:
            switch color {
            case .white: 0.086
            case .ivory: 0.092
            case .gray: 0.098
            case .navy: 0.094
            case .olive: 0.099
            case .rose: 0.095
            }
        }
    }

    /// 두 축을 한 줄로 부르는 이름.
    var name: String { "\(color.name) · \(pattern.name)" }
}

/// 잉크 8색의 값과 이름. **목록 자체는 문서가 든다** — 저장되는 값이다.
extension InkColor {
    /// 마커 진하기의 기본값과 범위. **색을 두 벌 만들지 않는다** — 같은 8색을 이 값으로 깐다.
    /// 0.4는 형광펜처럼 겹쳐 그었을 때 아래 글자가 읽히는 값이다.
    static let markerOpacity: Double = 0.4
    /// `11-O1`이 다루는 백분율. **0은 안 준다** — 안 보이는 잉크는 고장으로 읽힌다.
    static let markerOpacityRange: ClosedRange<CGFloat> = 10...100

    /// 마커로 그을 때의 색.
    func markerColor(_ opacity: Double = markerOpacity) -> Color { color.opacity(opacity) }

    var color: Color {
        switch self {
        case .sumi: Color(hex: 0x2A2521)
        case .pencil: Color(hex: 0x7A736A)
        case .red: Color(hex: 0xA8392B)
        case .orange: Color(hex: 0xC9722F)
        case .yellow: Color(hex: 0xD8B33A)
        case .green: Color(hex: 0x4C6B4A)
        case .navy: Color(hex: 0x2E4A6B)
        case .white: Color(hex: 0xFFFFFF)
        }
    }

    var name: String {
        switch self {
        case .sumi: "먹"
        case .pencil: "연필"
        case .red: "붉은 잉크"
        case .orange: "주황"
        case .yellow: "노랑"
        case .green: "초록"
        case .navy: "남청"
        case .white: "흰색"
        }
    }
}

/// 종이 한 장 — 색 위에 무늬를 절차적으로 얹는다.
struct CanvasPaperView: View {
    let paper: PaperStyle
    /// 무늬 간격의 배수. 썸네일은 절반으로 그린다 — 실치수면 무늬가 아니라 점 몇 개로 읽힌다.
    var patternScale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper.color.color))
            guard paper.pattern.spacing > 0 else { return }
            context.fill(pattern(in: size), with: .color(paper.patternColor))
        }
    }

    private func pattern(in size: CGSize) -> Path {
        let step = paper.pattern.spacing * patternScale
        // ⚠️ **선 폭도 배수를 따라야 한다** — 간격만 줄이면 잉크 밀도가 그만큼 올라가
        // 요약한 모눈이 실제 종이보다 진해진다. 0.5 아래로는 안 내린다(흐려진다).
        let line = max(0.5, patternScale)
        var path = Path()
        switch paper.pattern {
        case .dots:
            let diameter = PaperPattern.dotDiameter * patternScale
            for y in stride(from: step, to: size.height, by: step) {
                for x in stride(from: step, to: size.width, by: step) {
                    path.addEllipse(in: CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                               width: diameter, height: diameter))
                }
            }
        case .grid:
            for x in stride(from: step, to: size.width, by: step) {
                path.addRect(CGRect(x: x, y: 0, width: line, height: size.height))
            }
            for y in stride(from: step, to: size.height, by: step) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: line))
            }
        case .lines:
            for y in stride(from: step, to: size.height, by: step) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: line))
            }
        case .plain:
            break
        }
        return path
    }
}
#endif
