// 기록 목록의 상태. `07`과 `08`이 함께 보고, 저장·삭제 뒤 다시 읽는 자리도 여기다.

import Foundation
import MomentKernel

/// 저장된 기록 전부를 들고 화면에 내주는 자리.
///
/// ⚠️ **순간을 모른다** (원칙 `P2`). 이 타입에 순간을 들이면 기록 목록이 분류 결과에 매이고,
/// 그 반대 방향(순간 목록이 기록을 아는 것)도 곧 따라온다.
@MainActor
@Observable
final class RecordLibrary {
    /// 발생일시 역순 (`ARC-01`). 순서는 저장소가 정한다.
    private(set) var records: [Record] = []
    /// 저장소를 못 읽었다. ⚠️ **삭제 실패는 여기 안 든다** — 그때는 카드가 그대로 남는 것이
    /// 이미 결과를 말한다.
    private(set) var loadFailed = false

    let store: RecordStore

    init(store: RecordStore) {
        self.store = store
    }

    /// `ARC-02` 월 구분.
    var months: [RecordMonth] { Self.months(of: records) }

    func reload() {
        do {
            records = try store.all()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    /// `ARC-07`. 지운 뒤 다시 읽는다 — 목록에서만 빼면 디스크가 실패했을 때 화면이 거짓말한다.
    func delete(id: UUID) {
        try? store.delete(id: id)
        reload()
    }

    /// 초안을 기록으로 올린다. 설명을 요구하지 않는다 — 초안 여부는 저장된 상태다.
    /// ⚠️ **바이트를 안 넘긴다** — 이미지가 전부 이 기록의 디렉터리에 있어 저장소가 건너뛴다.
    func publish(_ record: Record) {
        var published = record
        published.status = .published
        published.updatedAt = Date()
        try? store.save(published, imageData: [:])
        reload()
    }

    /// 한 달치 기록.
    struct RecordMonth: Identifiable, Hashable, Sendable {
        let year: Int
        let month: Int
        let records: [Record]

        var id: Int { year * 100 + month }
    }

    /// 이어진 같은 달끼리 묶는다. **정렬돼 들어온다는 것이 전제다.**
    /// ⚠️ **다시 정렬하지 않는다** — 순서는 `ARC-01`을 지는 저장소의 것이다.
    static func months(of records: [Record]) -> [RecordMonth] {
        var months: [RecordMonth] = []
        for record in records {
            let day = record.occurredAt.calendarDay
            if let last = months.last, last.year == day.year, last.month == day.month {
                months[months.count - 1] = RecordMonth(year: last.year, month: last.month,
                                                       records: last.records + [record])
            } else {
                months.append(RecordMonth(year: day.year, month: day.month, records: [record]))
            }
        }
        return months
    }
}
