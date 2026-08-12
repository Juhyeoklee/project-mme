// 문구 — 화면들의 문구가 전부 여기 있다.
//
// 한 곳에 모은 이유 둘 — ① 같은 문자열이 두 화면에 나타나는 자리가 규칙이다(둘이 같아야
// *"누른 그 순간이 맞다"* 가 확인된다) ② **화면설계서 밖에서 만든 문구가 어디 있는지가
// 보여야 한다** — 그 구역은 아래에 따로 모여 있다. 흩어놓으면 슬며시 는다.
//
// `Date`·`Calendar`를 쓰지 않는다. `WallClock`은 시간대가 없는 벽시계고, 표시하려고 시간대를
// 발명해 넣으면 자정 근처에서 날짜가 밀린다 — 커널이 피한 함정을 화면에서 도로 팔 이유가 없다.

import MomentKernel

enum Wording {
    /// `04-N1`이자 탭 이름. 앱 이름을 쓰지 않는다 — 홈에서 앱 이름은 정보가 0이다.
    static let listTitle = "순간"
    /// `07-N1`이자 탭 이름. **두 글자·숫자 없음으로 위와 짝이다.**
    static let recordsTitle = "기록"

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

    /// 낭독 이름 셋. **화면에 안 보이지만 문자열이다** — 규칙은 `App/Icons/README-icons.md`.
    /// `05-N1`.
    static let back = "뒤로"
    /// `06-N1`.
    static let close = "닫기"
    /// `09-N4`.
    static let moreActions = "더보기"

    // MARK: - 기록 만들기

    /// **흐름 서술이 아니라 기능 이름이다** — `IA`·`PRD`가 부르는 이름을 그대로 쓴다.
    static let createRecord = "기록 만들기"
    static let cancel = "취소"
    static let save = "저장"
    static let confirm = "확정"
    /// `09-N4`.
    static let editOccurredAt = "발생일시 수정"
    /// `09-T`. iPad·macOS에만 선다.
    static let makeCanvas = "캔버스로 만들기"
    /// 격자의 마지막 칸이자 사진 더하기 화면의 타이틀. **같은 말이라 같은 문자열이다.**
    static let addPhotos = "사진 더하기"
    /// `10-T1` — 소스 밖 사진을 시스템 피커로 지목한다.
    static let importDirectly = "직접 가져오기"
    static let captionPlaceholder = "무슨 일이 있었는지 적어보세요"

    /// `09-N3` — 뺀 것이 없을 때. **부제가 어포던스를 진다**(탭이 무엇을 하는지 말한다).
    static func keptAll(_ count: Int) -> String { "\(count)장 · 탭해서 빼기" }
    /// `09-N3` — 하나라도 뺀 뒤. 「선택됨」이라는 단어가 없는 것이 값이다.
    static func kept(_ count: Int, removed: Int) -> String { "\(count)장 · \(removed)장 뺌" }

    /// `10-B` 시각 구분 헤더. 꼬리가 붙는 것은 들어온 그 순간 하나뿐이다.
    static func momentBreak(_ clock: WallClock, isOrigin: Bool) -> String {
        isOrigin ? "\(time(clock)) · 이 순간" : time(clock)
    }

    // MARK: - 기록 보기

    /// `07-E1`.
    static let recordsEmpty = "아직 남긴 기록이 없어요"

    /// `07-N2`. 기록에는 「장수」가 전체 요약으로 의미가 없어 개수만 쓴다.
    static func recordSummary(_ count: Int) -> String { "기록 \(count.formatted())개" }

    /// `07-B1` — `2026년 8월`. **날짜 헤더와 달리 년을 쓴다** — 기록은 여러 해에 걸쳐 쌓이고
    /// 월 단위라 년이 없으면 8월이 어느 8월인지 구별되지 않는다.
    static func monthHeader(year: Int, month: Int) -> String { "\(year)년 \(month)월" }

    /// 갤러리는 사진 수, 캔버스는 페이지 수. **둘 다 「이미지 몇 장」이다.**
    static func images(_ count: Int) -> String { "\(count)장" }

    static let draft = "초안"
    /// `08-T`.
    static let flipThrough = "넘겨보기"
    static let edit = "수정"
    static let share = "공유"
    /// `08-T` 초안 — 설명을 붙여 기록으로 만든다.
    static let publish = "게시"
    /// **컨텍스트 메뉴와 더보기 밖에는 안 선다.**
    static let delete = "삭제"

    // MARK: - 확인과 실패 — ⚠️ 화면설계서 밖이다

    /// ⚠️ **이 절의 문구는 화면설계가 정한 것이 아니다.** 오류·확인 문구는 *"어떤 실패가
    /// 실제로 나는지는 코드가 알려준다"* 는 이유로 구현에 넘겨진 자리다.
    static let discardTitle = "만들던 기록을 어떻게 할까요?"
    static let keepAsDraft = "초안으로 남기기"
    static let discard = "버리기"
    /// 원본을 못 읽었거나 디스크에 못 썼다. **왜인지는 사용자가 고칠 수 없어 말하지 않는다.**
    static let saveFailed = "저장하지 못했어요"
    static let acknowledge = "확인"
    /// 저장소를 못 읽었다. 삭제 실패에는 안 쓴다 — 그때는 지워지지 않은 카드가 그대로 남는 것이
    /// 이미 결과를 말한다.
    static let recordsFailed = "기록을 불러오지 못했어요"
    /// `ARC-07` 확인 한 단계. 파괴에는 색 말고 신호가 하나 더 있어야 한다.
    static let deleteRecordTitle = "이 기록을 지울까요?"

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
