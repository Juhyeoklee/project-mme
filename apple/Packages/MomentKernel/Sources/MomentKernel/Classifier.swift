// 분류 — 커널의 본체.

/// 임계값. 근거 원문은 실험 두 편(`ios-album` · `burst-signal`)과 커밋 `0b9d9f7`.
public struct Settings: Sendable, Hashable {
    /// `MOM-01`. 평탄 구간 10~30분의 위끝 — **덜 쪼개는 쪽이 안전한 실패 방향**이다.
    public var momentGapSeconds: Int

    /// `MOM-02` — 같은 구역 안에서 장소를 가르는 카메라 위치 거리.
    /// **판정 단위는 인접쌍이 아니라 군집이다** (인접쌍은 메타값 좌표에서도 실패했다).
    /// 60은 기준 A 실기기 전량 판정으로 확정했다 (2026-08-04 · 커밋 `0b9d9f7`).
    public var placeClusterDistance: Double

    /// `MOM-04`. 시선이 같은 쌍의 pHash 거리가 여기서 꺾인다.
    public var burstGapSeconds: Double
    /// 아래 회전·화각과 함께 실험의 「시선이 같다」 정의 그대로다.
    public var burstCameraDistance: Double
    public var burstAngleDegrees: Double
    /// 정확히 같기를 요구하면 부동소수에 취약하다.
    public var burstFieldOfViewTolerance: Double

    /// `MOM-06`. 표본에서 촬영이 3~5시에 비고 6시대에 아침 플레이가 있다 — 4시가 그 골이다
    /// (2026-08-03 세션 관측. 실험 문서에는 없다).
    public var dayCutoffHour: Int

    public init(momentGapSeconds: Int = 1800,
                placeClusterDistance: Double = 60,
                burstGapSeconds: Double = 10,
                burstCameraDistance: Double = 1.0,
                burstAngleDegrees: Double = 2.0,
                burstFieldOfViewTolerance: Double = 0.01,
                dayCutoffHour: Int = 4) {
        self.momentGapSeconds = momentGapSeconds
        self.placeClusterDistance = placeClusterDistance
        self.burstGapSeconds = burstGapSeconds
        self.burstCameraDistance = burstCameraDistance
        self.burstAngleDegrees = burstAngleDegrees
        self.burstFieldOfViewTolerance = burstFieldOfViewTolerance
        self.dayCutoffHour = dayCutoffHour
    }

    public static let `default` = Settings()
}

/// `MomentKernel`의 입구. **(파일명, 바이트) 컬렉션 → 날짜·순간·장면 구조.**
///
/// 순수 함수다 — 상태도 부작용도 없고, 플랫폼·시간대·로케일을 모른다 (ADR `0001` 결정 2·5).
/// 같은 사진 집합이면 어느 기기에서든 같은 결과가 나온다 (`MOM-07` · 약속 `C5`).
public enum Classifier {
    /// 사진 집합을 날짜·순간·장면으로 분류한다.
    ///
    /// **부분 입력 계약** (ADR `0004` 결정 2) — 바이트 없는 사진은 **시각만** 갖고 시간 경계에만
    /// 참여한다. 출력은 **입력 집합만의 함수**다 (`MOM-07` · 약속 `C5`).
    ///
    /// ⚠️ 바이트를 채워 다시 부르면 **장소 경계는 재계산된다 — 순간이 합쳐질 수도 있다**
    /// (ADR `0011`). 군집이 사슬로 이어지기 때문이다. **시간 경계와 순서만 안 바뀐다.**
    ///
    /// ⚠️ **전제** — `App`은 1패스에 자산을 **전량 열거해 전부** 넘긴다. 기계가 못 막는다.
    public static func classify(_ inputs: [PhotoInput],
                                settings: Settings = .default) -> Classification {
        let readings = inputs.map { SignalReader.read($0) }

        var placed: [Placed] = []
        var unplaced: [Int] = []
        for (index, reading) in readings.enumerated() {
            if let at = reading.capturedAt {
                placed.append(Placed(index: index, at: at,
                                     filename: inputs[index].filename,
                                     signals: reading.signals))
            } else {
                unplaced.append(index)
            }
        }

        // ⚠️ 동시각이면 파일명, 그것도 같으면 인덱스 — 입력 순서를 타면 `MOM-07`이 깨진다.
        placed.sort {
            if $0.at != $1.at { return $0.at < $1.at }
            if $0.filename != $1.filename { return $0.filename < $1.filename }
            return $0.index < $1.index
        }

        var moments: [Moment] = []
        for run in splitByTimeGap(placed, seconds: settings.momentGapSeconds) {
            for segment in splitByPlace(run, distance: settings.placeClusterDistance) {
                moments.append(Moment(start: segment[0].at,
                                      end: segment[segment.count - 1].at,
                                      scenes: foldBursts(segment, settings: settings)))
            }
        }

        return Classification(days: groupIntoDays(moments, cutoffHour: settings.dayCutoffHour),
                              readings: readings,
                              unplaced: unplaced)
    }

    // MARK: - 내부

    struct Placed {
        let index: Int
        let at: WallClock
        let filename: String
        let signals: CaptureSignals?
    }

    /// `MOM-01` — 촬영 시간이 크게 벌어지는 지점에서 나눈다.
    static func splitByTimeGap(_ items: [Placed], seconds: Int) -> [[Placed]] {
        guard !items.isEmpty else { return [] }
        let limit = seconds * 100
        var runs: [[Placed]] = [[items[0]]]
        for item in items.dropFirst() {
            let previous = runs[runs.count - 1].last!
            if item.at.centiseconds - previous.at.centiseconds > limit {
                runs.append([item])
            } else {
                runs[runs.count - 1].append(item)
            }
        }
        return runs
    }

    /// `MOM-02` `MOM-03` — 순간이 **시간상 연속 구간**으로 남아야 하므로, 군집으로 라벨을 얻고
    /// 시간 순서에서 라벨이 바뀌는 자리를 자른다. A→B→A면 순간 3개다.
    static func splitByPlace(_ run: [Placed], distance: Double) -> [[Placed]] {
        guard run.count > 1 else { return run.isEmpty ? [] : [run] }
        let labels = placeLabels(run, distance: distance)

        var segments: [[Placed]] = []
        var current: [Placed] = []
        var lastKnown: Int?
        for (position, item) in run.enumerated() {
            if let label = labels[position] {
                if let known = lastKnown, known != label, !current.isEmpty {
                    segments.append(current)
                    current = []
                }
                lastKnown = label
            }
            // 신호가 없으면 경계를 만들지 않는다 — 안 나누는 쪽이 안전한 실패 방향이다.
            current.append(item)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    /// 장소 라벨. 신호가 없으면 `nil`.
    ///
    /// **구역 이름이 하드 파티션이다** — 카메라 좌표계가 구역마다 별개라(2026-08-03 측정)
    /// 전역 거리로만 재면 다른 구역이 우연히 가까워질 수 있다.
    static func placeLabels(_ run: [Placed], distance: Double) -> [Int?] {
        // ⚠️ 처음 나온 순서로 모은다 — `Dictionary` 순회는 결정적이지 않다.
        var zoneOrder: [String] = []
        var positionsByZone: [String: [Int]] = [:]
        for (position, item) in run.enumerated() {
            guard let zone = item.signals?.zoneName else { continue }
            if positionsByZone[zone] == nil {
                zoneOrder.append(zone)
                positionsByZone[zone] = []
            }
            positionsByZone[zone]!.append(position)
        }

        var labels = [Int?](repeating: nil, count: run.count)
        var nextLabel = 0
        for zone in zoneOrder {
            let positions = positionsByZone[zone]!
            let points = positions.map { run[$0].signals!.cameraPosition }
            let clusters = averageLinkageClusters(points, threshold: distance)
            let base = nextLabel
            var used = 0
            for (offset, position) in positions.enumerated() {
                labels[position] = base + clusters[offset]
                used = max(used, clusters[offset] + 1)
            }
            nextLabel = base + used
        }
        return labels
    }

    /// 평균 연결(UPGMA) 병합 군집. 반환값은 점마다의 군집 번호.
    ///
    /// **다른 언어 구현이 같은 결과를 내야 하므로 갱신식과 병합 순서를 못 박는다** (`MOM-07`) —
    /// 거리 갱신은 Lance-Williams `d(A∪B,C) = (|A|·d(A,C) + |B|·d(B,C)) / (|A|+|B|)`,
    /// **동률이면 첨자가 작은 쌍**을 먼저 합치고, 군집 번호는 **가장 작은 구성원의 첨자 순서**로.
    /// 순간 하나가 작아(표본 최대 26장) 단순한 O(n³)로 충분하다.
    static func averageLinkageClusters(_ points: [Vector3], threshold: Double) -> [Int] {
        let n = points.count
        guard n > 1 else { return n == 1 ? [0] : [] }

        var distances = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let value = points[i].distance(to: points[j])
                distances[i][j] = value
                distances[j][i] = value
            }
        }

        var alive = [Bool](repeating: true, count: n)
        var size = [Int](repeating: 1, count: n)
        var representative = Array(0..<n)

        while true {
            var best: (value: Double, a: Int, b: Int)?
            for i in 0..<n where alive[i] {
                for j in (i + 1)..<n where alive[j] {
                    if best == nil || distances[i][j] < best!.value {
                        best = (distances[i][j], i, j)
                    }
                }
            }
            guard let best, best.value <= threshold else { break }

            let (a, b) = (best.a, best.b)
            let (sizeA, sizeB) = (size[a], size[b])
            for c in 0..<n where alive[c] && c != a && c != b {
                let merged = (Double(sizeA) * distances[a][c] + Double(sizeB) * distances[b][c])
                           / Double(sizeA + sizeB)
                distances[a][c] = merged
                distances[c][a] = merged
            }
            size[a] = sizeA + sizeB
            alive[b] = false
            for k in 0..<n where representative[k] == b { representative[k] = a }
        }

        var labelOf: [Int: Int] = [:]
        var next = 0
        var result = [Int](repeating: 0, count: n)
        for k in 0..<n {
            let root = representative[k]
            if let label = labelOf[root] {
                result[k] = label
            } else {
                labelOf[root] = next
                result[k] = next
                next += 1
            }
        }
        return result
    }

    /// `MOM-04` — 화면에 무엇이 담기는지는 **카메라 자세 + 화각 + 종횡비**가 정한다.
    /// 신호가 없으면 안 접는다 — **접으면 사진이 숨겨지므로** 그쪽이 안전한 실패 방향이다.
    static func foldBursts(_ segment: [Placed], settings: Settings) -> [Scene] {
        guard !segment.isEmpty else { return [] }
        var scenes: [[Int]] = [[segment[0].index]]
        for position in 1..<segment.count {
            if isBurst(segment[position - 1], segment[position], settings: settings) {
                scenes[scenes.count - 1].append(segment[position].index)
            } else {
                scenes.append([segment[position].index])
            }
        }
        return scenes.map { Scene(photoIndices: $0) }
    }

    static func isBurst(_ a: Placed, _ b: Placed, settings: Settings) -> Bool {
        guard let first = a.signals, let second = b.signals else { return false }
        let gap = Double(b.at.centiseconds - a.at.centiseconds) / 100
        return gap <= settings.burstGapSeconds
            && first.cameraPosition.distance(to: second.cameraPosition) <= settings.burstCameraDistance
            && first.cameraRotation.angularDistance(to: second.cameraRotation) <= settings.burstAngleDegrees
            && (first.fieldOfView - second.fieldOfView).magnitude <= settings.burstFieldOfViewTolerance
            && first.hasSameAspectRatio(as: second)
    }

    /// `MOM-05` `MOM-06` — 날짜는 **순간의 첫 사진** 시각으로 정한다. 순간이 시간상
    /// 연속 구간이므로(`MOM-03`) 한 순간이 두 날짜로 찢어지지 않는다.
    static func groupIntoDays(_ moments: [Moment], cutoffHour: Int) -> [Day] {
        var order: [CalendarDay] = []
        var byDate: [CalendarDay: [Moment]] = [:]
        for moment in moments {
            let date = moment.start.calendarDay(shiftedBackBy: cutoffHour)
            if byDate[date] == nil {
                order.append(date)
                byDate[date] = []
            }
            byDate[date]!.append(moment)
        }
        // `moments`가 시각 오름차순이므로 뒤집으면 최신 먼저가 된다.
        return order.reversed().map { date in
            Day(date: date, moments: byDate[date]!.reversed())
        }
    }
}
