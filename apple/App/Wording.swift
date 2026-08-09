// 문구 — 세 화면의 문구 열셋이 전부 여기 있다.
//
// 한 곳에 모은 이유 둘 — ① 같은 문자열이 두 화면에 나타나는 자리가 규칙이다(`04-C2`와 `05-N3`이
// 같아야 *"누른 그 순간이 맞다"* 가 확인된다) ② **없는 문구가 규칙이다** — 기록·저장·공유·설정·
// 에러·완료 알림이 없다. 흩어놓으면 슬며시 는다.
//
// `Date`·`Calendar`를 쓰지 않는다. `WallClock`은 시간대가 없는 벽시계고, 표시하려고 시간대를
// 발명해 넣으면 자정 근처에서 날짜가 밀린다 — 커널이 피한 함정을 화면에서 도로 팔 이유가 없다.

import MomentKernel

enum Wording {
    /// `04-N1`. 앱 이름을 쓰지 않는다 — 홈에서 앱 이름은 정보가 0이고,
    /// 출시 2에서 `기록` 탭이 생기면 `순간` ‖ `기록`으로 짝이 맞는다.
    static let listTitle = "순간"

    /// `04-E1`. 빈 상태 "화면"이 아니라 목록 자리를 채우는 한 줄이다.
    static let empty = "아직 사진이 없어요"

    /// `05-G4`.
    static let collapse = "접기"

    /// `순간 128개 · 1,204장`. 두 위계가 같은 말투로 갈린다 — 새 어휘를 만들지 않는다.
    static func summary(moments: Int, photos: Int) -> String {
        "순간 \(moments.formatted())개 · \(photos.formatted())장"
    }

    /// `12장 · 8장면`. **연사 묶음이 없으면 `2장`만 쓴다** — `BRW-03`은 조건 없이 셋을 요구하지만
    /// 장면 수 = 장수면 `2장 · 2장면`은 같은 값을 두 번 말하는 것이 된다.
    static func counts(photos: Int, scenes: Int) -> String {
        photos == scenes ? "\(photos)장" : "\(photos)장 · \(scenes)장면"
    }

    /// `04-C4` — 스트립에 다 못 담은 장면 수.
    static func more(_ count: Int) -> String { "+\(count)" }

    /// `04-B1` — `7월 26일 (일)`. 화면에서 가장 큰 활자.
    static func dateHeader(_ day: CalendarDay) -> String {
        "\(day.month)월 \(day.day)일 (\(weekdaySymbol(day)))"
    }

    static func time(_ clock: WallClock) -> String {
        "\(clock.hour):\(twoDigits(clock.minute))"
    }

    /// `05-N2` — `7월 26일 18:05`. 날짜 헤더와 달리 요일이 없다.
    static func detailTitle(_ clock: WallClock) -> String {
        "\(clock.month)월 \(clock.day)일 \(time(clock))"
    }

    /// `06-N3` — `3 / 12`.
    static func position(_ index: Int, of total: Int) -> String { "\(index + 1) / \(total)" }

    // MARK: - 조각

    /// 요일. `Calendar` 없이 커널의 일련 일수로 낸다.
    static func weekdaySymbol(_ day: CalendarDay) -> String {
        let days = WallClock.daysFromCivil(year: day.year, month: day.month, day: day.day)
        // 1970-01-01 = 목요일. 일요일을 0으로 옮기려 4를 더하고, 음수 구간에서도 맞게 접는다.
        let index = ((days + 4) % 7 + 7) % 7
        return ["일", "월", "화", "수", "목", "금", "토"][index]
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
