// 작성 중인 기록. 디스크도 사진 라이브러리도 안 타는 순수 계산이라 여기서 명세가 선다.

import Foundation
import MomentKernel
import PhotoSource
import Testing
@testable import Moanogi

private func clock(_ hour: Int, _ minute: Int) throws -> WallClock {
    try #require(WallClock(year: 2026, month: 8, day: 3,
                           hour: hour, minute: minute, second: 0, hundredth: 0))
}

private let day = CalendarDay(year: 2026, month: 8, day: 3)

private func sourcePhoto(_ id: String, at capturedAt: WallClock) -> DraftPhoto {
    DraftPhoto(id: UUID(),
               origin: .source(asset: SourceAsset(id: id, filename: "\(id).png",
                                                  pixelWidth: 1600, pixelHeight: 738),
                               capturedAt: capturedAt),
               isIncluded: true)
}

/// ⚠️ **`@MainActor`가 필요하다** — `RecordDraft`가 그 격리에 산다.
@Suite("작성 중인 기록")
@MainActor
struct RecordDraftTests {

    // MARK: - `REC-07` 발생일시

    @Test func 자동값은_담긴_사진의_가장_이른_촬영시각이다() throws {
        let photos = [sourcePhoto("b", at: try clock(18, 30)),
                      sourcePhoto("a", at: try clock(18, 5))]

        let draft = RecordDraft(day: day, start: try clock(19, 0),
                                startsFromMoment: true, photos: photos)

        #expect(draft.occurredAt == (try clock(18, 5)))
    }

    @Test func 사진을_빼면_자동값이_다시_계산된다() throws {
        let early = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(19, 0), startsFromMoment: true,
                                photos: [early, sourcePhoto("b", at: try clock(18, 30))])

        draft.toggle(early.id)

        #expect(draft.occurredAt == (try clock(18, 30)))
    }

    @Test func 사용자가_고친_뒤에는_자동_계산이_덮지_않는다() throws {
        let early = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(19, 0), startsFromMoment: true,
                                photos: [early, sourcePhoto("b", at: try clock(18, 30))])

        draft.setOccurredAt(try clock(9, 0))
        draft.toggle(early.id)

        #expect(draft.occurredAt == (try clock(9, 0)))
    }

    @Test func 가져온_사진은_자동값에_참여하지_않는다() throws {
        let draft = RecordDraft(day: day, start: try clock(19, 0), startsFromMoment: true,
                                photos: [sourcePhoto("a", at: try clock(18, 5))])

        draft.addImported(Data("x".utf8), fileExtension: "jpg")

        #expect(draft.occurredAt == (try clock(18, 5)))
    }

    @Test func 사진_없이_시작하면_시작_시각이_자동값이다() throws {
        let draft = RecordDraft(day: day, start: try clock(19, 0),
                                startsFromMoment: false, photos: [])

        #expect(draft.occurredAt == (try clock(19, 0)))
    }

    @Test func 사진을_전부_빼면_발생일시가_마지막_값으로_남는다() throws {
        // 자동값은 **담긴 사진이 있을 때만** 움직인다 — 0장이면 저장도 못 하므로 값이 쓰일
        // 데가 없고, `start`로 되돌리면 머리의 날짜가 이유 없이 튄다.
        let photo = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(19, 0),
                                startsFromMoment: true, photos: [photo])

        draft.toggle(photo.id)

        #expect(draft.occurredAt == (try clock(18, 5)))
    }

    @Test func 가져온_사진만_있으면_시작_시각이_자동값이다() throws {
        let draft = RecordDraft(day: day, start: try clock(19, 0),
                                startsFromMoment: false, photos: [])

        draft.addImported(Data("x".utf8), fileExtension: "jpg")

        #expect(draft.occurredAt == (try clock(19, 0)))
    }

    // MARK: - 빼기와 더하기

    @Test func 사진이_하나도_안_담기면_저장할_수_없다() throws {
        let photo = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(18, 5),
                                startsFromMoment: true, photos: [photo])

        #expect(draft.canSave)
        draft.toggle(photo.id)
        #expect(!draft.canSave)
    }

    @Test func 더한_사진은_기존_자리를_밀지_않고_끝에_붙는다() throws {
        let first = sourcePhoto("a", at: try clock(18, 30))
        let draft = RecordDraft(day: day, start: try clock(18, 30),
                                startsFromMoment: true, photos: [first])
        // 시간상으로는 앞서지만 자리는 뒤다 — 방금 더한 것이 어디 갔는지 보여야 한다.
        let earlier = sourcePhoto("b", at: try clock(18, 5))

        draft.apply(includedAssets: ["a", "b"], candidates: [earlier, first])

        #expect(draft.photos.map(\.asset?.id) == ["a", "b"])
    }

    @Test func 확정에서_빠진_사진은_담김이_풀린다() throws {
        let photo = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(18, 5),
                                startsFromMoment: true, photos: [photo])

        draft.apply(includedAssets: [], candidates: [photo])

        #expect(draft.photos.count == 1)
        #expect(draft.included.isEmpty)
    }

    @Test func 같은_사진을_두_번_더해도_한_장이다() throws {
        let photo = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(18, 5),
                                startsFromMoment: true, photos: [photo])

        draft.apply(includedAssets: ["a"], candidates: [sourcePhoto("a", at: try clock(18, 5))])

        #expect(draft.photos.count == 1)
    }

    // MARK: - `REC-10` 가져온 사진

    @Test func 가져온_사진은_목록_끝에_붙고_바이트를_들고_있다() throws {
        let draft = RecordDraft(day: day, start: try clock(18, 5), startsFromMoment: true,
                                photos: [sourcePhoto("a", at: try clock(18, 5))])

        draft.addImported(Data("bytes".utf8), fileExtension: "jpg")

        let added = try #require(draft.photos.last)
        #expect(added.asset == nil)
        #expect(added.capturedAt == nil)
        #expect(draft.importedData(of: added.id) == Data("bytes".utf8))
    }

    // MARK: - 실패

    @Test func 원본을_못_읽으면_저장이_실패로_끝난다() async throws {
        let draft = RecordDraft(day: day, start: try clock(18, 5), startsFromMoment: true,
                                photos: [sourcePhoto("a", at: try clock(18, 5))])
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "RecordDraftTests-\(UUID().uuidString)"))

        let saved = await draft.save(status: .published, to: store) { _ in
            throw CocoaError(.fileNoSuchFile)
        }

        #expect(saved == nil)
        #expect(draft.saveState == .failed)
        // ⚠️ **디스크에 아무것도 안 남는다** — 바이트를 전부 모은 뒤에 저장소를 한 번 부르기
        // 때문이다. `store.save`가 루프 안으로 들어가면 이 줄이 깨진다.
        #expect(try store.all().isEmpty)
        draft.clearFailure()
        #expect(draft.saveState == .editing)
    }

    // MARK: - 순간에서 시작하기

    @Test func 연사_장면은_대표_한_장만_담긴다() throws {
        let moment = Fixture.momentWithBurst
        let sourceDay = try #require(Fixture.library.days.first {
            $0.moments.contains(moment)
        })

        let draft = RecordDraft.from(moment: moment, day: sourceDay.date,
                                     library: Fixture.library)

        #expect(draft.photos.count == moment.scenes.count)
        #expect(draft.photos.count < moment.photoCount)
    }

    @Test func 날짜에서_시작하면_그_날_모든_순간이_시간_오름차순으로_담긴다() throws {
        let sourceDay = try #require(Fixture.library.days.first)

        let draft = try #require(RecordDraft.from(day: sourceDay, library: Fixture.library))

        // 커널은 최신 먼저로 준다 — 뒤집는 자리가 깨지면 하루 서사가 거꾸로 읽힌다.
        let times = draft.photos.compactMap(\.capturedAt)
        #expect(times == times.sorted())
        #expect(draft.photos.count == sourceDay.moments.reduce(0) { $0 + $1.scenes.count })
    }

    @Test func 이_순간_꼬리는_순간에서_시작했을_때만_붙는다() throws {
        let sourceDay = try #require(Fixture.library.days.first)
        let moment = try #require(sourceDay.moments.first)

        let fromMoment = RecordDraft.from(moment: moment, day: sourceDay.date,
                                          library: Fixture.library)
        let fromDay = try #require(RecordDraft.from(day: sourceDay, library: Fixture.library))

        #expect(fromMoment.startsFromMoment)
        #expect(!fromDay.startsFromMoment)
    }

    // MARK: - 계약

    @Test func 뺀_사진도_목록에_남는다() throws {
        // ⚠️ 빼는 것은 삭제가 아니라 선택 해제다 — 되돌릴 수 있어야 한다.
        let photo = sourcePhoto("a", at: try clock(18, 5))
        let draft = RecordDraft(day: day, start: try clock(18, 5),
                                startsFromMoment: true, photos: [photo])

        draft.toggle(photo.id)

        #expect(draft.photos.count == 1)
        #expect(draft.included.isEmpty)
        #expect(draft.removedCount == 1)
    }

    @Test func 가져온_사진은_확정에_휩쓸리지_않는다() throws {
        let draft = RecordDraft(day: day, start: try clock(18, 5), startsFromMoment: true,
                                photos: [sourcePhoto("a", at: try clock(18, 5))])
        draft.addImported(Data("bytes".utf8), fileExtension: "jpg")

        // `10`이 확정하는 것은 소스 안 목록이다.
        draft.apply(includedAssets: ["a"], candidates: [])

        #expect(draft.photos.count == 2)
        #expect(draft.included.count == 2)
    }

    @Test func 초안은_순간을_들고_있지_않는다() throws {
        // `P2` — 순간을 값으로 들면 이 문장이 깨진다. `startsFromMoment`는 깃발이지 참조가 아니다.
        let draft = RecordDraft(day: day, start: try clock(18, 5), startsFromMoment: true,
                                photos: [sourcePhoto("a", at: try clock(18, 5))])

        #expect(!Mirror(reflecting: draft).children.contains { $0.value is Moment })
    }
}
