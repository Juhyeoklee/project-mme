// 기록 저장소 — **기록 하나 = 디렉터리 하나.**
//
// `App` 안에 살지만 하는 일이 어댑터다 — 경계 밖(디스크)과 말하고 실패가 밖에서 온다.
// 그래서 `throws` + 도메인 오류 하나로 말하고, 화면이 받아 화면 상태로 바꾼다.

import Foundation
import MomentKernel

/// 기록의 영속 저장소. 값 타입이라 어느 실행 문맥에서 불러도 안전하다.
///
/// 배치는 `<root>/<기록 id>/record.json` + `<root>/<기록 id>/images/<이미지 id>.<확장자>`다.
/// **디렉터리 하나가 통째로 한 기록**이라 삭제가 한 번이고, 나중에 올라갈 단위와도 같다.
///
/// ⚠️ **원자성은 매니페스트에만 걸린다** — 이미지를 먼저 쓰고 `record.json`을 마지막에 원자
/// 교체한다. 디렉터리를 통째로 갈면 안 바뀐 이미지까지 매번 복사하게 되기 때문이다.
///
/// ⚠️ **그 대가가 고아 이미지다.** 매니페스트를 쓰기 전에 죽거나 던지면 이미지가 남고,
/// **회수하는 것은 같은 기록의 다음 저장뿐이다** — 그 초안을 버리면 아무도 안 지운다.
/// `all()`은 매니페스트가 없는 디렉터리를 건너뛰므로 화면에는 안 보인다.
struct RecordStore: Sendable {
    /// 기록 디렉터리들이 서는 자리.
    let root: URL

    /// 이 판이 쓰는 저장 형식. 읽을 때 더 큰 번호를 만나면 던진다.
    static let schemaVersion = 1

    private static let manifestName = "record.json"
    private static let imagesDirectoryName = "images"

    init(root: URL) {
        self.root = root
    }

    /// 앱 컨테이너의 기본 자리. **자리를 계산만 하고 만들지는 않는다** —
    /// 디렉터리는 첫 저장이 만들고, 없는 동안 `all()`은 빈 배열이다.
    static var inApplicationSupport: RecordStore {
        RecordStore(root: URL.applicationSupportDirectory.appending(path: "Records"))
    }

    // MARK: - 읽기

    /// 저장된 기록 전부. **발생일시 역순**(`ARC-01`), 같으면 `id` 역순이라 순서가 결정적이다.
    /// ⚠️ **하나라도 못 읽으면 던진다** — 조용히 빼면 무엇을 잃었는지 아무도 모른다.
    func all() throws -> [Record] {
        var records: [Record] = []
        for directory in try Self.contents(of: root) {
            let manifest = directory.appending(path: Self.manifestName)
            guard FileManager.default.fileExists(atPath: manifest.path) else { continue }
            records.append(try Self.load(manifest))
        }
        return records.sorted {
            ($0.occurredAt, $0.id.uuidString) > ($1.occurredAt, $1.id.uuidString)
        }
    }

    /// 그 이미지 파일의 자리. 파일이 실제로 있는지는 보지 않는다.
    func imageURL(recordID: UUID, image: RecordImage) -> URL {
        directory(of: recordID)
            .appending(path: Self.imagesDirectoryName)
            .appending(path: "\(image.id.uuidString).\(image.fileExtension)")
    }

    // MARK: - 쓰기

    /// 기록을 저장한다. `imageData`에는 **아직 저장소에 없는 이미지의 바이트만** 담는다.
    /// ⚠️ **원자성은 매니페스트에만 건다** — 대가는 아래 타입 문서의 고아 이미지다.
    func save(_ record: Record, imageData: [UUID: Data]) throws {
        let directory = directory(of: record.id)
        let images = directory.appending(path: Self.imagesDirectoryName)
        try Self.createDirectory(images)

        for image in record.images {
            let url = imageURL(recordID: record.id, image: image)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let bytes = imageData[image.id] else {
                throw RecordStoreError.imageDataMissing(imageID: image.id)
            }
            try Self.write(bytes, to: url)
        }

        try Self.write(try Self.encode(record), to: directory.appending(path: Self.manifestName))
        // ⚠️ **청소는 저장의 성패가 아니다** — 매니페스트를 바꾼 시점에 기록은 이미 온전하다.
        // 여기서 던지면 성공한 저장이 실패로 보고된다.
        try? Self.removeOrphans(in: images, keeping: record.images)
    }

    /// `ARC-07`. 없는 기록을 지우는 것은 실패가 아니다.
    func delete(id: UUID) throws {
        let directory = directory(of: id)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            throw RecordStoreError.io(error, at: directory)
        }
    }

    // MARK: - 자리

    private func directory(of id: UUID) -> URL {
        root.appending(path: id.uuidString)
    }

    private static func contents(of url: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            throw RecordStoreError.io(error, at: url)
        }
    }

    private static func createDirectory(_ url: URL) throws {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw RecordStoreError.io(error, at: url)
        }
    }

    private static func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw RecordStoreError.io(error, at: url)
        }
    }

    /// 매니페스트가 더 이상 안 가리키는 이미지 파일을 치운다.
    private static func removeOrphans(in directory: URL, keeping images: [RecordImage]) throws {
        let kept = Set(images.map(\.id.uuidString))
        for file in try contents(of: directory)
        where !kept.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - 실패

/// 저장소가 말하는 실패.
enum RecordStoreError: Error, Sendable, Hashable, CustomStringConvertible {
    /// 새로 담는 이미지의 바이트가 안 넘어왔다. 부르는 쪽의 계약 위반이다.
    case imageDataMissing(imageID: UUID)
    /// 디스크 읽기·쓰기 실패. 갈래로 못 가르므로 원문을 그대로 들고 온다.
    case ioFailed(file: String, reason: String)
    /// 매니페스트를 읽었는데 형태가 다르다.
    case malformed(file: String, reason: String)
    /// 이 판보다 나중 형식으로 쓰인 기록이다.
    case unsupportedSchema(file: String, version: Int)

    /// 플랫폼 오류 → 도메인 오류. **번역은 이 한 자리뿐이다.**
    /// 경로는 마지막 조각만 남긴다 — 전체 경로는 개발 기기의 사용자 이름을 담는다.
    static func io(_ error: Error, at url: URL) -> RecordStoreError {
        .ioFailed(file: url.lastPathComponent, reason: String(describing: error))
    }

    var description: String {
        switch self {
        case .imageDataMissing(let id): "이미지 바이트 없음: \(id)"
        case .ioFailed(let file, let reason): "파일 실패: \(file) — \(reason)"
        case .malformed(let file, let reason): "형태가 다름: \(file) — \(reason)"
        case .unsupportedSchema(let file, let version): "읽을 수 없는 판 \(version): \(file)"
        }
    }
}

// MARK: - 디스크 형태

extension RecordStore {
    private static func encode(_ record: Record) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(StoredRecord(record))
        } catch {
            throw RecordStoreError.malformed(file: manifestName, reason: String(describing: error))
        }
    }

    private static func load(_ url: URL) throws -> Record {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw RecordStoreError.io(error, at: url)
        }
        let stored: StoredRecord
        do {
            stored = try JSONDecoder().decode(StoredRecord.self, from: data)
        } catch {
            throw RecordStoreError.malformed(file: url.lastPathComponent,
                                             reason: String(describing: error))
        }
        guard stored.schemaVersion <= schemaVersion else {
            throw RecordStoreError.unsupportedSchema(file: url.lastPathComponent,
                                                     version: stored.schemaVersion)
        }
        guard let record = stored.record else {
            throw RecordStoreError.malformed(file: url.lastPathComponent, reason: "값이 범위 밖")
        }
        return record
    }
}

/// 디스크에 적히는 형태.
///
/// ⚠️ **커널의 `WallClock`에 저장 형식을 얹지 않는다** — 그 공개 API는 다른 언어 구현이
/// 재현할 계약이다 (ADR `0002`).
private struct StoredRecord: Codable {
    var schemaVersion: Int
    var id: UUID
    /// `YYYYMMDDhhmmsscc` 16자리.
    var occurredAt: String
    var caption: String
    var status: String
    var updatedAt: Date
    var images: [StoredImage]

    init(_ record: Record) {
        schemaVersion = RecordStore.schemaVersion
        id = record.id
        occurredAt = record.occurredAt.stamp
        caption = record.caption
        status = record.status.rawValue
        updatedAt = record.updatedAt
        images = record.images.map(StoredImage.init)
    }

    /// 값이 범위 밖이면 `nil`.
    var record: Record? {
        guard let occurredAt = WallClock(stamp: occurredAt),
              let status = Record.Status(rawValue: status)
        else { return nil }
        let images = self.images.compactMap(\.image)
        guard images.count == self.images.count else { return nil }
        return Record(id: id, occurredAt: occurredAt, images: images,
                      caption: caption, status: status, updatedAt: updatedAt)
    }
}

private struct StoredImage: Codable {
    var id: UUID
    var fileExtension: String
    /// `source` 이면 아래 둘이 함께 있고, `imported` 면 둘 다 없다.
    var origin: String
    var assetID: String?
    var capturedAt: String?

    static let sourceOrigin = "source"
    static let importedOrigin = "imported"

    init(_ image: RecordImage) {
        id = image.id
        fileExtension = image.fileExtension
        switch image.origin {
        case .source(let assetID, let capturedAt):
            origin = Self.sourceOrigin
            self.assetID = assetID
            self.capturedAt = capturedAt.stamp
        case .imported:
            origin = Self.importedOrigin
        }
    }

    var image: RecordImage? {
        switch origin {
        case Self.sourceOrigin:
            guard let assetID, let capturedAt, let clock = WallClock(stamp: capturedAt)
            else { return nil }
            return RecordImage(id: id, fileExtension: fileExtension,
                               origin: .source(assetID: assetID, capturedAt: clock))
        case Self.importedOrigin:
            return RecordImage(id: id, fileExtension: fileExtension, origin: .imported)
        default:
            return nil
        }
    }
}

/// 저장용 16자리 표현.
///
/// ⚠️ **커널의 파일명 파서를 재사용하지 않는다** — 그쪽 계약은 *촬영 파일명* 이고, 빌려 쓰면
/// 파일명 규칙이 바뀔 때 저장 형식이 함께 움직인다.
private extension WallClock {
    var stamp: String {
        func pad(_ value: Int, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return pad(year, 4) + pad(month, 2) + pad(day, 2)
            + pad(hour, 2) + pad(minute, 2) + pad(second, 2) + pad(hundredth, 2)
    }

    init?(stamp: String) {
        let values = stamp.compactMap { character -> Int? in
            guard character.isASCII, let value = character.wholeNumberValue,
                  (0...9).contains(value) else { return nil }
            return value
        }
        guard values.count == 16, stamp.count == 16 else { return nil }
        func number(_ range: Range<Int>) -> Int {
            range.reduce(0) { $0 * 10 + values[$1] }
        }
        self.init(year: number(0..<4), month: number(4..<6), day: number(6..<8),
                  hour: number(8..<10), minute: number(10..<12), second: number(12..<14),
                  hundredth: number(14..<16))
    }
}
