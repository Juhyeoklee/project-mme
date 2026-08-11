// 기록 저장소 — 디스크를 실제로 태운다. 임시 디렉터리에 쓰고 다시 읽는다.

import Foundation
import MomentKernel
import Testing
@testable import Moanogi

/// 테스트마다 새 자리. 남겨도 임시 디렉터리라 시스템이 치운다.
private func makeStore() -> RecordStore {
    RecordStore(root: FileManager.default.temporaryDirectory
        .appending(path: "RecordStoreTests-\(UUID().uuidString)"))
}

private func clock(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> WallClock {
    try #require(WallClock(year: 2026, month: month, day: day,
                           hour: hour, minute: minute, second: 0, hundredth: 0))
}

private func sourceImage(assetID: String, at capturedAt: WallClock) -> RecordImage {
    RecordImage(id: UUID(), fileExtension: "png",
                origin: .source(assetID: assetID, capturedAt: capturedAt))
}

private func record(at occurredAt: WallClock,
                    images: [RecordImage],
                    caption: String = "",
                    status: Record.Status = .published) -> Record {
    Record(id: UUID(), occurredAt: occurredAt, images: images,
           caption: caption, status: status, updatedAt: Date(timeIntervalSince1970: 1_780_000_000))
}

/// 이미지 하나에 붙일 가짜 바이트. 내용은 안 보고 자리와 왕복만 본다.
private func bytes(_ seed: String) -> Data {
    Data(seed.utf8)
}

/// 저장소를 거치지 않고 매니페스트를 직접 심는다 — 깨진 파일을 만들 방법이 이것뿐이다.
private func write(_ manifest: String, forRecord id: UUID, in store: RecordStore) throws {
    let directory = store.root.appending(path: id.uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(manifest.utf8).write(to: directory.appending(path: "record.json"))
}

@Suite("기록 저장소")
struct RecordStoreTests {

    // MARK: - 왕복

    @Test func 저장한_기록을_그대로_다시_읽는다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let written = record(at: try clock(8, 3, 18, 5), images: [image],
                             caption: "보스를 잡았다", status: .published)

        try store.save(written, imageData: [image.id: bytes("a")])
        let read = try #require(try store.all().first)

        #expect(read == written)
    }

    @Test func 가져온_사진과_소스_사진이_섞여도_왕복한다() throws {
        let store = makeStore()
        let fromSource = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let imported = RecordImage(id: UUID(), fileExtension: "jpg", origin: .imported)
        let written = record(at: try clock(8, 3, 18, 5), images: [fromSource, imported])

        try store.save(written, imageData: [fromSource.id: bytes("a"), imported.id: bytes("b")])
        let read = try #require(try store.all().first)

        #expect(read.images == [fromSource, imported])
    }

    @Test func 초안_상태가_보존된다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let draft = record(at: try clock(8, 3, 18, 5), images: [image], status: .draft)

        try store.save(draft, imageData: [image.id: bytes("a")])

        #expect(try store.all().first?.status == .draft)
    }

    // MARK: - 목록

    @Test func 저장소가_비어_있으면_빈_배열이다() throws {
        #expect(try makeStore().all().isEmpty)
    }

    @Test func 발생일시_역순으로_돌려준다() throws {
        let store = makeStore()
        for (month, day) in [(8, 3), (8, 10), (7, 26)] {
            let image = sourceImage(assetID: "a\(month)\(day)", at: try clock(month, day, 12, 0))
            let one = record(at: try clock(month, day, 12, 0), images: [image])
            try store.save(one, imageData: [image.id: bytes("a")])
        }

        let days = try store.all().map(\.occurredAt).map { ($0.month, $0.day) }

        #expect(days.map(\.0) == [8, 8, 7])
        #expect(days.map(\.1) == [10, 3, 26])
    }

    // MARK: - 이미지 파일

    @Test func 이미지_바이트가_기록_디렉터리_안에_놓인다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let one = record(at: try clock(8, 3, 18, 5), images: [image])

        try store.save(one, imageData: [image.id: bytes("픽셀")])
        let url = store.imageURL(recordID: one.id, image: image)

        #expect(try Data(contentsOf: url) == bytes("픽셀"))
        #expect(url.path.contains(one.id.uuidString))
    }

    @Test func 새_이미지의_바이트가_없으면_던진다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let one = record(at: try clock(8, 3, 18, 5), images: [image])

        #expect(throws: RecordStoreError.imageDataMissing(imageID: image.id)) {
            try store.save(one, imageData: [:])
        }
    }

    @Test func 이미_저장된_이미지는_바이트를_다시_안_받는다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        var one = record(at: try clock(8, 3, 18, 5), images: [image])
        try store.save(one, imageData: [image.id: bytes("a")])

        one.caption = "고쳐 썼다"
        try store.save(one, imageData: [:])

        #expect(try store.all().first?.caption == "고쳐 썼다")
    }

    @Test func 매니페스트가_안_가리키는_이미지는_치운다() throws {
        let store = makeStore()
        let kept = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let dropped = sourceImage(assetID: "asset-2", at: try clock(8, 3, 18, 6))
        var one = record(at: try clock(8, 3, 18, 5), images: [kept, dropped])
        try store.save(one, imageData: [kept.id: bytes("a"), dropped.id: bytes("b")])

        one.images = [kept]
        try store.save(one, imageData: [:])

        #expect(FileManager.default.fileExists(
            atPath: store.imageURL(recordID: one.id, image: kept).path))
        #expect(!FileManager.default.fileExists(
            atPath: store.imageURL(recordID: one.id, image: dropped).path))
    }

    // MARK: - 삭제

    @Test func 지운_기록은_목록에서_사라진다() throws {
        let store = makeStore()
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let one = record(at: try clock(8, 3, 18, 5), images: [image])
        try store.save(one, imageData: [image.id: bytes("a")])

        try store.delete(id: one.id)

        #expect(try store.all().isEmpty)
    }

    @Test func 없는_기록을_지우는_것은_실패가_아니다() throws {
        try makeStore().delete(id: UUID())
    }

    // MARK: - 못 읽는 것

    @Test func 나중_판으로_쓰인_기록은_던진다() throws {
        let store = makeStore()
        let id = UUID()
        let manifest = """
        {"schemaVersion": \(RecordStore.schemaVersion + 1), "id": "\(id.uuidString)",
         "occurredAt": "2026080318050000", "caption": "", "status": "published",
         "updatedAt": 0, "images": []}
        """
        try write(manifest, forRecord: id, in: store)

        // 갈래까지 본다 — `RecordStoreError.self`만 기대하면 다른 이유로 못 읽어도 초록이다.
        #expect(throws: RecordStoreError.unsupportedSchema(
            file: "record.json", version: RecordStore.schemaVersion + 1)) { try store.all() }
    }

    @Test func 달력에_없는_시각은_던진다() throws {
        let store = makeStore()
        let id = UUID()
        // 2월 30일. 형태는 맞고 값이 범위 밖인 갈래다.
        let manifest = """
        {"schemaVersion": \(RecordStore.schemaVersion), "id": "\(id.uuidString)",
         "occurredAt": "2026023012000000", "caption": "", "status": "published",
         "updatedAt": 0, "images": []}
        """
        try write(manifest, forRecord: id, in: store)

        #expect(throws: RecordStoreError.malformed(file: "record.json",
                                                   reason: "값이 범위 밖")) { try store.all() }
    }

    // MARK: - 계약

    @Test func 가져온_사진은_촬영시각을_갖지_않는다() {
        let imported = RecordImage(id: UUID(), fileExtension: "jpg", origin: .imported)

        #expect(imported.capturedAt == nil)
    }

    @Test func 기록은_순간을_가리키지_않는다() throws {
        // `P2` — 모델에 순간을 가리키는 값이 생기면 이 문장이 깨진다.
        let image = sourceImage(assetID: "asset-1", at: try clock(8, 3, 18, 5))
        let one = record(at: try clock(8, 3, 18, 5), images: [image])
        let mirror = Mirror(reflecting: one)

        #expect(!mirror.children.contains { ($0.label ?? "").lowercased().contains("moment") })
    }
}
