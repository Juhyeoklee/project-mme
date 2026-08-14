// 작성 중인 기록. `09`와 `10`이 함께 보는 상태이고, 저장도 여기서 돈다.

import Foundation
import MomentKernel
import PhotoSource

/// 원본 바이트 한 장을 끌어오는 일. **주입 가능한 이음매다** — 프리뷰·테스트가 합성 바이트를 먹인다.
typealias OriginalBytesLoader = @Sendable (SourceAsset) async throws -> Data

/// 작성 중인 사진 한 장. 아직 기록이 아니다 — 저장 시점에 `RecordImage`가 된다.
struct DraftPhoto: Identifiable, Hashable, Sendable {
    let id: UUID
    let origin: Origin
    /// ⚠️ **뺀 것도 목록에 남는다.** 빼는 것은 삭제가 아니라 선택 해제라 되돌릴 수 있어야 한다.
    var isIncluded: Bool

    enum Origin: Hashable, Sendable {
        case source(asset: SourceAsset, capturedAt: WallClock)
        case imported(fileExtension: String)
        /// `ARC-06` — 이미 저장된 기록의 이미지. **바이트가 기록 디렉터리에 있어 다시 읽지
        /// 않는다**, 그래서 원본이 앨범에서 사라졌어도 고칠 수 있다.
        case stored(RecordImage)
    }

    var asset: SourceAsset? {
        if case .source(let asset, _) = origin { return asset }
        return nil
    }

    /// 소스 안에서 왔다는 표지. **`.stored`도 값을 갖는다** — 안 그러면 `10`이 이미 든 사진을
    /// 못 알아보고 같은 사진을 한 번 더 담는다.
    var assetID: String? {
        switch origin {
        case .source(let asset, _): asset.id
        case .stored(let image): image.assetID
        case .imported: nil
        }
    }

    /// 소스 안에서 온 사진만 값이 있다 — 가져온 사진의 촬영 정보는 읽지 않는다.
    var capturedAt: WallClock? {
        switch origin {
        case .source(_, let capturedAt): capturedAt
        case .stored(let image): image.capturedAt
        case .imported: nil
        }
    }

    /// 저장된 이미지면 그 자리를 아는 데 필요한 값.
    var storedImage: RecordImage? {
        if case .stored(let image) = origin { return image }
        return nil
    }
}

/// `09`가 편집 중인 기록.
///
/// **진입 직후 전부 선택돼 있고 사용자가 하는 일은 빼기뿐이다** — 빈 상태에서 고르게 하면
/// 이 제품이 없애기로 한 「고르기」 단계가 돌아온다.
///
/// ⚠️ **순간을 들고 있지 않다** (원칙 `P2`). 날짜와 시작 시각만 아는데, 그것도 `10`이
/// 후보를 세우고 「이 순간」 꼬리를 다는 데만 쓴다.
@MainActor
@Observable
final class RecordDraft: Identifiable {
    /// 저장이 어디까지 갔는가. **실패는 화면 상태다** — 저장소는 `throws`로 말하고 여기서 받는다.
    ///
    /// ⚠️ **실패가 이유를 나르지 않는다** — 사용자가 고칠 수 없어 화면이 왜인지 말하지 않기로
    /// 했고(`Wording.saveFailed`), 아무도 안 읽는 값을 실으면 갈래가 있는 척만 하게 된다.
    /// 갈래를 구별해야 할 이유가 생기면 그때 `RecordStoreError`를 그대로 싣는다.
    enum SaveState: Equatable {
        case editing
        case saving
        case failed

        var isFailed: Bool { if case .failed = self { true } else { false } }
    }

    /// 저장이 두 번 돌아도 같은 기록이다. **고치러 들어오면 그 기록의 것을 그대로 쓴다** —
    /// 새로 뽑으면 같은 기록이 둘로 늘어난다 (`ARC-06`).
    let id: UUID
    /// `10`의 후보 범위.
    let day: CalendarDay
    /// 이 기록이 시작된 자리의 시각. 날짜에서 시작하면 그 날 가장 이른 순간의 시작이다.
    let start: WallClock
    /// 「이 순간」 꼬리를 다는가. **날짜에서 시작하면 가리킬 순간이 없다.**
    let startsFromMoment: Bool

    private(set) var photos: [DraftPhoto]
    var caption = ""
    private(set) var occurredAt: WallClock
    private(set) var saveState: SaveState = .editing

    /// `REC-10`으로 가져온 바이트. 저장 전까지 메모리에만 산다.
    private var importedData: [UUID: Data] = [:]
    /// 사용자가 발생일시를 직접 고쳤나. 고친 뒤에는 사진이 바뀌어도 자동 계산이 덮지 않는다.
    private var occurredAtIsManual = false

    init(id: UUID = UUID(), day: CalendarDay, start: WallClock, startsFromMoment: Bool,
         photos: [DraftPhoto], caption: String = "", occurredAt: WallClock? = nil) {
        self.id = id
        self.day = day
        self.start = start
        self.startsFromMoment = startsFromMoment
        self.photos = photos
        self.caption = caption
        self.occurredAt = occurredAt ?? Self.automaticOccurredAt(of: photos) ?? start
        // ⚠️ **고치러 들어오면 자동 계산이 다시 돌지 않는다** — 사용자가 저장된 값을 이미 봤고,
        // 사진 한 장을 빼는 것만으로 그 값이 조용히 바뀌는 것이 안전한 실패 방향이 아니다.
        self.occurredAtIsManual = occurredAt != nil
    }

    // MARK: - 화면이 보는 것

    var included: [DraftPhoto] { photos.filter(\.isIncluded) }
    var removedCount: Int { photos.count - included.count }
    /// 사진 0장인 기록은 만들 수 없다.
    var canSave: Bool { !included.isEmpty && saveState != .saving }

    /// `10`이 「이미 든 사진」을 또렷하게 그릴 때 본다.
    var includedAssetIDs: Set<String> {
        Set(included.compactMap(\.assetID))
    }

    // MARK: - 편집

    /// `09-G1` 타일 탭 — 빼기와 다시 넣기의 토글이다.
    func toggle(_ id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isIncluded.toggle()
        refreshOccurredAt()
    }

    /// `10` 확정 — 소스 안 사진의 담김 상태를 통째로 맞춘다.
    /// 이미 있던 사진은 자리를 지키고 **새로 든 것만 끝에 붙는다.**
    func apply(includedAssets: Set<String>, candidates: [DraftPhoto]) {
        for index in photos.indices {
            guard let assetID = photos[index].assetID else { continue }
            photos[index].isIncluded = includedAssets.contains(assetID)
        }
        let known = Set(photos.compactMap(\.assetID))
        for candidate in candidates {
            guard let assetID = candidate.asset?.id,
                  includedAssets.contains(assetID), !known.contains(assetID) else { continue }
            photos.append(candidate)
        }
        refreshOccurredAt()
    }

    /// `REC-10` — 사용자가 시스템 피커로 지목한 한 장. 목록 끝에 붙는다.
    func addImported(_ data: Data, fileExtension: String) {
        let photo = DraftPhoto(id: UUID(), origin: .imported(fileExtension: fileExtension),
                               isIncluded: true)
        photos.append(photo)
        importedData[photo.id] = data
    }

    /// 가져온 사진의 바이트. 화면이 그리는 데도 쓴다.
    func importedData(of id: UUID) -> Data? { importedData[id] }

    /// 실패를 사용자가 확인했다. 되돌아가는 곳은 편집 상태다 — 만들던 것은 그대로 있다.
    func clearFailure() {
        guard saveState.isFailed else { return }
        saveState = .editing
    }

    /// `REC-07` — 사용자가 고친다. 이후로는 자동 계산이 이 값을 덮지 않는다.
    func setOccurredAt(_ clock: WallClock) {
        occurredAt = clock
        occurredAtIsManual = true
    }

    // MARK: - 저장

    /// 기록을 만들어 저장한다. 성공하면 그 기록, 실패하면 `nil`이고 `saveState`가 실패를 든다.
    /// ⚠️ **여기서 원본 바이트를 처음 요구하고 네트워크를 연다** — `R8`이 사는 자리다.
    func save(status: Record.Status, to store: RecordStore,
              bytes: @escaping OriginalBytesLoader) async -> Record? {
        guard canSave else { return nil }
        saveState = .saving

        var images: [RecordImage] = []
        var data: [UUID: Data] = [:]
        for photo in included {
            switch photo.origin {
            case .source(let asset, let capturedAt):
                guard let loaded = try? await bytes(asset) else {
                    saveState = .failed
                    return nil
                }
                data[photo.id] = loaded
                images.append(RecordImage(id: photo.id,
                                          fileExtension: Self.fileExtension(of: asset.filename),
                                          origin: .source(assetID: asset.id, capturedAt: capturedAt)))
            case .imported(let fileExtension):
                guard let loaded = importedData[photo.id] else {
                    saveState = .failed
                    return nil
                }
                data[photo.id] = loaded
                images.append(RecordImage(id: photo.id, fileExtension: fileExtension,
                                          origin: .imported))
            case .stored(let image):
                // 바이트는 이미 이 기록의 디렉터리에 있다. 저장소가 있는 파일을 건너뛴다.
                images.append(image)
            }
        }

        let record = Record(id: id, occurredAt: occurredAt, images: images,
                            caption: caption, status: status, updatedAt: Date())
        do {
            try store.save(record, imageData: data)
        } catch {
            saveState = .failed
            return nil
        }
        saveState = .editing
        return record
    }

    // MARK: - 조각

    /// `REC-07` 자동값 — **소스 안 사진의 가장 이른 촬영시각.** 가져온 사진은 참여하지 않는다.
    static func automaticOccurredAt(of photos: [DraftPhoto]) -> WallClock? {
        photos.filter(\.isIncluded).compactMap(\.capturedAt).min()
    }

    private func refreshOccurredAt() {
        guard !occurredAtIsManual, let automatic = Self.automaticOccurredAt(of: photos) else { return }
        occurredAt = automatic
    }

    private static func fileExtension(of filename: String) -> String {
        let suffix = URL(fileURLWithPath: filename).pathExtension.lowercased()
        return suffix.isEmpty ? "png" : suffix
    }
}

extension RecordDraft {
    /// 순간 하나에서 시작한다 (`REC-01`). **연사는 대표 한 장만 담긴다** (`REC-03`).
    static func from(moment: Moment, day: CalendarDay, library: MomentLibrary) -> RecordDraft {
        RecordDraft(day: day, start: moment.start, startsFromMoment: true,
                    photos: photos(at: moment.scenes.map(\.representative), library: library))
    }

    /// 날짜 하나에서 시작한다 (`REC-02`) — 그 날 **모든 순간**의 사진이 대상이다.
    /// ⚠️ 순간 목록은 최신 먼저라 **뒤집어 담는다** — 사진은 시간 오름차순으로 놓인다.
    static func from(day: Day, library: MomentLibrary) -> RecordDraft? {
        guard let earliest = day.moments.last else { return nil }
        let indices = day.moments.reversed().flatMap { $0.scenes.map(\.representative) }
        return RecordDraft(day: day.date, start: earliest.start, startsFromMoment: false,
                           photos: photos(at: indices, library: library))
    }

    /// `ARC-06` — 이미 저장된 기록을 고치러 들어간다. 신원과 사진과 설명을 그대로 싣는다.
    static func editing(_ record: Record) -> RecordDraft {
        RecordDraft(id: record.id,
                    day: record.occurredAt.calendarDay,
                    start: record.occurredAt,
                    // 「이 순간」 꼬리를 달 자리가 없다 — 기록은 순간을 모른다 (원칙 `P2`).
                    startsFromMoment: false,
                    photos: record.images.map {
                        DraftPhoto(id: $0.id, origin: .stored($0), isIncluded: true)
                    },
                    caption: record.caption,
                    occurredAt: record.occurredAt)
    }

    /// 커널 인덱스를 화면이 다루는 사진으로 옮긴다. 시각을 못 얻은 사진은 애초에 순간에 없다.
    static func photos(at indices: [Int], library: MomentLibrary) -> [DraftPhoto] {
        indices.compactMap { index in
            guard let asset = library.asset(at: index),
                  let capturedAt = library.capturedAt(at: index) else { return nil }
            return DraftPhoto(id: UUID(),
                              origin: .source(asset: asset, capturedAt: capturedAt),
                              isIncluded: true)
        }
    }
}
