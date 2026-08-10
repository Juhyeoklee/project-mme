// `04-C3` 스트립의 칸 배분. **규칙은 행이지 장수가 아니라서** 폭이 결과를 정한다 —
// 폭을 바꿔가며 부르는 것이 이 계산을 확인하는 유일한 방법이다.

import SwiftUI
import Testing
@testable import Moanogi

/// 정확히 `count`장이 한 행에 들어가는 폭.
private func width(forPerRow count: Int) -> CGFloat {
    CGFloat(count) * Layout.thumbnail + CGFloat(count - 1) * Spacing.thumbnailGap
}

/// ⚠️ **`@MainActor`가 필요하다** — `plan`은 `View` 소속이라 격리를 물려받는다.
/// 빼면 컴파일은 통과하고 **실행 중에 격리 검사가 트랩을 낸다**(2026-08-10 실측).
@Suite("스트립 칸 배분")
@MainActor
struct StripPlanTests {

    // MARK: - 행

    @Test func 폭이_장수를_정한다() {
        #expect(Layout.thumbnailsPerRow(inWidth: width(forPerRow: 3)) == 3)
        #expect(Layout.thumbnailsPerRow(inWidth: width(forPerRow: 2)) == 2)
        // 3장에서 1pt 모자라면 2장이다 — 반올림하지 않는다.
        #expect(Layout.thumbnailsPerRow(inWidth: width(forPerRow: 3) - 1) == 2)
    }

    @Test func 아무리_좁아도_한_장은_넣는다() {
        #expect(Layout.thumbnailsPerRow(inWidth: 0) == 1)
        #expect(Layout.thumbnailsPerRow(inWidth: 10) == 1)
    }

    // MARK: - 칸

    @Test func 다_들어가면_장면_수만큼만_놓는다() {
        let plan = MomentCard.plan(sceneCount: 4, width: width(forPerRow: 3))
        #expect(plan.rows.map(\.count) == [3, 1])
        #expect(plan.rows.flatMap { $0 } == [.scene(0), .scene(1), .scene(2), .scene(3)])
    }

    @Test func 넘치면_마지막_칸을_더하기가_가져간다() {
        // 3장 × 2행 = 6칸에 10장면 → 앞 5칸 + `+5`. **폭을 뺏지 않고 칸을 쓴다.**
        let plan = MomentCard.plan(sceneCount: 10, width: width(forPerRow: 3))
        #expect(plan.rows.map(\.count) == [3, 3])
        #expect(plan.rows[1].last == .more(5))
        #expect(plan.rows.flatMap { $0 }.filter { if case .scene = $0 { true } else { false } }.count == 5)
    }

    @Test func 정확히_다_차면_더하기가_안_나온다() {
        let plan = MomentCard.plan(sceneCount: 6, width: width(forPerRow: 3))
        #expect(plan.rows.flatMap { $0 }.contains { if case .more = $0 { true } else { false } } == false)
    }

    @Test func 한_칸만_들어가는_폭에서도_깨지지_않는다() {
        // 칸이 2개(1장 × 2행)뿐이라 `capacity - 1`이 1이 되는 경계다.
        let plan = MomentCard.plan(sceneCount: 9, width: 0)
        #expect(plan.rows.map(\.count) == [1, 1])
        #expect(plan.rows.flatMap { $0 } == [.scene(0), .more(8)])
    }

    // MARK: - 계약

    @Test func 장면이_없으면_행도_없다() {
        #expect(MomentCard.plan(sceneCount: 0, width: width(forPerRow: 3)).rows.isEmpty)
    }

    @Test func 상한은_행_수가_정한다() {
        // `stripRows`가 2인 한, 어떤 폭에서도 행이 2를 넘지 않는다.
        for perRow in 1...5 {
            let plan = MomentCard.plan(sceneCount: 99, width: width(forPerRow: perRow))
            #expect(plan.rows.count <= Layout.stripRows, "\(perRow)장/행")
        }
    }
}
