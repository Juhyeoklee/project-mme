// 문구 — 화면설계서 §1.3이 세 화면의 문구를 **열셋으로** 닫았다. 여기가 그 열셋의 전부다.
//
// 한 곳에 모은 이유는 두 가지다. ① 같은 문자열이 두 화면에 나타나는 자리가 규칙이다 —
// `04-C2`와 `05-N3`이 같은 문자열이어야 *"누른 그 순간이 맞다"* 가 확인된다(설계서 §3.2).
// ② 없는 문구가 규칙이다 — 기록·저장·공유·설정·에러·완료 알림이 없다. 흩어놓으면 슬며시 는다.
//
// `Date`·`Calendar`를 쓰지 않는다. 입력인 `WallClock`은 시간대가 없는 벽시계고
// (`MomentKernel/WallClock.swift`), 표시하려고 시간대를 발명해 넣으면 자정 근처에서 날짜가
// 밀린다. 커널이 피한 함정을 화면에서 도로 팔 이유가 없다.

import MomentKernel

enum Wording {
    /// `04-N1`. 앱 이름을 쓰지 않는다 — 홈에서 앱 이름은 정보가 0이고,
    /// 출시 2에서 `기록` 탭이 생기면 `순간` ‖ `기록`으로 짝이 맞는다.
    static let listTitle = "순간"

    /// `04-E1`. 빈 상태 "화면"이 아니라 목록 자리를 채우는 한 줄이다.
    static let empty = "아직 사진이 없어요"

    /// `05-G4`.
    static let collapse = "접기"

    /// `04-N2` · `04-B2` — `순간 128개 · 1,204장`.
    /// 두 위계가 같은 말투로 갈린다. 새 어휘를 만들지 않는다.
    static func summary(moments: Int, photos: Int) -> String {
        "순간 \(moments.formatted())개 · \(photos.formatted())장"
    }

    /// `04-C2` · `05-N3` — `12장 · 8장면`.
    ///
    /// **연사 묶음이 없으면 `2장`만 쓴다.** `BRW-03`은 조건 없이 셋을 요구하지만, 연사가 없으면
    /// 장면 수 = 장수라 `2장 · 2장면`은 같은 값을 두 번 말하는 것이 된다 (설계서 §2.2).
    static func counts(photos: Int, scenes: Int) -> String {
        photos == scenes ? "\(photos)장" : "\(photos)장 · \(scenes)장면"
    }

    /// `04-C4` — 스트립에 다 못 담은 장면 수.
    static func more(_ count: Int) -> String { "+\(count)" }

    /// `04-B1` — `7월 26일 (일)`. 화면에서 가장 큰 활자.
    static func dateHeader(_ day: CalendarDay) -> String {
        "\(day.month)월 \(day.day)일 (\(weekdaySymbol(day)))"
    }

    /// `04-C1` · `06-N2` — `18:05`.
    static func time(_ clock: WallClock) -> String {
        "\(clock.hour):\(twoDigits(clock.minute))"
    }

    /// `05-N2` — `7월 26일 18:05`. 날짜 헤더와 달리 요일이 없다.
    static func detailTitle(_ clock: WallClock) -> String {
        "\(clock.month)월 \(clock.day)일 \(time(clock))"
    }

    /// `06-N3` — `3 / 12`. **장면 수가 아니라 장수 기준이다** (설계서 §4.2).
    static func position(_ index: Int, of total: Int) -> String { "\(index + 1) / \(total)" }

    // MARK: - 조각

    /// 요일. 1970-01-01이 목요일이라는 사실 하나로 닫힌다 — 커널의 `daysFromCivil`이 일련 일수를 준다.
    static func weekdaySymbol(_ day: CalendarDay) -> String {
        let days = WallClock.daysFromCivil(year: day.year, month: day.month, day: day.day)
        // 0 = 1970-01-01 = 목요일. 일요일을 0으로 옮기려면 4를 더한다.
        // 음수 구간(1970 이전)에서도 맞도록 나머지를 양수로 접는다.
        let index = ((days + 4) % 7 + 7) % 7
        return ["일", "월", "화", "수", "목", "금", "토"][index]
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
