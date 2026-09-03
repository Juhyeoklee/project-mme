// 색 토큰 — 모드를 안 따르는 것이 실제로 안 따르는지 해석해서 잡는다. hex는 적지 않는다.

import SwiftUI
import Testing
@testable import Moanogi

@Suite("색 토큰")
struct ThemeTests {

    // MARK: - 조각

    /// sRGB 8비트로 내려 비교한다 — 동적 색은 해석 전에는 같은지 물을 수 없다.
    private func resolve(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { Int(($0 * 255).rounded()) }
    }

    // MARK: - 계약

    /// 모드를 안 따르는 토큰 — 두 슬롯에 같은 값을 든 것.
    static let fixed: [(String, Color)] = [
        ("뷰어배경", Palette.viewerBackground),
        ("온뷰어", Palette.onViewer),
        ("사진배지", Palette.photoBadge),
        ("온사진배지", Palette.onPhotoBadge),
        ("선택테두리", Palette.selectionEdge),
        ("그림자색", Chrome.shadowColor),
    ]

    @Test(arguments: fixed.map(\.0))
    func 모드를_안_따르는_토큰은_두_모드에서_같은_값으로_해석된다(name: String) throws {
        let color = try #require(Self.fixed.first { $0.0 == name }?.1)
        #expect(resolve(color, .light) == resolve(color, .dark))
    }

    @Test(arguments: AccentSet.allCases)
    func 선택_핸들_채움은_어느_벌이든_두_모드에서_그_벌의_라이트_값이다(set: AccentSet) {
        let light = resolve(set.light, .light)
        #expect(resolve(set.selectionFill, .light) == light)
        #expect(resolve(set.selectionFill, .dark) == light)
    }

    @Test(arguments: AccentSet.allCases)
    func 강조색은_모드마다_그_슬롯의_값으로_해석된다(set: AccentSet) {
        #expect(resolve(set.accent, .light) == resolve(set.light, .light))
        #expect(resolve(set.accent, .dark) == resolve(set.dark, .dark))
    }
}
