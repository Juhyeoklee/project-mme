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

    // `04-E1`은 셋으로 갈린다 — 소스가 없는 것 · 사진이 0장인 것 · 사진은 있는데 못 묶은 것.
    /// 소스는 있고 사진이 0장.
    static let empty = "아직 사진이 없어요"
    /// 소스를 아직 안 정했다 (`SYS-01`).
    static let sourceUnset = "아직 볼 앨범을 안 정했어요"
    /// 사진은 있는데 순간이 0이다.
    static let noMomentsHere = "이 앨범에서는 순간을 못 묶었어요"

    /// `05` 원본을 끝내 못 받은 사진 (`R8`).
    /// ⚠️ **문구는 잠정이다** — 오류 카피는 `M3`가 정한다.
    static func missingOriginals(_ count: Int) -> String {
        "표시된 사진 \(count)장은 원본을 아직 못 받아왔어요.\n나머지는 다 받았고, 원본이 도착하면 순간이 더 정확해져요."
    }
    static let missingOriginalsLabel = "원본을 못 받은 사진 있음"

    /// `05-G4`.
    static let collapse = "접기"

    /// `순간 128개 · 1,204장`. ⚠️ **순간이 0이면 장수만 말한다** — 시각을 못 얻은 사진만
    /// 있는 소스에서 「순간 0개」가 세는 것은 없는 것이고, 그 줄은 실패의 보고로 읽힌다.
    static func summary(moments: Int, photos: Int) -> String {
        moments == 0 ? "\(photos.formatted())장"
                     : "순간 \(moments.formatted())개 · \(photos.formatted())장"
    }

    /// `10`의 시각 구분 헤더가 날짜만 가진 묶음에 다는 라벨.
    /// ⚠️ **`04`·`05`는 안 쓴다** — 거기는 날짜와 장수가 이미 서 있어 같은 말이 두 번 된다.
    static let noCaptureTime = "찍힌 시각 모름"

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
        time(hour: clock.hour, minute: clock.minute)
    }

    /// 벽시계 없이 부르는 입구. **견본이 쓴다** — 있지도 않은 시각을 지어내지 않으려면
    /// 시·분만 있으면 된다.
    static func time(hour: Int, minute: Int) -> String { "\(hour):\(twoDigits(minute))" }

    /// `05-N2` — `7월 26일 18:05`. 날짜 헤더와 달리 요일이 없다.
    static func detailTitle(_ clock: WallClock) -> String {
        "\(clock.month)월 \(clock.day)일 \(time(clock))"
    }

    /// `05-N2` 날짜만 가진 묶음 — **시각을 지어내지 않는다.** 날짜에서 멈춘다.
    static func detailTitle(_ day: CalendarDay) -> String {
        "\(day.month)월 \(day.day)일"
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

    // MARK: - `01` 권한 요청

    /// `01-N1` — **줄마다 따로 선다.** 형광펜이 첫 줄에만 그어진다.
    static let permissionHeadline = ["마비노기 모바일이 만든", "앨범 하나로 시작해요"]
    /// `01-N2` — 첫 줄이 왜 묻는지, 둘째 줄이 무엇만 읽는지.
    static let permissionBody = """
        앨범 목록을 보려면 사진 접근이 필요해요.
        고른 앨범 안의 사진만 읽어요.
        """
    /// `01-B1`이자 `02-N1` 타이틀. **같은 말이라 같은 문자열이다.**
    static let chooseAlbum = "앨범 고르기"

    // MARK: - `02` 소스 지정

    /// `02-N2` — 왜 게임 앨범이어야 하는지를 한 줄이 진다.
    static let sourceHint = "게임이 사진에 남긴 정보로 순간을 묶어요."
    /// `02-N3` — 온보딩에서 나가는 낱말. 설정에서 들어오면 `취소`다.
    static let later = "나중에"

    /// `02` 부분 접근 — 앨범이라는 낱말을 못 쓴다.
    static let pickPhotos = "사진 고르기"
    static let pickedPhotos = "고른 사진"
    static let pickMorePhotos = "사진 더 고르기"
    static let limitedHint = """
        허용한 사진만 볼 수 있어요.
        새로 찍은 사진은 저절로 들어오지 않아요.
        """

    /// `02` 거부 — 목록이 아예 없다.
    static let bringPhotos = "사진 가져오기"
    static let openSettings = "설정 열기"
    static let deniedHint = """
        사진 접근이 꺼져 있어 앨범을 볼 수 없어요.
        설정에서 켜거나, 사진을 직접 가져올 수 있어요.
        """
    /// `02-L` 스트립의 마지막 칸. ⚠️ **`more`와 상한이 다르다** — `04`는 순간 단위라 안 닿는다.
    static func moreInSource(_ count: Int) -> String {
        count > 999 ? "999+" : more(count)
    }

    // MARK: - `13` 설정

    /// `13-N1`이자 `04-N3`의 낭독 이름.
    static let settingsTitle = "설정"
    static let sourceRow = "소스"
    static let themeRow = "테마"
    static let termsRow = "이용약관"
    static let privacyRow = "개인정보 처리방침"
    static let versionRow = "버전"
    /// `13-L1` — **비활성이다.** 눌러서 도달할 곳이 `M3`에는 없다.
    static let signInRow = "로그인"
    /// `13-F` 계정 슬롯. ⚠️ **계정 상태가 바뀌면 이 자리의 내용이 바뀐다.**
    static let accountUnavailable = ["로그인은 추후 제공 예정이에요", "계정 없이도 전부 쓸 수 있어요"]

    // MARK: - `14` 약관 · 개인정보 처리방침

    /// ⚠️ **잠정 문안이다** — 실제 조항은 배포 앞에 확정한다.
    /// ⚠️ **화면에 뜨는 줄이라 앱 말투다** — 이모지와 내부 어휘를 안 쓴다.
    static let provisionalNotice = "아직 확정된 문안이 아니에요"
    static let effectiveDate = "시행일 2026년 0월 0일"

    static let terms = LegalDocument(title: termsRow, clauses: [
        .init(heading: "제1조 (목적)",
              body: "이 약관은 모아노기가 제공하는 서비스의 이용 조건과 절차, 이용자와 서비스의 권리·의무를 정하는 것을 목적으로 합니다."),
        .init(heading: "제2조 (사진과 저장)",
              body: "서비스는 기기에 있는 사진을 읽기만 하며 원본을 바꾸거나 지우지 않습니다. 기록으로 남기기로 한 사진만 서비스가 복사해 보관합니다."),
        .init(heading: "제3조 (계정)",
              body: "계정 없이 서비스를 이용할 수 있습니다. 만든 기록을 다른 사람에게 보여줄 때 계정이 필요합니다."),
    ])

    /// ⚠️ **약관과 같이 잠정이다.**
    static let privacy = LegalDocument(title: privacyRow, clauses: [
        .init(heading: "제1조 (수집하지 않는 것)",
              body: "당신의 스크린샷은 기기를 떠나지 않습니다. 기록으로 남기기로 한 것만 서비스에 올라갑니다."),
        .init(heading: "제2조 (네트워크)",
              body: "정리하고 기록하는 데 인터넷이 필요 없습니다. 네트워크는 남에게 보여줄 때만 씁니다."),
        .init(heading: "제3조 (공개)",
              body: "기본은 비공개입니다. 공개는 당신이 누를 때만 일어납니다."),
    ])

    // MARK: - `13-A` 테마

    static let appearanceModeSection = "화면 모드"
    static let accentSection = "포인트 컬러"

    static func appearanceMode(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: "시스템 따름"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    /// ⚠️ **화면에 안 쓴다 — 낭독 이름이다.** 색은 눈으로 고르므로 이름이 하는 일이 없다.
    static func accentLabel(_ set: AccentSet) -> String {
        switch set {
        case .terracotta: "테라코타"
        case .burgundy: "버건디"
        case .navy: "먹빛남색"
        case .olive: "이끼 올리브"
        case .ginkgo: "은행잎"
        case .rose: "장미"
        }
    }

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

/// 긴 글 한 판이 그리는 것. **화면은 이 값을 그리기만 한다** — 실제 조항이 확정돼도
/// `Wording`만 갈면 되고 화면은 안 바뀐다.
struct LegalDocument {
    struct Clause {
        let heading: String
        let body: String
    }

    let title: String
    let clauses: [Clause]
}
