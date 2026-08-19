// 문구 — 화면들의 문구가 전부 여기 있다. **같은 문자열이 두 화면에 서는 자리가 규칙이다.**
//
// ⚠️ `Date`·`Calendar`를 쓰지 않는다. `WallClock`은 시간대가 없는 벽시계고, 표시하려고
// 시간대를 발명해 넣으면 자정 근처에서 날짜가 밀린다.

import MomentKernel

enum Wording {
    /// `04-N1`이자 탭 이름.
    static let listTitle = "순간"
    /// `07-N1`이자 탭 이름.
    static let recordsTitle = "기록"

    /// `04-E1`.
    static let empty = "아직 사진이 없어요"

    /// `05` 원본을 끝내 못 받은 사진 (`R8`).
    /// ⚠️ **문구는 잠정이다** — 오류 카피는 `M3`가 정한다.
    static func missingOriginals(_ count: Int) -> String {
        "표시된 사진 \(count)장은 원본을 아직 못 받아왔어요.\n나머지는 다 받았고, 원본이 도착하면 순간이 더 정확해져요."
    }
    static let missingOriginalsLabel = "원본을 못 받은 사진 있음"

    /// `05-G4`.
    static let collapse = "접기"

    /// `순간 128개 · 1,204장`.
    static func summary(moments: Int, photos: Int) -> String {
        "순간 \(moments.formatted())개 · \(photos.formatted())장"
    }

    /// `12장 · 8장면`.
    static func counts(photos: Int, scenes: Int) -> String {
        photos == scenes ? "\(photos)장" : "\(photos)장 · \(scenes)장면"
    }

    /// `04-C4` — 스트립에 다 못 담은 장면 수.
    static func more(_ count: Int) -> String { "+\(count)" }

    /// `04-B1` — `7월 26일 (일)`.
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

    /// 낭독 이름 셋. **화면에 안 보이지만 문자열이다** — 규칙은 `App/Design/Icons/README-icons.md`.
    /// `05-N1`.
    static let back = "뒤로"
    /// `06-N1`.
    static let close = "닫기"
    /// `09-N4`.
    static let moreActions = "더보기"

    // MARK: - 기록 만들기

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

    /// `09-N3` — 뺀 것이 없을 때.
    static func keptAll(_ count: Int) -> String { "\(count)장 · 탭해서 빼기" }
    /// `09-N3` — 하나라도 뺀 뒤.
    static func kept(_ count: Int, removed: Int) -> String { "\(count)장 · \(removed)장 뺌" }

    /// `10-B` 시각 구분 헤더. 꼬리가 붙는 것은 들어온 그 순간 하나뿐이다.
    static func momentBreak(_ clock: WallClock, isOrigin: Bool) -> String {
        isOrigin ? "\(time(clock)) · 이 순간" : time(clock)
    }

    // MARK: - 기록 보기

    /// `07-E1`.
    static let recordsEmpty = "아직 남긴 기록이 없어요"

    /// `07-N2`.
    static func recordSummary(_ count: Int) -> String { "기록 \(count.formatted())개" }

    /// `07-B1` — `2026년 8월`.
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

    // MARK: - `11` 캔버스

    /// `11-P1` 낭독 이름 — `2쪽`.
    static func canvasPage(_ number: Int) -> String { "\(number)쪽" }
    /// `11-P2`.
    static let addPage = "페이지 더하기"
    /// `11-N2` · `11-N3`.
    static let undo = "되돌리기"
    static let redo = "다시하기"
    /// `11-O3` — 서랍이 무엇이고 어떻게 쓰는지를 한 줄이 진다.
    static let photoDrawer = "이 기록의 사진 · 끌어다 놓거나 탭한다"
    /// `11-I3` · `11-O1` 스테퍼의 낭독 이름 — `크기 키우기`.
    static func increase(_ name: String) -> String { "\(name) 키우기" }
    static func decrease(_ name: String) -> String { "\(name) 줄이기" }
    /// `11-I` · `11-O1` 컨트롤의 이름.
    static let textSize = "크기"
    static let strokeWidth = "굵기"
    /// `11-O1` 마커 — **「투명도」가 아니라 「진하기」다.** 100이 어느 쪽인지 헷갈리지 않는다.
    static let inkOpacity = "진하기"
    static let inkColor = "색"
    /// `11-I1` 글꼴 2종 — **역할 이름이지 서체 이름이 아니다.**
    static let handwritingFace = "손글씨"
    static let serifFace = "반듯한 것"
    /// `11-I2` 굵기 2단.
    static let regularWeight = "보통"
    static let boldWeight = "굵게"

    /// `11-I6`과 컨텍스트 메뉴.
    static let bringToFront = "맨 앞으로"
    static let sendToBack = "맨 뒤로"

    /// `11-N1` — 승격해 들어왔을 때. 만들던 것이 아직 어디에도 없다.
    static let discardCanvasTitle = "만들던 캔버스를 어떻게 할까요?"
    /// `11-N1` — 저장된 캔버스를 고치던 중.
    static let discardCanvasEditTitle = "변경한 내용을 버릴까요?"
    static let keepEditing = "계속 편집"

    // MARK: - 확인과 실패 — ⚠️ 이 절은 구현이 정했다

    static let discardTitle = "만들던 기록을 어떻게 할까요?"
    static let keepAsDraft = "초안으로 남기기"
    static let discard = "버리기"
    /// 원본을 못 읽었거나 디스크에 못 썼다.
    static let saveFailed = "저장하지 못했어요"
    static let acknowledge = "확인"
    /// 저장소를 못 읽었다. **삭제 실패에는 안 쓴다** — 지워지지 않은 카드가 이미 결과를 말한다.
    static let recordsFailed = "기록을 불러오지 못했어요"
    /// `ARC-07` 확인 한 단계.
    static let deleteRecordTitle = "이 기록을 지울까요?"
    /// `REC-05` 후보가 0장이다.
    static let noPhotosToAdd = "더할 사진이 없어요"

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
