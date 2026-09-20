// `04`가 한 줄로 세우고 `05`가 여는 덩어리. 순간이거나, 날짜만 가진 사진 묶음이다.

import MomentKernel

/// 화면이 다루는 사진 덩어리 하나.
///
/// **커널의 출력 둘을 한 타입으로 받는다** — `Moment`와 `Day.dateOnlyPhotos`다. 격자도
/// 스트립도 보는 것은 둘 다 「장면의 목록」이라 같고, 갈리는 것은 **머리가 시각을 말할 수
/// 있는가** 하나뿐이다.
///
/// ⚠️ **커널 타입이 아니다.** 커널은 이 둘을 갈라 두는 것이 옳고(하나는 시간축에 있고 하나는
/// 없다), 합치는 판단은 화면의 것이다.
struct PhotoGroup: Hashable, Identifiable {
    /// 이 덩어리가 선 날짜.
    let day: CalendarDay
    /// 시간축에서 시작하는 자리. **`nil`이면 날짜만 가진 묶음이다.**
    let start: WallClock?
    /// 장면 목록. **비어 있지 않고 장면마다 사진이 1장 이상이다** — 커널의 `Moment`가 그
    /// 불변을 지고, 날짜만 묶음은 아래 이니셜라이저가 빈 것을 거른다.
    ///
    /// **날짜만 묶음은 전부 1장짜리 장면이다** — 연사 접기가 바이트를 요구하는데
    /// 그 사진들의 바이트는 읽지 않는다.
    let scenes: [[Int]]

    /// 목록 행의 신원. **첫 사진의 첨자다.**
    ///
    /// ⚠️ **장면 구성을 신원에 넣으면 안 된다** — 2패스가 바이트를 채우며 재분류를 돌리는
    /// 동안 장면이 계속 다시 갈리고, 그때마다 행이 통째로 헐렸다 다시 선다.
    var id: Int { scenes[0][0] }

    init(moment: Moment, day: CalendarDay) {
        self.day = day
        self.start = moment.start
        self.scenes = moment.scenes.map(\.photoIndices)
    }

    /// 날짜만 가진 사진들로 묶음 하나를 만든다. 비어 있으면 `nil` — 빈 카드가 서지 않는다.
    init?(dateOnly photos: [Int], day: CalendarDay) {
        guard !photos.isEmpty else { return nil }
        self.day = day
        self.start = nil
        self.scenes = photos.map { [$0] }
    }

    /// 시각을 아는 묶음인가. 머리와 요약 줄이 이 값으로 갈린다.
    var isPlaced: Bool { start != nil }

    var photoIndices: [Int] { scenes.flatMap { $0 } }
    var photoCount: Int { scenes.reduce(0) { $0 + $1.count } }
    var sceneCount: Int { scenes.count }
}

extension Day {
    /// 이 날이 세우는 덩어리 전부. **순간이 먼저고 날짜만 묶음이 맨 뒤다** — 시각이 없는
    /// 것을 시간축 사이에 끼우면 목록의 순서가 거짓말이 된다.
    var groups: [PhotoGroup] {
        moments.map { PhotoGroup(moment: $0, day: date)
        } + [PhotoGroup(dateOnly: dateOnlyPhotos, day: date)].compactMap { $0 }
    }
}
