import Testing
@testable import MomentKernel

@Suite("벽시계")
struct WallClockTests {

    @Test func 파일명에서_1_100초까지_읽는다() {
        let clock = WallClock.fromCaptureFilename("MabinogiMobile_2026080210211445.png")
        #expect(clock?.year == 2026)
        #expect(clock?.month == 8)
        #expect(clock?.day == 2)
        #expect(clock?.hour == 10)
        #expect(clock?.minute == 21)
        #expect(clock?.second == 14)
        #expect(clock?.hundredth == 45)
    }

    @Test func 확장자_대소문자와_없는_경우를_가리지_않는다() {
        let expected = WallClock.fromCaptureFilename("MabinogiMobile_2026080210211445.png")
        #expect(WallClock.fromCaptureFilename("MabinogiMobile_2026080210211445.PNG") == expected)
        #expect(WallClock.fromCaptureFilename("MabinogiMobile_2026080210211445") == expected)
    }

    @Test func 게임_이름을_요구하지_않는다() {
        // 소스가 게임 앨범으로 고정돼 있어 접두사를 다시 검사할 이유가 없다.
        #expect(WallClock.fromCaptureFilename("무엇이든_2026080210211445.png") != nil)
    }

    @Test(arguments: [
        "MabinogiMobile.png",                    // `_` 가 없다
        "MabinogiMobile_202608021021144.png",    // 15자
        "MabinogiMobile_20260802102114455.png",  // 17자
        "MabinogiMobile_2026080210211x45.png",   // 숫자가 아니다
        "MabinogiMobile_20260802102114 5.png",   // 공백
        "MabinogiMobile_2026133210211445.png",   // 13월
        "MabinogiMobile_2026023010211445.png",   // 2월 30일
        "MabinogiMobile_2026080224211445.png",   // 24시
        "MabinogiMobile_2026080210611445.png",   // 61분
    ])
    func 읽을_수_없는_이름은_nil(_ name: String) {
        #expect(WallClock.fromCaptureFilename(name) == nil)
    }

    @Test func 윤년을_본다() {
        #expect(WallClock.fromCaptureFilename("x_2024022912000000.png") != nil)   // 2024는 윤년
        #expect(WallClock.fromCaptureFilename("x_2026022912000000.png") == nil)
        #expect(WallClock.fromCaptureFilename("x_2000022912000000.png") != nil)   // 400 배수
        #expect(WallClock.fromCaptureFilename("x_1900022912000000.png") == nil)   // 100 배수
    }

    @Test func 달력_왕복이_맞는다() {
        // 경계와 윤년 언저리를 골라 왕복시킨다.
        let dates = [(1970, 1, 1), (1969, 12, 31), (2000, 2, 29), (2024, 2, 29),
                     (2026, 8, 3), (1900, 3, 1), (2100, 3, 1), (2400, 2, 29)]
        for (year, month, day) in dates {
            let days = WallClock.daysFromCivil(year: year, month: month, day: day)
            let back = WallClock.civilFromDays(days)
            #expect(back.year == year && back.month == month && back.day == day)
        }
        #expect(WallClock.daysFromCivil(year: 1970, month: 1, day: 1) == 0)
        #expect(WallClock.daysFromCivil(year: 1970, month: 1, day: 2) == 1)
        #expect(WallClock.daysFromCivil(year: 1969, month: 12, day: 31) == -1)
    }

    @Test func 하루_연속으로_왕복시켜도_어긋나지_않는다() {
        let start = WallClock.daysFromCivil(year: 2023, month: 12, day: 20)
        for offset in 0..<500 {
            let civil = WallClock.civilFromDays(start + offset)
            #expect(WallClock.daysFromCivil(year: civil.year, month: civil.month, day: civil.day)
                    == start + offset)
        }
    }

    @Test func 시각_순서가_1_100초까지_간다() {
        let a = WallClock.fromCaptureFilename("x_2026080210211444.png")!
        let b = WallClock.fromCaptureFilename("x_2026080210211445.png")!
        #expect(a < b)
        #expect(b.centiseconds - a.centiseconds == 1)
    }

    @Test func 새벽_컷오프가_자정을_넘긴_촬영을_전날에_붙인다() {
        let cutoff = 4
        // 23:50 → 당일
        #expect(WallClock.fromCaptureFilename("x_2026080223500000.png")!
                .calendarDay(shiftedBackBy: cutoff) == CalendarDay(year: 2026, month: 8, day: 2))
        // 다음날 01:30 → 전날
        #expect(WallClock.fromCaptureFilename("x_2026080301300000.png")!
                .calendarDay(shiftedBackBy: cutoff) == CalendarDay(year: 2026, month: 8, day: 2))
        // 03:59:59.99 → 아직 전날
        #expect(WallClock.fromCaptureFilename("x_2026080303595999.png")!
                .calendarDay(shiftedBackBy: cutoff) == CalendarDay(year: 2026, month: 8, day: 2))
        // 04:00:00.00 → 당일
        #expect(WallClock.fromCaptureFilename("x_2026080304000000.png")!
                .calendarDay(shiftedBackBy: cutoff) == CalendarDay(year: 2026, month: 8, day: 3))
    }

    @Test func 컷오프가_월과_해의_경계를_넘는다() {
        #expect(WallClock.fromCaptureFilename("x_2026010101000000.png")!
                .calendarDay(shiftedBackBy: 4) == CalendarDay(year: 2025, month: 12, day: 31))
        #expect(WallClock.fromCaptureFilename("x_2024030102000000.png")!
                .calendarDay(shiftedBackBy: 4) == CalendarDay(year: 2024, month: 2, day: 29))
    }

    @Test func 컷오프_0시는_달력_날짜_그대로다() {
        let clock = WallClock.fromCaptureFilename("x_2026080300300000.png")!
        #expect(clock.calendarDay(shiftedBackBy: 0) == clock.calendarDay)
    }
}
