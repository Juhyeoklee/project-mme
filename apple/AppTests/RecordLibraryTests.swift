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

/// 그 기록의 디렉터리. 배치는 `RecordStore`가 계약으로 든다 — 이미지 자리에서 두 단계 위다.
private func directory(of record: Record, in store: RecordStore) -> URL {
    store.imageURL(recordID: record.id, image: record.images[0])
        .deletingLastPathComponent().deletingLastPathComponent()
}

/// 디렉터리를 읽기 전용으로 잠근다 — 안을 못 바꾸니 지우기도 쓰기도 실패한다.
/// ⚠️ **`unlock`을 꼭 짝지어 부른다** — 안 풀면 임시 디렉터리를 아무도 못 치운다.
private func lock(_ directory: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
}

private func unlock(_ directory: URL) {
    try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
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

        try library.delete(id: one.id)

        #expect(library.records.isEmpty)
        #expect(try library.store.all().isEmpty)
    }

    @Test func 못_지우면_호출자가_실패를_받고_기록은_남는다() throws {
        let library = makeLibrary()
        let one = record(at: try clock(2026, 8, 3))
        try library.store.save(one, imageData: [one.images[0].id: Data("x".utf8)])
        library.reload()
        let directory = directory(of: one, in: library.store)
        try lock(directory)
        defer { unlock(directory) }

        #expect(throws: RecordStoreError.self) { try library.delete(id: one.id) }
        #expect(library.records.map(\.id) == [one.id])
    }

    @Test func 못_지워도_목록은_디스크를_따른다() throws {
        // 매니페스트는 밖에서 먼저 사라지고 디렉터리는 그 뒤 잠긴다 — 지우기는 던지지만
        // 디스크에는 이미 기록이 없다. 던지기 전에 다시 안 읽으면 목록이 거짓말한다.
        let library = makeLibrary()
        let one = record(at: try clock(2026, 8, 3))
        try library.store.save(one, imageData: [one.images[0].id: Data("x".utf8)])
        library.reload()
        let directory = directory(of: one, in: library.store)
        try FileManager.default.removeItem(at: directory.appending(path: "record.json"))
        try lock(directory)
        defer { unlock(directory) }

        #expect(throws: RecordStoreError.self) { try library.delete(id: one.id) }
        #expect(library.records.isEmpty)
    }

    // MARK: - `ARC-08` 게시

    @Test func 게시하면_초안_표시가_사라진다() throws {
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])
        library.reload()

        try library.publish(draft)

        #expect(library.records.map(\.status) == [.published])
    }

    @Test func 게시는_설명을_요구하지_않는다() throws {
        // ⚠️ 초안 여부가 설명의 파생값이면 `게시`는 눌러도 아무 일이 안 일어나는 버튼이 된다.
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])

        try library.publish(draft)

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

        try library.publish(draft)

        let url = library.store.imageURL(recordID: draft.id, image: draft.images[0])
        #expect(try Data(contentsOf: url) == Data("bytes".utf8))
    }

    @Test func 못_게시하면_호출자가_실패를_받고_초안으로_남는다() throws {
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])
        library.reload()
        let directory = directory(of: draft, in: library.store)
        try lock(directory)
        defer { unlock(directory) }

        #expect(throws: RecordStoreError.self) { try library.publish(draft) }
        #expect(library.records.map(\.status) == [.draft])
    }

    @Test func 못_게시해도_목록은_디스크를_따른다() throws {
        // 디스크가 먼저 게시되고 그 뒤 잠긴다 — 게시는 던지지만 목록은 디스크의 게시 상태를 든다.
        let library = makeLibrary()
        let draft = record(at: try clock(2026, 8, 3), status: .draft)
        try library.store.save(draft, imageData: [draft.images[0].id: Data("x".utf8)])
        library.reload()
        var elsewhere = draft
        elsewhere.status = .published
        try library.store.save(elsewhere, imageData: [:])
        let directory = directory(of: draft, in: library.store)
        try lock(directory)
        defer { unlock(directory) }

        #expect(throws: RecordStoreError.self) { try library.publish(draft) }
        #expect(library.records.map(\.status) == [.published])
    }
}
