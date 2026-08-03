// PhotoSource — 사진 라이브러리를 아는 유일한 모듈. 공개 API에 쓰기 연산 없음 (ADR 0001 결정 2).
// 게임 지식 없음 — 컨테이너를 찾고, 자산을 열거하고, 바이트를 읽는 것까지가 이 모듈의 일이다 (ADR 0002).
// 어느 앨범이 게임 것인지도 이 모듈의 지식이 아니다 — 앨범 이름은 주입받는다.
// 쓰기 심볼 금지는 scripts/verify-boundaries.swift가 강제한다.
//
// 이 파일은 계약 타입만 담는다. 구현은 AlbumPhotoSource.swift.

import Foundation

/// 소스 안의 사진 한 장을 가리키는 손잡이. 바이트는 아직 읽지 않았다.
///
/// `filename`은 커널 입력의 절반이다 (ADR 0002 — 커널 입력 = 사진별 (파일명, 바이트)).
/// 원본이 기기에 없어도 읽히므로, 로드에 실패한 사진도 이름으로 지목할 수 있다.
public struct SourceAsset: Sendable, Hashable, Identifiable {
    /// 라이브러리 안에서의 식별자. 이 모듈 밖에서는 불투명한 문자열이다.
    public let id: String
    /// 원본 파일 이름.
    public let filename: String

    public init(id: String, filename: String) {
        self.id = id
        self.filename = filename
    }
}

/// 라이브러리가 갖고 있는 앨범 하나의 요약. 무엇으로 소스를 고정할지 정하기 위한 읽기 전용 목록이다.
public struct AlbumSummary: Sendable, Hashable {
    public let id: String
    public let title: String
    public let assetCount: Int
    /// 사용자가 만든 앨범인지 시스템이 만든 스마트 앨범인지. 소스 고정 방법을 가르는 값이다.
    public let isSmart: Bool

    public init(id: String, title: String, assetCount: Int, isSmart: Bool) {
        self.id = id
        self.title = title
        self.assetCount = assetCount
        self.isSmart = isSmart
    }
}

/// 읽기 접근 상태.
///
/// 플랫폼이 제공하는 가장 좁은 읽기 권한이 `.readWrite`라 그것을 요청하지만,
/// 이 모듈의 공개 API에는 쓰기가 없고 쓰기 심볼 금지는 검증기가 강제한다 (원칙 `P5`).
public enum ReadAccess: Sendable, Hashable, CustomStringConvertible {
    case notDetermined
    case restricted
    case denied
    case authorized
    /// 사용자가 일부 사진만 골라 허용했다. 앨범이 통째로 안 보일 수 있다.
    case limited

    /// 자산을 열거해 볼 가치가 있는 상태인가.
    public var canRead: Bool {
        switch self {
        case .authorized, .limited: true
        case .notDetermined, .restricted, .denied: false
        }
    }

    public var description: String {
        switch self {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        case .limited: "limited"
        }
    }
}

/// 어댑터가 말하는 실패. 리스크 `R8`이 사는 자리가 `originalNotOnDevice`다.
public enum PhotoSourceError: Error, Sendable, Hashable, CustomStringConvertible {
    /// 읽기 권한이 없다.
    case accessNotGranted(ReadAccess)
    /// 그 이름의 앨범이 없다.
    case albumNotFound(title: String)
    /// 자산이 사라졌거나 식별자가 더 이상 유효하지 않다.
    case assetNotFound(assetID: String)
    /// 원본 파일에 해당하는 리소스가 없다.
    case noOriginalResource(assetID: String)
    /// **`R8`** — 원본이 기기에 없고 네트워크 접근이 막혀 있다.
    case originalNotOnDevice(assetID: String)
    /// 그 밖의 로드 실패. 원문을 그대로 들고 온다 — 추측으로 뭉개지 않는다.
    case loadFailed(assetID: String, reason: String)

    public var description: String {
        switch self {
        case .accessNotGranted(let access): "권한 없음 (\(access))"
        case .albumNotFound(let title): "앨범 없음: \"\(title)\""
        case .assetNotFound(let id): "자산 없음: \(id)"
        case .noOriginalResource(let id): "원본 리소스 없음: \(id)"
        case .originalNotOnDevice(let id): "원본이 기기에 없음 (R8): \(id)"
        case .loadFailed(let id, let reason): "로드 실패: \(id) — \(reason)"
        }
    }
}
