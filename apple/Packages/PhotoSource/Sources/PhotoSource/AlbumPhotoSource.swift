// 앨범 하나를 소스로 읽는 어댑터. "구현체 교체" 규칙의 첫 구현체다 —
// macOS 폴더 소스가 오면 조건문이 아니라 같은 일을 하는 다른 타입이 온다.

import Foundation
import Photos

/// 앨범 하나를 소스로 읽는다 — 앨범 찾기 · 자산 열거 · 원본 바이트 로드.
/// 출력이 커널 입력 (파일명, 바이트)를 공급한다.
///
/// **후보를 고르는 일은 `AlbumCatalog`이 진다** — 이 타입은 이미 정해진 하나만 읽는다.
public struct AlbumPhotoSource: Sendable {
    /// 소스로 삼을 앨범의 식별자. "어느 것이 게임 것인가"는 부르는 쪽이 안다.
    ///
    /// ⚠️ **이름이 아니다** — 같은 이름의 앨범이 둘 이상일 수 있고, 이름은 사용자가 바꾼다.
    public let albumID: String

    public init(albumID: String) {
        self.albumID = albumID
    }

    /// 이 앨범의 지금 이름. **저장하지 않고 물을 때마다 읽는다** — 사용자가 바꾸면 따라간다.
    public func title() throws -> String {
        try collection().localizedTitle ?? ""
    }

    // MARK: - 권한

    /// 지금의 읽기 권한. 묻기만 하고 사용자에게 요청하지 않는다.
    public static func currentAccess() -> ReadAccess {
        ReadAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// `.readWrite`를 요청하는 것은 플랫폼이 그보다 좁은 읽기 권한을 주지 않기 때문이다.
    /// 쓰기 경로가 없다는 것은 공개 API와 검증기 ③이 보장한다 (원칙 `P5`).
    public static func requestAccess() async -> ReadAccess {
        ReadAccess(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    // MARK: - 자산 열거

    /// 앨범 안의 사진을 최신순으로 열거한다.
    ///
    /// **이름을 얻은 사진은 전부 넘긴다.**
    ///
    /// ⚠️ **첨자는 이 목록 안에서만 뜻이 있고 열거할 때마다 달라진다** — 최신순이라 새 사진이
    /// 앞에 붙으면 뒤가 전부 밀린다. 첨자로 사진을 붙들어 두는 자리가 있으면 `SRC-03`에 깨진다.
    public func assets() throws -> [SourceAsset] {
        let access = Self.currentAccess()
        guard access.canRead else { throw PhotoSourceError.accessNotGranted(access) }

        let collection = try collection()
        var result: [SourceAsset] = []
        PHAsset.fetchAssets(in: collection, options: Self.imageOptions).enumerateObjects { asset, _, _ in
            if let asset = asset.sourceAsset { result.append(asset) }
        }
        return result
    }

    /// 같은 사진들의 식별자만. **`assets()`보다 훨씬 싸다** — 자산마다 리소스를 묻지 않는다.
    ///
    /// 소스가 정말 바뀌었는지 대조하는 데만 쓴다 (`SRC-03`). 라이브러리는 무엇이 바뀌었는지
    /// 안 가리고 통지하므로, 무관한 변경에 전량 열거를 무는 것을 이 대조가 막는다.
    ///
    /// ⚠️ **`assets()`가 이름 없는 사진을 버리는 것과 달리 여기는 안 버린다.** 대조에는 그
    /// 차이가 안 걸린다 — 거르는 판정이 자산마다 결정적이라, 식별자가 같으면 거른 결과도 같다.
    public func assetIDs() throws -> [String] {
        let access = Self.currentAccess()
        guard access.canRead else { throw PhotoSourceError.accessNotGranted(access) }
        return Self.identifiers(PHAsset.fetchAssets(in: try collection(), options: Self.imageOptions))
    }

    /// 부분 접근에서의 같은 것. ⚠️ **`permittedAssets()`와 같은 이유로 `.limited`에서만 연다.**
    public static func permittedAssetIDs() throws -> [String] {
        let access = currentAccess()
        guard access == .limited else { throw PhotoSourceError.accessNotGranted(access) }
        return identifiers(PHAsset.fetchAssets(with: imageOptions))
    }

    private static func identifiers(_ fetched: PHFetchResult<PHAsset>) -> [String] {
        var result: [String] = []
        fetched.enumerateObjects { asset, _, _ in result.append(asset.localIdentifier) }
        return result
    }

    /// 사진만, 최신 먼저. **열거하는 네 자리가 같은 값을 써야** 식별자 대조가 성립한다.
    private static var imageOptions: PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return options
    }

    /// 사용자가 허용한 사진 전부. **부분 접근에는 앨범이 없어 이 집합이 곧 컨테이너다.**
    ///
    /// ⚠️ **부분 접근에서만 연다** — 전체 접근에서 부르면 라이브러리를 통째로 훑어 `SRC-08`이
    /// 깨진다. 부르는 쪽의 조심이 아니라 여기서 막는다.
    public static func permittedAssets() throws -> [SourceAsset] {
        let access = currentAccess()
        guard access == .limited else { throw PhotoSourceError.accessNotGranted(access) }

        var result: [SourceAsset] = []
        PHAsset.fetchAssets(with: imageOptions).enumerateObjects { asset, _, _ in
            if let asset = asset.sourceAsset { result.append(asset) }
        }
        return result
    }

    /// ⚠️ **사용자가 앨범을 지우면 여기서 실패한다** — 식별자는 남아 있어도 가리킬 것이 없다.
    private func collection() throws -> PHAssetCollection {
        let fetched = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID],
                                                             options: nil)
        guard let found = fetched.firstObject else {
            throw PhotoSourceError.albumNotFound(id: albumID)
        }
        return found
    }

    private static func originalResource(of asset: PHAsset) -> PHAssetResource? {
        // `.photo`가 원본이다. 편집본(`.fullSizePhoto`)은 받지 않는다 (원칙 `P5`).
        PHAssetResource.assetResources(for: asset).first { $0.type == .photo }
    }

    // MARK: - 원본 바이트

    /// 사진의 원본 파일 바이트를 그대로 읽는다. 디코딩도 변환도 하지 않는다.
    ///
    /// - Parameter allowingNetwork: 원본이 기기에 없을 때 iCloud에서 받아올지. `false`면
    ///   기기에 없는 사진이 `.originalNotOnDevice`로 즉시 실패한다 — 리스크 `R8`을 재는 손잡이다.
    public func originalBytes(of asset: SourceAsset, allowingNetwork: Bool) async throws -> Data {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil).firstObject
        else { throw PhotoSourceError.assetNotFound(assetID: asset.id) }
        guard let resource = Self.originalResource(of: phAsset)
        else { throw PhotoSourceError.noOriginalResource(assetID: asset.id) }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowingNetwork

        let sink = ByteSink()
        let assetID = asset.id
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in sink.append(chunk) },
                completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: Self.mapped(error, assetID: assetID))
                    } else {
                        continuation.resume(returning: sink.take())
                    }
                }
            )
        }
    }

    // MARK: - 표시용 이미지

    /// 화면에 그릴 이미지. **원본이 아니라 라이브러리가 만들어 둔 표시용 사본이다** — 그래서
    /// 원본이 iCloud에만 있는 사진(`R8`)도 여기서는 즉시 돌아올 수 있다.
    /// ⚠️ **얼마나 즉시인지는 「판정 불가」다** — iCloud에만 있는 사진을 실기기에서 띄워야 판정된다.
    ///
    /// **분류 신호는 여기서 오지 않는다** — 신호는 원본 `iTXt`에 있고 `originalBytes`만이 준다.
    /// 두 경로를 섞으면 "입력값의 생산 과정도 계약이다"가 깨진다.
    ///
    /// - Parameter maxPixelSize: 긴 변의 상한. 종횡비는 유지된다.
    public func image(of asset: SourceAsset,
                      maxPixelSize: Int,
                      allowingNetwork: Bool) async throws -> CGImage {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil).firstObject
        else { throw PhotoSourceError.assetNotFound(assetID: asset.id) }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        // ⚠️ `.fast`는 타겟보다 큰 사본을 줄 수 있다 — 수백 장을 캐시에 얹으므로 못 박는다.
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = allowingNetwork
        options.isSynchronous = false

        let target = CGSize(width: maxPixelSize, height: maxPixelSize)
        let gate = ResumeGate()
        let assetID = asset.id
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(
                for: phAsset, targetSize: target, contentMode: .aspectFit, options: options
            ) { image, info in
                // .highQualityFormat이면 콜백은 한 번이지만 그 보장에 기대지 않는다 —
                // 두 번째 resume은 크래시다.
                guard gate.open() else { return }
                if let image, let cgImage = Self.cgImage(from: image) {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: Self.imageFailure(info, assetID: assetID))
                }
            }
        }
    }

    static func imageFailure(_ info: [AnyHashable: Any]?, assetID: String) -> PhotoSourceError {
        if let error = info?[PHImageErrorKey] as? any Error {
            return mapped(error, assetID: assetID)
        }
        if info?[PHImageResultIsInCloudKey] as? Bool == true {
            return .originalNotOnDevice(assetID: assetID)
        }
        if info?[PHImageCancelledKey] as? Bool == true {
            return .loadFailed(assetID: assetID, reason: "취소됨")
        }
        return .loadFailed(assetID: assetID, reason: "이미지 없음 (이유 미제공)")
    }

    static func mapped(_ error: any Error, assetID: String) -> PhotoSourceError {
        if let photosError = error as? PHPhotosError, photosError.code == .networkAccessRequired {
            return .originalNotOnDevice(assetID: assetID)
        }
        let ns = error as NSError
        return .loadFailed(assetID: assetID, reason: "\(ns.domain) \(ns.code): \(ns.localizedDescription)")
    }
}

// MARK: -

/// 조각으로 도착하는 바이트를 모은다. 콜백이 어느 큐에서 오는지 보장이 없어 잠금을 건다.
final class ByteSink: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(chunk)
    }

    func take() -> Data {
        lock.lock()
        defer { lock.unlock() }
        let taken = buffer
        buffer = Data()
        return taken
    }
}

/// 콜백이 두 번 와도 continuation을 한 번만 푼다.
final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func open() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

// PhotoKit이 돌려주는 이미지 타입이 플랫폼마다 다르다. **`CGImage`로 좁히는 곳은 여기뿐이라**
// 이 분기가 밖으로 새지 않는다.
#if canImport(UIKit)
import UIKit

extension AlbumPhotoSource {
    static func cgImage(from image: UIImage) -> CGImage? { image.cgImage }
}
#elseif canImport(AppKit)
import AppKit

extension AlbumPhotoSource {
    static func cgImage(from image: NSImage) -> CGImage? {
        image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif

extension PHAsset {
    /// `SourceAsset`을 만드는 유일한 자리 — 열거와 후보 목록이 같은 규칙을 쓴다.
    var sourceAsset: SourceAsset? {
        // 이름을 못 얻으면 버린다 — 그 절반이 커널 입력이다.
        // 원본(`.photo`)이 없어도 이름은 얻는다 — 바이트 없는 사진도 시간축에 참여한다.
        let resources = PHAssetResource.assetResources(for: self)
        guard let filename = (resources.first { $0.type == .photo }
                              ?? resources.first)?.originalFilename else { return nil }
        return SourceAsset(id: localIdentifier, filename: filename,
                           pixelWidth: pixelWidth, pixelHeight: pixelHeight,
                           creationDate: creationDate)
    }
}

extension ReadAccess {
    init(_ status: PHAuthorizationStatus) {
        self = switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .restricted
        }
    }
}
