// 출력 구조 — 날짜 → 순간 → 장면 → 사진.
//
// ⚠️ **읽기 전용이다** (원칙 `P1`) — 나누기·합치기·편집 API를 만들지 마라.
// 사진은 **입력 배열의 인덱스**로만 가리킨다. 커널에 식별자 개념이 없다.

/// 연달아 찍은 거의 같은 컷 하나의 묶음 (`MOM-04`). **1장짜리도 장면이다.**
public struct Scene: Sendable, Hashable {
    /// 촬영 시각 오름차순. 항상 1개 이상.
    public let photoIndices: [Int]

    /// **첫 컷**이다 — 결정적이고 값이 공짜다.
    public var representative: Int { photoIndices[0] }
    public var isFolded: Bool { photoIndices.count > 1 }
}

/// 시간이 연속되고 장소가 같은 사진 묶음. **항상 시간상 연속 구간이다** (`MOM-03`) —
/// 같은 장소로 돌아왔으면 새 순간이다.
public struct Moment: Sendable, Hashable {
    public let start: WallClock
    public let end: WallClock
    /// 촬영 시각 오름차순. 이어 붙이면 이 순간의 사진 전체다.
    public let scenes: [Scene]

    public var photoIndices: [Int] { scenes.flatMap(\.photoIndices) }
    public var photoCount: Int { scenes.reduce(0) { $0 + $1.photoIndices.count } }
    public var sceneCount: Int { scenes.count }
}

/// 하루치 순간들 (`MOM-05`). 자정을 넘겨 이어진 촬영은 전날에 붙는다 (`MOM-06`).
public struct Day: Sendable, Hashable {
    public let date: CalendarDay
    /// **최신 먼저.**
    public let moments: [Moment]

    public var photoCount: Int { moments.reduce(0) { $0 + $1.photoCount } }
}

/// 분류 결과 전체.
public struct Classification: Sendable, Hashable {
    /// **최신 먼저.**
    public let days: [Day]
    /// 입력과 **같은 길이·같은 순서**. 사진별로 무엇을 읽었고 무엇을 못 읽었는지.
    public let readings: [PhotoReading]
    /// 파일명에서 시각을 못 얻어 시간축에 놓지 못한 사진의 입력 인덱스. 오름차순.
    /// **제품 규칙은 여기 없다** — 커널은 사실만 준다.
    public let unplaced: [Int]

    public var photoCount: Int { days.reduce(0) { $0 + $1.photoCount } }
    public var momentCount: Int { days.reduce(0) { $0 + $1.moments.count } }
}
