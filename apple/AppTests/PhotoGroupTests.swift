// `04`가 세우고 `05`가 여는 덩어리 — 순간과 날짜만 묶음이 한 타입으로 오는 계약.

import MomentKernel
import Testing
@testable import Moanogi

@Suite("사진 묶음")
@MainActor
struct PhotoGroupTests {

    @Test func 날짜만_묶음은_그_날의_맨_뒤에_선다() throws {
        // 시각이 없는 것을 시간축 사이에 끼우면 목록의 순서가 거짓말이 된다.
        let day = try #require(Fixture.classification.days.first { !$0.dateOnlyPhotos.isEmpty })

        let groups = day.groups

        #expect(groups.count == day.moments.count + 1)
        #expect(groups.dropLast().allSatisfy { $0.isPlaced })
        #expect(!groups[groups.count - 1].isPlaced)
    }

    @Test func 날짜만_사진이_없으면_묶음도_안_선다() throws {
        let day = try #require(Fixture.classification.days.first { $0.dateOnlyPhotos.isEmpty })

        #expect(day.groups.count == day.moments.count)
        #expect(day.groups.allSatisfy { $0.isPlaced })
    }

    @Test func 날짜만_묶음은_전부_1장짜리_장면이다() {
        // 연사 접기는 바이트를 요구하는데 그 사진들의 바이트는 읽지 않는다.
        let group = Fixture.dateOnlyGroup

        #expect(!group.isPlaced)
        #expect(group.sceneCount == group.photoCount)
        #expect(group.scenes.allSatisfy { $0.count == 1 })
    }

    @Test func 신원은_장면_구성이_바뀌어도_안_바뀐다() throws {
        // 2패스가 바이트를 채우며 장소 경계를 다시 계산한다 — 그때마다 행이 헐리면 안 된다.
        let day = try #require(Fixture.classification.days.first)
        let moment = try #require(day.moments.first)

        let group = PhotoGroup(moment: moment, day: day.date)

        #expect(group.id == moment.photoIndices[0])
    }

    // MARK: - 고른 묶음을 재분류 너머로 잇는다 (`SRC-03`)

    @Test func 고른_묶음의_첫_사진으로_그_묶음을_다시_찾는다() throws {
        let groups = Fixture.classification.days.flatMap(\.groups)
        let chosen = try #require(groups.dropFirst().first)

        #expect(groups.group(containing: chosen.id) == chosen)
    }

    /// 새 사진이 들어오면 순간이 쪼개진다 — 고른 묶음은 사라지고 그 사진은 다른 묶음에 든다.
    @Test func 묶음이_쪼개지면_첫_사진이_간_쪽으로_따라간다() throws {
        let day = try #require(Fixture.classification.days.first { $0.moments.contains { $0.photoCount > 1 } })
        let moment = try #require(day.moments.first { $0.photoCount > 1 })
        let whole = PhotoGroup(moment: moment, day: day.date)
        // 같은 사진들이 한 장씩 갈라진 뒤.
        let split = moment.photoIndices.map { PhotoGroup(dateOnly: [$0], day: day.date)! }

        let found = try #require(split.group(containing: whole.id))

        #expect(found.photoIndices == [whole.id])
    }

    /// 반대 방향 — 묶음이 합쳐져 고른 사진이 더 이상 첫 사진이 아니게 되는 자리.
    @Test func 첫_사진이_아니게_돼도_품은_묶음을_찾는다() throws {
        let day = try #require(Fixture.classification.days.first)
        let moment = try #require(day.moments.first { $0.photoCount > 1 })
        let group = PhotoGroup(moment: moment, day: day.date)
        let notFirst = try #require(group.photoIndices.dropFirst().first)

        #expect([group].group(containing: notFirst) == group)
    }

    @Test func 소스에서_사라진_사진은_어느_묶음에도_안_든다() {
        let groups = Fixture.classification.days.flatMap(\.groups)
        let gone = (groups.flatMap(\.photoIndices).max() ?? 0) + 1

        #expect(groups.group(containing: gone) == nil)
    }

    @Test func 순간_묶음은_그_순간의_장면과_사진을_그대로_든다() throws {
        let day = try #require(Fixture.classification.days.first)
        let moment = try #require(day.moments.first)

        let group = PhotoGroup(moment: moment, day: day.date)

        #expect(group.start == moment.start)
        #expect(group.day == day.date)
        #expect(group.sceneCount == moment.sceneCount)
        #expect(group.photoIndices == moment.photoIndices)
    }
}
