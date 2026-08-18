import Testing
@testable import MomentKernel

/// 픽스처를 짧게 쓰기 위한 도우미. `stamp`는 `YYYYMMDDHHMMSSff`.
private func photo(_ stamp: String,
                   zone: String = "던바튼",
                   position: (Double, Double, Double) = (0, 0, 0),
                   rotation: (Double, Double, Double) = (0, 0, 0),
                   fieldOfView: Double = 62.9,
                   size: (Int, Int) = (1600, 738),
                   withBytes: Bool = true) -> PhotoInput {
    PhotoInput(filename: captureName(stamp),
               bytes: withBytes ? PNGFixture.capture(width: size.0, height: size.1,
                                                     zone: zone,
                                                     cameraPosition: position,
                                                     cameraRotation: rotation,
                                                     fieldOfView: fieldOfView) : nil)
}

private extension Classification {
    /// 모든 순간을 시간 오름차순으로 편다. 날짜 묶음을 신경 쓰지 않는 검사용.
    var allMoments: [Moment] {
        days.reversed().flatMap { $0.moments.reversed() }
    }
}

@Suite("분류")
struct ClassifierTests {

    // MARK: - 시간

    @Test func 빈_입력은_빈_결과다() {
        let result = Classifier.classify([])
        #expect(result.days.isEmpty)
        #expect(result.unplaced.isEmpty)
        #expect(result.readings.isEmpty)
    }

    @Test func 시간이_크게_벌어지면_순간이_갈린다() {
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213100000"),   // +10분 — 같은 순간
            photo("2026080214000000"),   // +50분 — 새 순간
        ])
        #expect(result.momentCount == 2)
        #expect(result.allMoments.map(\.photoCount) == [2, 1])
    }

    @Test func 임계값_경계에서는_붙는_쪽이다() {
        // 정확히 30분은 같은 순간, 30분 + 1/100초는 새 순간.
        #expect(Classifier.classify([photo("2026080213000000"),
                                     photo("2026080213300000")]).momentCount == 1)
        #expect(Classifier.classify([photo("2026080213000000"),
                                     photo("2026080213300001")]).momentCount == 2)
    }

    @Test func 순간의_시작과_끝이_첫_사진과_마지막_사진이다() {
        let result = Classifier.classify([photo("2026080213000000"),
                                          photo("2026080213052500")])
        let moment = result.allMoments[0]
        #expect(moment.start == WallClock.fromCaptureFilename(captureName("2026080213000000")))
        #expect(moment.end == WallClock.fromCaptureFilename(captureName("2026080213052500")))
    }

    // MARK: - 장소

    @Test func 같은_순간_안에서_장소가_바뀌면_더_나눈다() {
        let result = Classifier.classify([
            photo("2026080213000000", position: (0, 0, 0)),
            photo("2026080213010000", position: (1, 0, 0)),
            photo("2026080213020000", position: (500, 0, 0)),   // 멀리 갔다
        ])
        #expect(result.momentCount == 2)
        #expect(result.allMoments.map(\.photoCount) == [2, 1])
    }

    @Test func 돌아오면_새_순간이다() {
        // `MOM-03` — A→B→A는 순간 3개다. 표본에 실제로 있었다(실험 §5.5).
        let result = Classifier.classify([
            photo("2026080213000000", position: (0, 0, 0)),
            photo("2026080213010000", position: (0, 0, 0)),
            photo("2026080213020000", position: (500, 0, 0)),
            photo("2026080213030000", position: (0, 0, 0)),
        ])
        #expect(result.momentCount == 3)
        #expect(result.allMoments.map(\.photoCount) == [2, 1, 1])
    }

    @Test func 구역_이름이_다르면_좌표가_같아도_갈린다() {
        // 좌표계가 구역마다 별개다. 이름이 하드 파티션이라 거리 0이어도 안 합친다.
        let result = Classifier.classify([
            photo("2026080213000000", zone: "포토부스", position: (0, 0, 0)),
            photo("2026080213010000", zone: "반호르", position: (0, 0, 0)),
        ])
        #expect(result.momentCount == 2)
    }

    @Test func 판정_단위가_인접쌍이_아니라_군집이다() {
        // 네 점을 임계값의 0.75배씩 벌린다. 인접쌍 판정이면 한 덩어리지만(간격 < 임계값)
        // 평균 연결은 양 끝이 세 걸음 떨어진 것을 본다.
        let step = Settings.default.placeClusterDistance * 0.75
        let result = Classifier.classify((0..<4).map { index in
            photo(String(format: "20260802130%d0000", index),
                  position: (step * Double(index), 0, 0))
        })
        #expect(result.momentCount == 2)
        #expect(result.allMoments.map(\.photoCount) == [2, 2])
    }

    @Test func 가까운_것끼리는_한_장소로_남는다() {
        let result = Classifier.classify([
            photo("2026080213000000", position: (0, 0, 0)),
            photo("2026080213010000", position: (3, 4, 0)),     // 거리 5
            photo("2026080213020000", position: (0, 0, 6)),
        ])
        #expect(result.momentCount == 1)
    }

    // MARK: - 연사

    @Test func 시선이_같고_10초_안이면_한_장면으로_접힌다() {
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213000800"),   // +8초
            photo("2026080213001500"),   // +7초
        ])
        #expect(result.momentCount == 1)
        #expect(result.allMoments[0].sceneCount == 1)
        #expect(result.allMoments[0].scenes[0].photoIndices == [0, 1, 2])
        #expect(result.allMoments[0].scenes[0].isFolded)
    }

    @Test func 대표_컷은_첫_컷이다() {
        let result = Classifier.classify([photo("2026080213000000"), photo("2026080213000300")])
        #expect(result.allMoments[0].scenes[0].representative == 0)
    }

    @Test func 한_장짜리도_장면이지만_접힌_것은_아니다() {
        let result = Classifier.classify([photo("2026080213000000")])
        let scene = result.allMoments[0].scenes[0]
        #expect(scene.photoIndices == [0])
        #expect(!scene.isFolded)
        #expect(scene.representative == 0)
    }

    @Test func 시간이_벌어지면_같은_시선이어도_안_접힌다() {
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213001100"),   // +11초
        ])
        #expect(result.allMoments[0].sceneCount == 2)
    }

    @Test(arguments: [
        ("카메라가 움직였다", (2.0, 0.0, 0.0), (0.0, 0.0, 0.0), 62.9, (1600, 738)),
        ("카메라가 돌았다", (0.0, 0.0, 0.0), (0.0, 5.0, 0.0), 62.9, (1600, 738)),
        ("화각이 바뀌었다", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 26.9, (1600, 738)),
        ("세로로 돌렸다", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 62.9, (738, 1600)),
    ])
    func 시선이_달라지면_안_접힌다(_ testCase: (String, (Double, Double, Double),
                                        (Double, Double, Double), Double, (Int, Int))) {
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213000300", position: testCase.1, rotation: testCase.2,
                  fieldOfView: testCase.3, size: testCase.4),
        ])
        #expect(result.allMoments[0].sceneCount == 2, "\(testCase.0)")
    }

    @Test func 회전이_360도를_넘어가도_같은_시선으로_본다() {
        let result = Classifier.classify([
            photo("2026080213000000", rotation: (0, 359.5, 0)),
            photo("2026080213000300", rotation: (0, 0.5, 0)),   // 실제로는 1도 차이
        ])
        #expect(result.allMoments[0].sceneCount == 1)
    }

    @Test func 장면을_이어_붙이면_순간의_사진_전체다() {
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213000300"),
            photo("2026080213002000"),
            photo("2026080213002300"),
        ])
        let moment = result.allMoments[0]
        #expect(moment.scenes.map(\.photoIndices) == [[0, 1], [2, 3]])
        #expect(moment.photoIndices == [0, 1, 2, 3])
        #expect(moment.photoCount == 4)
    }

    // MARK: - 날짜

    @Test func 자정을_넘겨_이어진_촬영이_전날에_붙는다() {
        let result = Classifier.classify([
            photo("2026080223500000"),   // 8/2 23:50
            photo("2026080301300000"),   // 8/3 01:30 — 컷오프 전이라 8/2
            photo("2026080312000000"),   // 8/3 12:00
        ])
        #expect(result.days.count == 2)
        #expect(result.days.map(\.date) == [CalendarDay(year: 2026, month: 8, day: 3),
                                            CalendarDay(year: 2026, month: 8, day: 2)])
        #expect(result.days[1].moments.count == 2)
    }

    @Test func 날짜도_순간도_최신_먼저다() {
        let result = Classifier.classify([
            photo("2026080113000000"),
            photo("2026080213000000"),
            photo("2026080219000000"),
        ])
        #expect(result.days.map(\.date) == [CalendarDay(year: 2026, month: 8, day: 2),
                                            CalendarDay(year: 2026, month: 8, day: 1)])
        #expect(result.days[0].moments[0].start.hour == 19)
        #expect(result.days[0].moments[1].start.hour == 13)
    }

    @Test func 날짜는_순간의_첫_사진으로_정해진다() {
        // 순간이 컷오프를 넘겨 이어져도 한 날짜에 통째로 들어간다 — 찢어지지 않는다.
        let result = Classifier.classify([
            photo("2026080303550000"),
            photo("2026080304050000"),   // 컷오프를 넘었지만 같은 순간
        ])
        #expect(result.days.count == 1)
        #expect(result.days[0].date == CalendarDay(year: 2026, month: 8, day: 2))
        #expect(result.days[0].photoCount == 2)
    }

    // MARK: - 읽지 못한 사진

    @Test func 시각을_못_얻은_사진은_unplaced로_빠진다() {
        let result = Classifier.classify([
            photo("2026080213000000"),
            PhotoInput(filename: "IMG_0001.HEIC", bytes: nil),
            photo("2026080213100000"),
        ])
        #expect(result.unplaced == [1])
        #expect(result.photoCount == 2)
        #expect(result.readings.count == 3)
        #expect(result.readings[1].capturedAt == nil)
    }

    @Test func 신호가_없는_사진은_경계를_만들지_않는다() {
        // 안 나누는 쪽이 안전한 실패 방향이다.
        let result = Classifier.classify([
            photo("2026080213000000", position: (0, 0, 0)),
            photo("2026080213010000", withBytes: false),
            photo("2026080213020000", position: (0, 0, 0)),
        ])
        #expect(result.momentCount == 1)
        #expect(result.allMoments[0].photoCount == 3)
    }

    @Test func 신호가_없는_사진은_접히지_않는다() {
        // 접으면 사진이 숨겨진다. 신호가 없으면 접지 않는다.
        let result = Classifier.classify([
            photo("2026080213000000"),
            photo("2026080213000300", withBytes: false),
            photo("2026080213000600"),
        ])
        #expect(result.allMoments[0].sceneCount == 3)
    }

    @Test func readings는_입력과_같은_길이_같은_순서다() {
        let inputs = [photo("2026080215000000"),          // 시간상 나중
                      PhotoInput(filename: "깨진이름.png", bytes: nil),
                      photo("2026080213000000")]
        let result = Classifier.classify(inputs)
        #expect(result.readings.count == inputs.count)
        #expect(result.readings[0].capturedAt?.hour == 15)
        #expect(result.readings[1].capturedAt == nil)
        #expect(result.readings[2].capturedAt?.hour == 13)
    }

    // MARK: - 계약

    @Test func 입력_순서를_바꿔도_같은_결과다() {
        // `MOM-07` · 약속 `C5` — 같은 사진 집합이면 같은 결과.
        let inputs = [
            photo("2026080213000000", position: (0, 0, 0)),
            photo("2026080213000500", position: (0, 0, 0)),
            photo("2026080213200000", position: (500, 0, 0)),
            photo("2026080219000000", position: (0, 0, 0)),
            photo("2026080301300000", position: (0, 0, 0)),
        ]
        let straight = Classifier.classify(inputs)
        let shuffled = Classifier.classify([inputs[3], inputs[0], inputs[4], inputs[2], inputs[1]])

        // 인덱스는 입력 배열을 따라가므로 파일명으로 견준다.
        func shape(_ result: Classification, _ order: [PhotoInput]) -> [[[String]]] {
            result.days.map { day in
                day.moments.flatMap { moment in
                    moment.scenes.map { $0.photoIndices.map { order[$0].filename } }
                }
            }
        }
        #expect(shape(straight, inputs)
                == shape(shuffled, [inputs[3], inputs[0], inputs[4], inputs[2], inputs[1]]))
    }

    @Test func 같은_입력을_두_번_부르면_같은_결과다() {
        let inputs = (0..<12).map { index in
            photo(String(format: "202608021300%02d00", index * 4),
                  position: (Double(index) * 3, 0, 0))
        }
        #expect(Classifier.classify(inputs) == Classifier.classify(inputs))
    }

    @Test func 바이트가_채워져도_시간_경계와_순서는_안_바뀐다() {
        // 부분 입력 계약이 남긴 것 (ADR `0011`). 시간 경계는 파일명만으로 확정됐고
        // 바이트는 그 안의 장소 경계만 건드린다.
        let positions: [(Double, Double, Double)] = [
            (0, 0, 0), (1, 0, 0), (300, 0, 0), (301, 0, 0), (0, 0, 0), (600, 0, 0),
        ]
        let names = ["2026080213000000", "2026080213000500", "2026080213100000",
                     "2026080213101000", "2026080213200000", "2026080214300000"]

        let coarse = Classifier.classify(names.map { PhotoInput(filename: captureName($0), bytes: nil) })
        let refined = Classifier.classify(zip(names, positions).map { photo($0, position: $1) })

        // 사진이 사라지거나 늘지 않는다.
        #expect(refined.photoCount == coarse.photoCount)
        // 시각 오름차순으로 편 사진 순서가 같다.
        #expect(refined.allMoments.flatMap(\.photoIndices)
                == coarse.allMoments.flatMap(\.photoIndices))
        // 시간 경계는 그대로다 — 장소는 그 **안에서만** 다시 갈린다.
        let timeRuns = coarse.allMoments.map { Set($0.photoIndices) }
        for moment in refined.allMoments {
            #expect(timeRuns.contains { Set(moment.photoIndices).isSubset(of: $0) },
                    "순간 \(moment.photoIndices)가 시간 구간을 넘어섰다")
        }
    }

    @Test func 바이트가_채워지면_순간이_합쳐질_수도_있다() {
        // ⚠️ ADR `0011`이 `0004` 결정 2 (c)를 대체한 자리. 평균 연결은 **그때 있는 점들**의
        // 함수라, 가운데 점이 뒤늦게 오면 갈라져 있던 둘에 다리를 놓는다.
        // 한 줄 위 `0 · t/6 · t+1` — 양 끝은 임계값을 넘는데, 가운데가 오면 먼저 붙어
        // 갱신 거리가 `t + 1 - t/12`로 임계값 안에 들어온다.
        let t = Settings.default.placeClusterDistance
        let names = ["2026080213000000", "2026080213010000", "2026080213020000"]
        let xs: [Double] = [0, t / 6, t + 1]

        let partial = Classifier.classify(zip(names, xs).enumerated().map { index, pair in
            photo(pair.0, position: (pair.1, 0, 0), withBytes: index != 1)
        })
        let full = Classifier.classify(zip(names, xs).map { photo($0, position: ($1, 0, 0)) })

        #expect(partial.momentCount == 2)
        #expect(full.momentCount == 1)
    }

    @Test func 바이트가_일부만_채워져도_시간_구간을_넘지_않는다() {
        let names = ["2026080213000000", "2026080213050000", "2026080213100000",
                     "2026080213150000"]
        let positions: [(Double, Double, Double)] = [(0, 0, 0), (0, 0, 0), (500, 0, 0), (500, 0, 0)]

        let none = Classifier.classify(names.map { PhotoInput(filename: captureName($0), bytes: nil) })
        let half = Classifier.classify(zip(names, positions).enumerated().map { index, pair in
            photo(pair.0, position: pair.1, withBytes: index < 3)
        })
        let all = Classifier.classify(zip(names, positions).map { photo($0, position: $1) })

        // 시간 구간(바이트 0장일 때의 순간)이 상한이다 — 어느 단계에서도 이를 넘지 않는다.
        let timeRuns = none.allMoments.map { Set($0.photoIndices) }
        for result in [half, all] {
            #expect(result.photoCount == none.photoCount)
            for moment in result.allMoments {
                #expect(timeRuns.contains { Set(moment.photoIndices).isSubset(of: $0) })
            }
        }
    }

    @Test func 군집_번호는_가장_작은_첨자_순서로_붙는다() {
        // 다른 언어 구현이 같은 결과를 내려면 번호 순서도 정해져 있어야 한다.
        let points = [Vector3(x: 100, y: 0, z: 0), Vector3(x: 0, y: 0, z: 0),
                      Vector3(x: 101, y: 0, z: 0), Vector3(x: 1, y: 0, z: 0)]
        #expect(Classifier.averageLinkageClusters(points, threshold: 20) == [0, 1, 0, 1])
    }

    @Test func 군집이_평균_연결로_합쳐진다() {
        // 0, 10, 20 — 인접 간격은 10이지만 평균 연결 거리는 15라 임계값 12에서 안 합쳐진다.
        let points = [Vector3(x: 0, y: 0, z: 0), Vector3(x: 10, y: 0, z: 0),
                      Vector3(x: 20, y: 0, z: 0)]
        #expect(Classifier.averageLinkageClusters(points, threshold: 12) == [0, 0, 1])
        #expect(Classifier.averageLinkageClusters(points, threshold: 20) == [0, 0, 0])
    }

    @Test func 군집이_빈_입력과_한_점을_견딘다() {
        #expect(Classifier.averageLinkageClusters([], threshold: 20).isEmpty)
        #expect(Classifier.averageLinkageClusters([Vector3(x: 0, y: 0, z: 0)], threshold: 20) == [0])
    }
}
