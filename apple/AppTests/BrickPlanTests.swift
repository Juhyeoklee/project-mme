// `05-G` 벽돌쌓기의 칸 배분과, 그 격자가 `06`에 넘기는 목록.
//
// 배치는 폭과 종횡비의 함수라 값을 바꿔가며 부르는 것이 확인하는 유일한 방법이고,
// 넘기는 목록은 **셀 종류로** 갈린다 — 일반 셀은 격자가 보여준 대표들, 연사 셀은 그 묶음만.

import SwiftUI
import Testing
@testable import Moanogi

private typealias Cell = MomentDetailScreen.Cell

/// 연사가 아닌 셀 하나.
private func cell(_ index: Int, aspect: CGFloat) -> Cell {
    Cell(photoIndex: index, scene: [index], aspect: aspect)
}

/// 가로 사진의 종횡비. 실물 표본이 이 모양이다.
private let landscape: CGFloat = 1600.0 / 738
private let portrait: CGFloat = 738.0 / 1600

/// ⚠️ **`@MainActor`가 필요하다** — `plan`·`run`이 `View` 소속이라 격리를 물려받는다.
@Suite("벽돌쌓기 칸 배분")
@MainActor
struct BrickPlanTests {

    // MARK: - 열

    @Test func 열은_둘이다() {
        let plan = MomentDetailScreen.plan(cells: (0..<8).map { cell($0, aspect: landscape) },
                                           width: 366)
        #expect(plan.columns.count == 2)
    }

    @Test func 사진이_한_장이면_한_열이다() {
        let plan = MomentDetailScreen.plan(cells: [cell(0, aspect: landscape)], width: 366)
        #expect(plan.columns.count == 1)
        #expect(plan.columnWidth == 366)
    }

    @Test func 열_폭은_남은_폭을_고르게_나눈다() {
        let plan = MomentDetailScreen.plan(cells: (0..<4).map { cell($0, aspect: landscape) },
                                           width: 366)
        #expect(plan.columnWidth == (366 - Spacing.cellGap) / 2)
    }

    // MARK: - 배치

    @Test func 종횡비가_균일하면_시간순이_안_어긋난다() {
        let plan = MomentDetailScreen.plan(cells: (0..<6).map { cell($0, aspect: landscape) },
                                           width: 366)
        // 행 정렬과 픽셀 단위로 같아진다 — 왼쪽 짝수, 오른쪽 홀수.
        #expect(plan.columns[0].map(\.photoIndex) == [0, 2, 4])
        #expect(plan.columns[1].map(\.photoIndex) == [1, 3, 5])
    }

    @Test func 긴_사진_뒤의_칸들은_짧은_열로_간다() {
        // 0번이 세로라 왼쪽 열이 훌쩍 길어진다 — 뒤따르는 셋이 전부 오른쪽으로 가야 한다.
        let cells = [cell(0, aspect: portrait)] + (1..<4).map { cell($0, aspect: landscape) }
        let plan = MomentDetailScreen.plan(cells: cells, width: 366)
        #expect(plan.columns[0].map(\.photoIndex) == [0])
        #expect(plan.columns[1].map(\.photoIndex) == [1, 2, 3])
    }

    @Test func 동률이면_왼쪽부터_채운다() {
        let plan = MomentDetailScreen.plan(cells: (0..<2).map { cell($0, aspect: landscape) },
                                           width: 366)
        #expect(plan.columns[0].map(\.photoIndex) == [0])
        #expect(plan.columns[1].map(\.photoIndex) == [1])
    }

    // MARK: - `06`이 넘기는 목록

    @Test func 일반_셀은_격자가_보여준_목록을_넘긴다() {
        let cells = [cell(0, aspect: landscape),
                     Cell(photoIndex: 1, scene: [1, 2, 3], aspect: landscape),
                     cell(4, aspect: landscape)]
        let run = MomentDetailScreen.run(for: cells[0], in: cells)
        // 격자에 없던 연사 컷(2·3)이 뷰어에서 튀어나오면 안 된다.
        #expect(run.photos == [0, 1, 4])
        #expect(run.start == 0)
    }

    @Test func 연사_셀은_그_묶음만_넘긴다() {
        let cells = [cell(0, aspect: landscape),
                     Cell(photoIndex: 1, scene: [1, 2, 3], aspect: landscape)]
        let run = MomentDetailScreen.run(for: cells[1], in: cells)
        #expect(run.photos == [1, 2, 3])
        #expect(run.start == 1)
    }

    // MARK: - 계약

    /// ⚠️ **격자는 자기가 받은 폭을 넘지 않는다.** 화면이 이 폭을 재서 다시 격자에 주므로,
    /// 1pt라도 넘치면 값이 상한까지 기어오른다(2026-08-12 실측: 패스마다 6씩 늘었다).
    @Test(arguments: [1, 2, 3, 6, 9, 20])
    func 열_전체가_받은_폭_안에_들어간다(count: Int) {
        let width: CGFloat = 366
        let plan = MomentDetailScreen.plan(cells: (0..<count).map { cell($0, aspect: landscape) },
                                           width: width)
        let used = plan.columnWidth * CGFloat(plan.columns.count)
            + Spacing.cellGap * CGFloat(plan.columns.count - 1)
        #expect(used <= width)
    }

    /// 모든 셀이 정확히 한 번씩 놓인다 — 잃지도 겹치지도 않는다.
    @Test func 셀을_잃지_않는다() {
        let cells = (0..<9).map { cell($0, aspect: $0.isMultiple(of: 3) ? portrait : landscape) }
        let plan = MomentDetailScreen.plan(cells: cells, width: 366)
        #expect(plan.columns.flatMap { $0 }.map(\.photoIndex).sorted() == Array(0..<9))
    }
}
