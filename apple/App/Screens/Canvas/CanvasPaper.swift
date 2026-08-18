// 캔버스 종이와 잉크 — `11`만 쓰는 값과 그 값을 그리는 법.
//
// ⚠️ **앱 팔레트가 아니다.** 여기 색은 사용자가 고르는 재료라 모드를 따르지 않는다 —
// 종이는 다크에서도 종이여야 한다.

import SwiftUI

/// 종이 4종의 색과 무늬.
///
/// **색 하나에 무늬 하나가 고정으로 붙는다** — 색 × 무늬 격자를 만들면 선택지가 넷을 넘고
/// 고르는 UI가 1단으로 안 남는다.
///
/// ⚠️ **무늬는 절차적으로 그린다.** 비트맵 타일을 깔면 확대(`CAN-02`)와 이미지 굽기
/// (`CAN-09`)에서 깨진다.
extension PaperKind {
    var color: Color {
        switch self {
        case .grid: Color(hex: 0xFFFFFF)
        case .dots: Color(hex: 0xF7EEDA)
        case .lines: Color(hex: 0xEBEAE6)
        case .plain: Color(hex: 0xE3EBE7)
        }
    }

    /// 무늬 색은 뉴트럴 램프의 `종이-7`을 알파로 깐 것이다 — 새 색을 만들지 않았다.
    var patternColor: Color {
        switch self {
        case .grid: Paper.step7.opacity(0.08)
        case .dots: Paper.step7.opacity(0.15)
        case .lines: Paper.step7.opacity(0.10)
        case .plain: .clear
        }
    }

    /// 무늬 간격. 민무늬는 0이다.
    var patternSpacing: CGFloat {
        switch self {
        case .grid: 24
        case .dots: 22
        case .lines: 28
        case .plain: 0
        }
    }

    var name: String {
        switch self {
        case .grid: "모눈"
        case .dots: "점"
        case .lines: "줄"
        case .plain: "민무늬"
        }
    }
}

/// 잉크 8색의 값과 이름. **목록 자체는 문서가 든다** — 저장되는 값이다.
extension InkColor {
    /// 마커 진하기의 기본값과 범위. **색을 두 벌 만들지 않는다** — 같은 8색을 이 값으로 깐다.
    /// 0.4는 형광펜처럼 겹쳐 그었을 때 아래 글자가 읽히는 값이다 (세션 판단 2026-08-18).
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
    let paper: PaperKind
    /// 무늬 간격의 배수. 썸네일은 절반으로 그린다 — 실치수면 무늬가 아니라 점 몇 개로 읽힌다.
    var patternScale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper.color))
            guard paper.patternSpacing > 0 else { return }
            context.fill(pattern(in: size), with: .color(paper.patternColor))
        }
    }

    private func pattern(in size: CGSize) -> Path {
        let step = paper.patternSpacing * patternScale
        var path = Path()
        switch paper {
        case .dots:
            let diameter = 2.4 * patternScale
            for y in stride(from: step, to: size.height, by: step) {
                for x in stride(from: step, to: size.width, by: step) {
                    path.addEllipse(in: CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                               width: diameter, height: diameter))
                }
            }
        case .grid:
            for x in stride(from: step, to: size.width, by: step) {
                path.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
            }
            for y in stride(from: step, to: size.height, by: step) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
            }
        case .lines:
            for y in stride(from: step, to: size.height, by: step) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
            }
        case .plain:
            break
        }
        return path
    }
}
