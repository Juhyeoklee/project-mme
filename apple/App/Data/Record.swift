// 기록 — 이 앱의 첫 영속 데이터. 디스크 형태와 저장소는 `RecordStore.swift`.

import Foundation
import MomentKernel

/// 사용자가 남긴 기록 하나.
///
/// **갤러리든 캔버스든 한 형태다** — 이미지 배열 + 설명 텍스트. 캔버스는 별도 종류가 아니라
/// 그 이미지를 만드는 방법이다.
///
/// ⚠️ **순간을 참조하지 않는다** (원칙 `P2`). 사진이 어느 순간에서 왔는지는 남기지 않는다 —
/// 남기면 순간 목록이 기록 여부에 따라 달라지는 경로가 생긴다.
struct Record: Identifiable, Hashable, Sendable {
    let id: UUID
    /// `REC-07` 발생일시. 소스 안 사진의 가장 이른 촬영시각으로 자동 설정되고 사용자가 고친다.
    var occurredAt: WallClock
    /// 표시 순서. `REC-10`으로 가져온 사진은 시각을 안 쓰므로 더한 순서대로 끝에 붙는다.
    var images: [RecordImage]
    /// `REC-06`.
    var caption: String
    var status: Status
    /// 마지막으로 고친 **절대 시각.** 벽시계가 아닌 이유는 이 값의 쓸 곳이 기기 간 비교라서다 —
    /// 시간대 없이는 어느 기기의 수정이 나중인지 못 가른다.
    var updatedAt: Date

    /// `ARC-08` 초안 여부.
    ///
    /// ⚠️ **저장된 상태지 파생값이 아니다.** *설명이 비었으면 초안* 으로 되돌리면 초안 상세의
    /// `게시`가 성립하지 않는다 — 눌러도 설명이 없어 계속 초안이다.
    enum Status: String, Sendable, Hashable {
        case draft
        case published
    }
}

/// 기록에 든 이미지 한 장.
///
/// **바이트는 기록 디렉터리 안에 복사돼 있다.** 원본을 앨범에서 지워도, 원본이 기기에 없어도
/// (`R8`) 기록은 열린다.
struct RecordImage: Identifiable, Hashable, Sendable {
    let id: UUID
    /// 파일 이름은 `id`가 정하고 자리는 저장소가 안다. 여기 있는 것은 확장자뿐이다.
    let fileExtension: String
    let origin: Origin

    /// 이 이미지가 어디서 왔는가. **`REC-07` 자동값에 참여하는가를 이것이 가른다.**
    enum Origin: Hashable, Sendable {
        /// 소스 안에서 왔다.
        ///
        /// ⚠️ `assetID`는 **참조가 아니라 출처 표지다.** 이미지를 다시 읽는 데 쓰지 않는다 —
        /// 쓰기 시작하면 원본이 사라진 기록이 깨지고, 복사로 산 성질을 도로 잃는다.
        case source(assetID: String, capturedAt: WallClock)
        /// `REC-10` 직접 가져오기. 촬영 정보를 읽지 않으므로 시각이 없다.
        case imported
    }

    /// 소스 안에서 왔으면 그 촬영시각.
    var capturedAt: WallClock? {
        if case .source(_, let capturedAt) = origin { return capturedAt }
        return nil
    }

    /// 출처 표지. ⚠️ **이미지를 다시 읽는 데 쓰지 않는다** — 위 `origin`의 경고 그대로다.
    var assetID: String? {
        if case .source(let assetID, _) = origin { return assetID }
        return nil
    }
}
