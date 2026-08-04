// 분류 — (파일명, 바이트) 컬렉션 → 날짜·순간·장면 구조.
//
// 순수 함수다. 상태도 부작용도 없고, 플랫폼도 시간대도 로케일도 모른다 (ADR 0001 결정 2·5).

/// 임계값. **기준 A(실기기 212장 전량 분류, 2026-08-04)로 확정했다.**
/// 근거는 `docs/experiments/ios-album-2026-08.md`와 `burst-signal-2026-08.md`,
/// 그리고 그 위에 얹힌 기준 A 판정 — 아래 `placeClusterDistance` 주석.
public struct Settings: Sendable, Hashable {
    /// 순간을 자르는 시간 간격 (`MOM-01`). 실험 §5.1의 평탄 구간은 10~30분이고,
    /// 5분은 26장짜리 순간을 11장으로 부순다. **덜 쪼개는 쪽이 안전한 실패 방향**이라 위끝을 잡았다.
    public var momentGapSeconds: Int

    /// 같은 구역 안에서 장소를 가르는 카메라 위치 거리 (`MOM-02`).
    /// **판정 단위는 인접쌍이 아니라 군집이다** — 인접쌍 임계값은 메타값 좌표에서도 실패했다(§4.3).
    ///
    /// **20 → 60. 기준 A가 올렸다** (2026-08-04). 실험 §5.2가 고른 20은 평탄 구간 20~25의
    /// 아래끝인데, 그 구간은 **정답 라벨이 있는 유일한 데이터인 Windows 34장** 위에서 잰 것이고
    /// 실험 스스로 한계에 *"정답을 보고 골랐다 · 과적합 위험 · 카메라 쪽 평탄 구간이 좁다"* 를
    /// 적어뒀다. iOS 212장을 사람이 훑은 결과 **거슬린 경계 2건이 나왔고 둘 다 이 값 때문**이었다
    /// (같은 구역 안에서 카메라 거리 29.1·54.7로 갈린 자리).
    ///
    /// 60을 고른 근거는 데이터의 골이다. 구역 내 분할 9자리의 거리가
    /// `29.1 · 37.6 · 38.1 · 54.7 · 54.7 ┊ 76.7 · 140.8 · 160.9 · 273.7` 로 벌어져 있어
    /// **56~76이 평탄 구간(1.35배)** 이고, 원래 값의 근거였던 20~25(1.25배)보다 넓다.
    /// 이 값에서 212장의 순간이 104 → 99가 되고, 덤으로 합쳐지는 3자리는 사람이 보고 승인했다.
    public var placeClusterDistance: Double

    /// 연사로 묶는 최대 시간 간격 (`MOM-04`). 시선이 같은 쌍의 pHash 거리가 여기서 꺾인다.
    public var burstGapSeconds: Double
    /// 연사로 묶는 최대 카메라 위치 이동.
    public var burstCameraDistance: Double
    /// 연사로 묶는 최대 카메라 회전(도).
    public var burstAngleDegrees: Double
    /// 화각이 "같다"고 볼 오차. 정확히 같기를 요구하면 부동소수에 취약하다.
    public var burstFieldOfViewTolerance: Double

    /// 새벽 컷오프 (`MOM-06`). 이 시각 전의 순간은 전날에 붙는다.
    /// 표본에서 촬영이 3~5시에 비고 6시대에 아침 플레이가 있다 — 4시가 그 골이다.
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

public enum Classifier {
    /// 사진 집합을 날짜·순간·장면으로 분류한다.
    ///
    /// ## 부분 입력 계약
    ///
    /// **바이트는 없어도 된다.** `R8` 실측이 로컬 먼저 훑는 2패스를 정당화했고, 그때
    /// 파일명은 1패스에 전량 들어온다. 그래서 —
    ///
    /// 1. 바이트 없는 사진은 **시각만** 갖는다. 날짜와 순간의 **시간 경계에는 온전히 참여**하고,
    ///    장소 분할과 연사 접기에는 참여하지 않는다
    /// 2. 출력은 **입력 집합만의 함수**다. 몇 번째 호출인지도, 직전에 무엇을 반환했는지도
    ///    모른다 (`MOM-07` · 약속 `C5`). 그래서 기기가 달라도 같은 결과가 나온다
    ///
    /// 이 둘에서 **약속이 아니라 귀결로** 따라오는 성질이 있다 —
    ///
    /// > 같은 사진 집합에 바이트만 채워 다시 부르면, 순간은 **더 잘게 쪼개질 뿐**
    /// > 합쳐지거나 순서가 바뀌지 않는다.
    ///
    /// 시간 경계는 파일명만으로 이미 확정됐고 장소는 그 안을 나누기만 하기 때문이다.
    /// 화면 `04`의 행이 2패스 도중 재배치되지 않는다는 뜻이다.
    ///
    /// **전제가 하나 붙는다** — `App`은 1패스에 자산을 **전량 열거해 전부** 넘겨야 한다.
    /// 일부만 넘기고 나중에 사진을 추가하면 이 성질은 성립하지 않는다.
    /// (장면은 반대 방향이다. 바이트가 채워지면 연사가 접혀 장면 수가 줄 수 있다.)
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

        // 시각 오름차순. 동시각이면 파일명으로 가른다 — **입력 순서를 타지 않기 위해서다**.
        // 인덱스는 파일명까지 같은, 구조적으로 구별할 수 없는 경우의 마지막 안전장치다.
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

    // MARK: 내부

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

    /// `MOM-02` `MOM-03` — 장소가 바뀌면 더 나누되, 순간은 **시간상 연속 구간**으로 남는다.
    /// 그래서 군집으로 라벨을 얻고, 시간 순서에서 라벨이 바뀌는 자리를 자른다.
    /// A→B→A면 순간 3개다.
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
            // 신호가 없는 사진은 경계를 만들지 않는다. 안 나누는 쪽이 안전한 실패 방향이다.
            current.append(item)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    /// 장소 라벨. 신호가 없으면 `nil`.
    ///
    /// **구역 이름이 하드 파티션이다.** 카메라 좌표계가 구역마다 별개라(측정 2026-08-03:
    /// 던바튼 중심 `<-17,88,-27>` 반경 204 · 이멘마하 `<43,42,16>` 반경 200) 전역 거리로만
    /// 재면 다른 구역이 우연히 가까워질 수 있다. 이름으로 먼저 가르면 그 구멍이 닫힌다.
    static func placeLabels(_ run: [Placed], distance: Double) -> [Int?] {
        // 구역 이름을 **처음 나온 순서**로 모은다. Dictionary 순회는 결정적이지 않다.
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
    /// 매 단계 가장 가까운 쌍을 합치되 **동률이면 첨자가 작은 쌍**을 먼저 합친다.
    /// 군집 번호는 **가장 작은 구성원의 첨자 순서**로 매긴다.
    ///
    /// 순간 하나의 크기가 작아(표본 최대 26장) 단순한 O(n³)로 충분하다.
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

    /// `MOM-04` — 연달아 찍은 거의 같은 컷을 접는다.
    ///
    /// 화면에 무엇이 담기는지를 결정하는 것은 **카메라 자세 + 화각 + 종횡비**다. 신호가 없는
    /// 사진은 접히지 않는다 — **접으면 사진이 숨겨지므로** 안 접는 쪽이 안전한 실패 방향이다.
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

    /// `MOM-05` `MOM-06` — 순간을 날짜로 묶는다. 날짜는 **순간의 첫 사진** 시각으로 정한다.
    /// 순간이 시간상 연속 구간이므로(`MOM-03`) 한 순간이 두 날짜로 찢어지지 않는다.
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
