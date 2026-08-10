// 문구는 `Date`·`Calendar` 없이 만들어진다 — 그 계산이 맞는지는 여기서만 확인된다.

import MomentKernel
import Testing
@testable import Moanogi

@Suite("문구")
struct WordingTests {

    // MARK: - 요일

    @Test(arguments: [
        (1970, 1, 1, "목"),    // 일련 일수 0의 요일. 나머지가 전부 여기서 파생된다
        (1969, 12, 31, "수"),  // 음수 구간
        (2026, 8, 3, "월"),
        (2026, 7, 26, "일"),
        (1900, 3, 1, "목"),    // 100의 배수 — 윤년이 아니다
        (2000, 3, 1, "수"),    // 400의 배수 — 윤년이다
    ])
    func 요일을_달력_없이_낸다(_ testCase: (Int, Int, Int, String)) {
        let day = CalendarDay(year: testCase.0, month: testCase.1, day: testCase.2)
        #expect(Wording.weekdaySymbol(day) == testCase.3, "\(testCase.0)-\(testCase.1)-\(testCase.2)")
    }

    // MARK: - 형식

    @Test func 날짜_머리글은_요일을_붙이고_상세_제목은_안_붙인다() throws {
        let clock = try #require(WallClock.fromCaptureFilename("x_2026072618050000.png"))
        #expect(Wording.dateHeader(clock.calendarDay) == "7월 26일 (일)")
        #expect(Wording.detailTitle(clock) == "7월 26일 18:05")
    }

    @Test func 시각은_분만_두_자리로_채운다() throws {
        let morning = try #require(WallClock.fromCaptureFilename("x_2026072609050000.png"))
        #expect(Wording.time(morning) == "9:05")
    }

    @Test func 순번은_1부터_센다() {
        #expect(Wording.position(0, of: 12) == "1 / 12")
        #expect(Wording.position(11, of: 12) == "12 / 12")
    }

    @Test func 요약은_천_단위를_끊는다() {
        #expect(Wording.summary(moments: 128, photos: 1204) == "순간 128개 · 1,204장")
    }

    // MARK: - 계약

    @Test func 장면_수가_장수와_같으면_같은_말을_두_번_하지_않는다() {
        // `BRW-03`은 조건 없이 셋을 요구하지만, 연사 묶음이 없으면 장면 수가 정보를 더하지 않는다.
        #expect(Wording.counts(photos: 2, scenes: 2) == "2장")
        #expect(Wording.counts(photos: 12, scenes: 8) == "12장 · 8장면")
    }
}
