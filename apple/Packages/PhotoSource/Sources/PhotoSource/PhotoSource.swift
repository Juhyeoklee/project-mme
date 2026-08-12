// PhotoSource — 사진 라이브러리를 아는 유일한 모듈. **공개 API에 쓰기 연산 없음**
// (ADR `0001` 결정 2 · `scripts/verify-boundaries.swift`가 강제한다). **게임 지식도 없다** —
// 어느 앨범이 게임 것인지는 주입받고, 하는 일은 컨테이너 찾기·열거·바이트 읽기다 (ADR `0002`).
// 이 파일은 계약 타입만 담는다. 구현은 `AlbumPhotoSource.swift`.

import Foundation

/// 소스 안의 사진 한 장을 가리키는 손잡이. 바이트는 아직 읽지 않았다.
///
/// `filename`은 커널 입력의 절반이고(ADR `0002`) 원본이 기기에 없어도 읽히므로,
/// 로드에 실패한 사진도 이름으로 지목할 수 있다.
///
/// ⚠️ **화소 크기는 분류 신호가 아니다.** 커널이 읽는 값은 `IHDR`에서 오고(ADR `0004`)
/// 여기 것은 배치에만 쓴다 — **커널 입력에 넣지 마라.**
public struct SourceAsset: Sendable, Hashable, Identifiable {
    /// 라이브러리 안에서의 식별자. 이 모듈 밖에서는 불투명한 문자열이다.
    public let id: String
    public let filename: String
    /// 원본의 화소 크기. **열거 시점에 온다** — 바이트도 네트워크도 안 기다린다.
    /// 0이면 라이브러리가 크기를 모른다는 뜻이다.
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(id: String, filename: String, pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.filename = filename
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// 읽기 접근 상태. 플랫폼이 주는 가장 좁은 읽기 권한이 `.readWrite`라 그것을 요청하지만,
/// 공개 API에는 쓰기가 없고 쓰기 심볼 금지는 검증기가 강제한다 (원칙 `P5`).
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
    case accessNotGranted(ReadAccess)
    case albumNotFound(title: String)
    /// 자산이 사라졌거나 식별자가 더 이상 유효하지 않다.
    case assetNotFound(assetID: String)
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
