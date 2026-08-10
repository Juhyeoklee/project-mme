// 시각 — 시간대가 없는 벽시계.
//
// import 0이라 `Date`·`Calendar`를 쓸 수 없는데(ADR `0001` 결정 4 ①) 그게 손해가 아니다.
// 파일명이 담은 것은 **촬영 기기의 벽시계**지 타임라인 위의 한 점이 아니다. `Date`를 쓰면
// 데이터에 없는 시간대를 발명했다 도로 빼야 하고, 그 왕복이 약속 `C5`가 깨지는 자리다.

/// 시간대가 없는 벽시계 시각. 1/100초까지 담는다.
public struct WallClock: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int      // 1...12
    public let day: Int        // 1...말일
    public let hour: Int       // 0...23
    public let minute: Int     // 0...59
    public let second: Int     // 0...59
    public let hundredth: Int  // 0...99

    /// 달력상 있을 수 없는 값이면 `nil`. 윤년까지 본다.
    public init?(year: Int, month: Int, day: Int,
                 hour: Int, minute: Int, second: Int, hundredth: Int) {
        // ⚠️ 말일은 범위가 아니라 부등호로 본다 — `daysInMonth`가 0을 주는 달이면
        // `1...0`이 트랩이고, 지금 안전한 이유가 앞줄 검사의 **평가 순서**뿐이었다.
        guard (1...12).contains(month),
              day >= 1, day <= WallClock.daysInMonth(year: year, month: month),
              (0...23).contains(hour), (0...59).contains(minute),
              (0...59).contains(second), (0...99).contains(hundredth)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.hundredth = hundredth
    }

    // MARK: - 달력

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: 31
        case 4, 6, 9, 11: 30
        case 2: isLeapYear(year) ? 29 : 28
        default: 0
        }
    }

    /// 1970-01-01을 0으로 하는 일련 일수 — Howard Hinnant의 `days_from_civil`이다.
    /// Swift의 `/`는 C++와 같이 0쪽으로 자르므로 원문 그대로 옮겨진다.
    public static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400                                        // 0...399
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1  // 0...365
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146097 + dayOfEra - 719468
    }

    /// `daysFromCivil`의 역함수.
    public static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let dayOfEra = z - era * 146097                                      // 0...146096
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365
        let y = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153                                   // 0...11 (3월=0)
        let d = dayOfYear - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    /// 1970-01-01 00:00:00.00을 0으로 하는 1/100초 일련값. 시각 비교와 간격 계산의 바탕이다.
    public var centiseconds: Int {
        let days = WallClock.daysFromCivil(year: year, month: month, day: day)
        return ((((days * 24 + hour) * 60 + minute) * 60 + second) * 100) + hundredth
    }

    public var calendarDay: CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    /// `hours`시간 뒤로 민 뒤의 달력 날짜. 새벽 컷오프(`MOM-06`)가 쓴다.
    public func calendarDay(shiftedBackBy hours: Int) -> CalendarDay {
        let shifted = centiseconds - hours * 3600 * 100
        // 내림 나눗셈 — 음수 구간에서도 하루를 정확히 자른다.
        let perDay = 24 * 3600 * 100
        var days = shifted / perDay
        if shifted % perDay < 0 { days -= 1 }
        let civil = WallClock.civilFromDays(days)
        return CalendarDay(year: civil.year, month: civil.month, day: civil.day)
    }

    public static func < (lhs: WallClock, rhs: WallClock) -> Bool {
        lhs.centiseconds < rhs.centiseconds
    }

    // MARK: - 파일명

    /// 확장자를 떼고 **마지막 `_` 뒤가 정확히 숫자 16자**여야 한다.
    /// **게임 이름은 요구하지 않는다** — 소스가 게임 앨범으로 고정돼 있어 접두사를 다시 검사할
    /// 이유가 없고, 검사하면 이름이 바뀐 사본을 통째로 잃는다.
    public static func fromCaptureFilename(_ filename: String) -> WallClock? {
        var name = Substring(filename)
        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            name = name[name.startIndex..<dot]
        }
        guard let underscore = name.lastIndex(of: "_") else { return nil }
        let digits = name[name.index(after: underscore)...]
        guard digits.count == 16 else { return nil }

        var values: [Int] = []
        values.reserveCapacity(16)
        for character in digits {
            guard let value = character.wholeNumberValue, character.isASCII, (0...9).contains(value)
            else { return nil }
            values.append(value)
        }
        func number(_ range: Range<Int>) -> Int {
            range.reduce(0) { $0 * 10 + values[$1] }
        }
        return WallClock(year: number(0..<4), month: number(4..<6), day: number(6..<8),
                         hour: number(8..<10), minute: number(10..<12), second: number(12..<14),
                         hundredth: number(14..<16))
    }
}

/// 시간대도 시각도 없는 달력 날짜. 순간을 날짜로 묶는 단위다 (`MOM-05`).
public struct CalendarDay: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
