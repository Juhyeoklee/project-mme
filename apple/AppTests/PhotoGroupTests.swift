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
