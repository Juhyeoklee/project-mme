// 입력과 그 해석 결과.
//
// **커널 입력 = 사진별 (파일명, 바이트)** — ADR `0002`. 바이트가 선택값인 이유는 `PhotoInput`에.
// **커널에 식별자 개념이 없다** — 출력은 입력 배열의 인덱스고, 원본과 잇는 일은 `App`이 한다.

/// 사진 한 장의 입력.
///
/// **바이트는 없을 수 있다** — `R8`(원본이 iCloud에만 있을 때의 극단 지연) 때문에 2패스로 도는데
/// **파일명은 1패스에 전량 들어오기** 때문이다. 계약은 `Classifier.classify(_:settings:)`에.
public struct PhotoInput: Sendable, Hashable {
    public let filename: String
    /// `nil` = 아직 안 읽었다. 다음 패스에서 채워진다.
    public let bytes: [UInt8]?

    public init(filename: String, bytes: [UInt8]? = nil) {
        self.filename = filename
        self.bytes = bytes
    }
}

/// 카메라 위치와 회전이 이 형태로 들어 있다.
public struct Vector3: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public func distance(to other: Vector3) -> Double {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    /// 각도 벡터로 볼 때의 거리. **360도 되감기를 접는다** — 안 접으면 359도와 1도가
    /// 358도 차이로 읽힌다. 표본에 실제로 있었다(2026-08-03).
    public func angularDistance(to other: Vector3) -> Double {
        let dx = Vector3.fold(x - other.x)
        let dy = Vector3.fold(y - other.y)
        let dz = Vector3.fold(z - other.z)
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    private static func fold(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360).magnitude
        return wrapped > 180 ? 360 - wrapped : wrapped
    }

    /// `<-36.61901, 47.02017, -36.97002>` 형태를 읽는다.
    static func parse(_ text: String) -> Vector3? {
        var body = Substring(text)
        while let first = body.first, first == " " { body = body.dropFirst() }
        while let last = body.last, last == " " { body = body.dropLast() }
        guard body.first == "<", body.last == ">", body.count >= 2 else { return nil }
        body = body.dropFirst().dropLast()
        let parts = body.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var values: [Double] = []
        for part in parts {
            guard let value = Double(part.trimmingSpaces()), value.isFinite else { return nil }
            values.append(value)
        }
        return Vector3(x: values[0], y: values[1], z: values[2])
    }
}

extension Substring {
    func trimmingSpaces() -> Substring {
        var slice = self
        while let first = slice.first, first == " " || first == "\t" { slice = slice.dropFirst() }
        while let last = slice.last, last == " " || last == "\t" { slice = slice.dropLast() }
        return slice
    }
}

/// 바이트에서 꺼낸 분류 신호. 여기 있는 것이 곧 **`M5` 웹 자산 구현이 재현해야 할 전부**다
/// (ADR `0001` 결정 6). 쓰지 않는 필드는 파싱도 노출도 안 한다 — 노출하면 언젠가 계약이 된다.
public struct CaptureSignals: Sendable, Hashable {
    /// **좌표계가 구역마다 별개라** 장소 판정의 하드 파티션으로 쓴다.
    public let zoneName: String
    public let cameraPosition: Vector3
    public let cameraRotation: Vector3
    public let fieldOfView: Double
    public let pixelWidth: Int
    public let pixelHeight: Int

    /// 종횡비가 같은가. 정수 교차곱이라 부동소수 오차가 없다.
    public func hasSameAspectRatio(as other: CaptureSignals) -> Bool {
        pixelWidth * other.pixelHeight == other.pixelWidth * pixelHeight
    }
}

/// 신호를 못 얻은 이유. **제품 규칙이 아니라 사실의 보고다** — 화면이 이 값으로 무엇을 할지는
/// 커널이 정하지 않는다.
public enum SignalStatus: Sendable, Hashable {
    case ok
    /// 바이트를 안 넘겼다. 실패가 아니라 **아직**이다.
    case bytesNotProvided
    case notPNG
    case malformedPNG
    /// PNG인데 `iTXt`가 없다.
    case textChunkMissing
    /// 필요한 값이 **압축된** `iTXt` 안에 있다. ADR `0002` 대가 2가 예고한 자리 —
    /// 풀려면 zlib이 필요하고 그건 import 0을 깬다. **새 결정이 필요하다.**
    case textChunkCompressed
    case fieldMissing(String)
    case fieldUnparsable(String)
}

/// 사진 한 장을 읽은 결과. 두 사실이 **서로 독립**이다 —
/// 시각은 파일명에서, 신호는 바이트에서 온다.
public struct PhotoReading: Sendable, Hashable {
    /// `nil`이면 시간축에 놓을 수 없다 → `Classification.unplaced`.
    public let capturedAt: WallClock?
    /// `nil`이면 장소 분할과 연사 접기에 **참여하지 않는다**. 이유는 `signalStatus`.
    public let signals: CaptureSignals?
    public let signalStatus: SignalStatus
}

enum SignalReader {
    static let zoneKey = "Location Display Name"
    static let cameraPositionKey = "Camera Position"
    static let cameraRotationKey = "Camera Rotation"
    static let fieldOfViewKey = "Camera Fov Degree"

    static func read(_ input: PhotoInput) -> PhotoReading {
        let capturedAt = WallClock.fromCaptureFilename(input.filename)
        let (signals, status) = readSignals(input.bytes)
        return PhotoReading(capturedAt: capturedAt, signals: signals, signalStatus: status)
    }

    private static func readSignals(_ bytes: [UInt8]?) -> (CaptureSignals?, SignalStatus) {
        guard let bytes else { return (nil, .bytesNotProvided) }
        let scan: PNGScan
        switch PNGText.scan(bytes) {
        case .success(let value): scan = value
        case .failure(.notPNG): return (nil, .notPNG)
        case .failure(.malformed): return (nil, .malformedPNG)
        }
        if scan.text.isEmpty {
            return (nil, scan.sawCompressedText ? .textChunkCompressed : .textChunkMissing)
        }

        // 첫 실패 하나를 그대로 보고한다 — 뭉개지 않는다.
        var failure: SignalStatus?
        func text(_ key: String) -> String? {
            guard let value = scan.text[key] else {
                // 압축 청크를 봤다면 그 안에 있었을 수 있다.
                failure = failure ?? (scan.sawCompressedText ? .textChunkCompressed
                                                            : .fieldMissing(key))
                return nil
            }
            return value
        }
        func vector(_ key: String) -> Vector3? {
            guard let raw = text(key) else { return nil }
            guard let value = Vector3.parse(raw) else {
                failure = failure ?? .fieldUnparsable(key)
                return nil
            }
            return value
        }
        func number(_ key: String) -> Double? {
            guard let raw = text(key) else { return nil }
            guard let value = Double(Substring(raw).trimmingSpaces()), value.isFinite else {
                failure = failure ?? .fieldUnparsable(key)
                return nil
            }
            return value
        }

        let zone = text(zoneKey)
        let position = vector(cameraPositionKey)
        let rotation = vector(cameraRotationKey)
        let fieldOfView = number(fieldOfViewKey)

        guard let zone, let position, let rotation, let fieldOfView else {
            return (nil, failure ?? .textChunkMissing)
        }
        return (CaptureSignals(zoneName: zone,
                               cameraPosition: position,
                               cameraRotation: rotation,
                               fieldOfView: fieldOfView,
                               pixelWidth: scan.pixelWidth,
                               pixelHeight: scan.pixelHeight), .ok)
    }
}
