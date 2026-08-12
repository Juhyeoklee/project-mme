// 기록 목록의 상태. 월 구분은 순수 계산이라 여기서 명세가 서고, 나머지는 디스크를 실제로 탄다.

import Foundation
import MomentKernel
import Testing
@testable import Moanogi

/// ⚠️ **`@MainActor`다** — `RecordLibrary`가 그 격리에 살아서, 빼면 컴파일이 막는다.
@MainActor
private func makeLibrary() -> RecordLibrary {
    RecordLibrary(store: RecordStore(root: FileManager.default.temporaryDirectory
        .appending(path: "RecordLibraryTests-\(UUID().uuidString)")))
}

private func clock(_ year: Int, _ month: Int, _ day: Int) throws -> WallClock {
    try #require(WallClock(year: year, month: month, day: day,
                           hour: 18, minute: 5, second: 0, hundredth: 0))
}

private func record(at occurredAt: WallClock, status: Record.Status = .published) -> Record {
    Record(id: UUID(), occurredAt: occurredAt,
           images: [RecordImage(id: UUID(), fileExtension: "png", origin: .imported)],
           caption: "", status: status, updatedAt: Date(timeIntervalSince1970: 1_780_000_000))
}

/// ⚠️ **`@MainActor`가 필요하다** — `RecordLibrary`가 그 격리에 산다.
@Suite("기록 목록")
@MainActor
struct RecordLibraryTests {

    // MARK: - `ARC-02` 월 구분

    @Test func 같은_달_기록은_한_구분_아래_묶인다() throws {
        let months = RecordLibrary.months(of: [record(at: try clock(2026, 8, 3)),
                                               record(at: try clock(2026, 8, 1))])

        #expect(months.count == 1)
        #expect(months[0].records.count == 2)
    }

    @Test func 달이_바뀌면_구분이_갈린다() throws {
        let months = RecordLibrary.months(of: [record(at: try clock(2026, 8, 1)),
                                               record(at: try clock(2026, 7, 29))])

        #expect(months.map(\.month) == [8, 7])
    }

    @Test func 해가_다르면_같은_달이어도_갈린다() throws {
        // ⚠️ 이것이 `07-B1`에 년을 쓰는 이유다 — 갈라 놓고 이름이 같으면 화면이 거짓말한다.
        let months = RecordLibrary.months(of: [record(at: try clock(2026, 8, 3)),
                                               record(at: try clock(2025, 8, 3))])

        #expect(months.count == 2)
        #expect(months.map(\.year) == [2026, 2025])
    }

    @Test func 기록이_없으면_구분도_없다() {
        #expect(RecordLibrary.months(of: []).isEmpty)
    }

    @Test func 들어온_순서를_뒤집지_않는다() throws {
        // 시간 역순(`ARC-01`)을 지는 것은 저장소다. 여기서 또 정렬하면 규칙이 두 곳에 산다.
        let months = RecordLibrary.months(of: [record(at: try clock(2026, 7, 1)),
                                               record(at: try clock(2026, 8, 1))])

        #expect(months.map(\.month) == [7, 8])
    }

    // MARK: - 읽기와 지우기

    @Test func 저장소가_비어_있으면_목록도_비어_있다() {
        let library = makeLibrary()

        library.reload()

        #expect(library.records.isEmpty)
        #expect(!library.loadFailed)
    }

    @Test func 저장한_기록이_시간_역순으로_읽힌다() throws {
        let library = makeLibrary()
        for month in [7, 8] {
            let one = record(at: try clock(2026, month, 3))
            try library.store.save(one, imageData: [one.images[0].id: Data("x".utf8)])
        }

        library.reload()

        #expect(library.records.map { $0.occurredAt.calendarDay.month } == [8, 7])
    }

    @Test func 지운_기록은_목록에서도_디스크에서도_사라진다() throws {
        let library = makeLibrary()
        let one = record(at: try clock(2026, 8, 3))
        try library.store.save(one, imageData: [one.images[0].id: Data("x".utf8)])
        library.reload()

        library.delete(id: one.id)

        #expect(library.records.isEmpty)
        #expect(try library.store.all().isEmpty)
    }

    // MARK: - `ARC-08` 게시

    @Test func 게시하면_초안_표시가_사라진다() throws {
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])
        library.reload()

        library.publish(draft)

        #expect(library.records.map(\.status) == [.published])
    }

    @Test func 게시는_설명을_요구하지_않는다() throws {
        // ⚠️ 초안 여부가 설명의 파생값이면 `게시`는 눌러도 아무 일이 안 일어나는 버튼이 된다.
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])

        library.publish(draft)

        let published = try #require(try library.store.all().first)
        #expect(published.caption.isEmpty)
        #expect(published.status == .published)
    }

    @Test func 게시해도_사진_바이트는_다시_안_쓰인다() throws {
        // 바이트를 안 넘기고 부르는 자리라, 저장소가 있는 파일을 건너뛰지 않으면 여기서 던진다.
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        let imageID = draft.images[0].id
        try library.store.save(draft, imageData: [imageID: Data("bytes".utf8)])

        library.publish(draft)

        let url = library.store.imageURL(recordID: draft.id, image: draft.images[0])
        #expect(try Data(contentsOf: url) == Data("bytes".utf8))
    }
}
