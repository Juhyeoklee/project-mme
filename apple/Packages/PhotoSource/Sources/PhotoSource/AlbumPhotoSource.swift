// 앨범 하나를 소스로 읽는 어댑터. ADR 0001 결정 5의 "구현체 교체" 규칙에서 첫 구현체다 —
// macOS 폴더 소스가 오면 조건문이 아니라 같은 일을 하는 다른 타입이 온다.

import Foundation
import Photos

/// 이름이 있는 앨범 하나를 소스로 읽는다.
///
/// 하는 일은 셋이다 — 앨범 찾기 · 자산 열거 · 원본 바이트 로드.
/// 출력이 커널 입력 (파일명, 바이트)를 공급한다 (ADR 0002).
public struct AlbumPhotoSource: Sendable {
    /// 소스로 삼을 앨범의 이름. "어느 이름이 게임 것인가"는 부르는 쪽이 안다.
    public let albumTitle: String

    public init(albumTitle: String) {
        self.albumTitle = albumTitle
    }

    // MARK: - 권한

    /// 지금의 읽기 권한. 묻기만 하고 사용자에게 요청하지 않는다.
    public static func currentAccess() -> ReadAccess {
        ReadAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// 사용자에게 읽기 권한을 요청한다.
    ///
    /// `.readWrite`를 요청하는 것은 플랫폼이 그보다 좁은 읽기 권한을 주지 않기 때문이다.
    /// 이 모듈에 쓰기 경로가 없다는 것은 공개 API와 검증기 ③이 보장한다 (원칙 `P5`).
    public static func requestAccess() async -> ReadAccess {
        ReadAccess(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    // MARK: - 앨범

    /// 라이브러리의 앨범 목록. 무엇으로 소스를 고정할지 정하기 위한 읽기 전용 조회다.
    public static func albums() -> [AlbumSummary] {
        summaries(of: .album) + summaries(of: .smartAlbum)
    }

    private static func summaries(of type: PHAssetCollectionType) -> [AlbumSummary] {
        let fetched = PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil)
        var result: [AlbumSummary] = []
        fetched.enumerateObjects { collection, _, _ in
            // estimatedAssetCount는 스마트 앨범에서 NSNotFound가 나온다. 실제로 세는 쪽이 정확하다.
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            result.append(AlbumSummary(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "",
                assetCount: count,
                isSmart: type == .smartAlbum
            ))
        }
        return result
    }

    // MARK: - 자산 열거

    /// 앨범 안의 사진을 최신순으로 열거한다.
    ///
    /// 정렬에만 촬영 시각을 쓰고 값은 밖으로 내보내지 않는다. `PHAsset.creationDate`는
    /// 파일 안에 대응물이 없어 다른 언어 구현이 재현할 수 없는 값이고(실험 §6),
    /// 커널 입력에 섞이면 ADR 0001 결정 6이 커널 밖에서 깨진다.
    public func assets() throws -> [SourceAsset] {
        let access = Self.currentAccess()
        guard access.canRead else { throw PhotoSourceError.accessNotGranted(access) }

        let collection = try collection()
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        var result: [SourceAsset] = []
        PHAsset.fetchAssets(in: collection, options: options).enumerateObjects { asset, _, _ in
            guard let resource = Self.originalResource(of: asset) else { return }
            result.append(SourceAsset(id: asset.localIdentifier, filename: resource.originalFilename))
        }
        return result
    }

    private func collection() throws -> PHAssetCollection {
        // 술어(predicate)로 제목을 거르지 않는다 — PhotoKit이 컬렉션 술어에 어떤 키를 받아주는지가
        // 문서로 닫혀 있지 않아 조용한 미탐이 될 수 있다. 앨범 수는 작으므로 받아와서 거른다.
        //
        // 같은 이름의 앨범이 둘 이상일 수 있다 — 검증 기기에 실제로 있었다(2026-08-03).
        // 첫 매치를 쓴다. 출시 1은 소스가 코드에 고정이고 그 이름이 유일해서 성립하는 선택이고,
        // 사용자가 소스를 고르는 M3에서는 이름이 아니라 식별자로 잡아야 한다.
        let fetched = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: PHAssetCollection?
        fetched.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == albumTitle {
                found = collection
                stop.pointee = true
            }
        }
        guard let found else { throw PhotoSourceError.albumNotFound(title: albumTitle) }
        return found
    }

    private static func originalResource(of asset: PHAsset) -> PHAssetResource? {
        // .photo가 원본이다. 편집본(.fullSizePhoto)은 원본이 아니므로 받지 않는다 (원칙 `P5`).
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

    /// 화면에 그릴 이미지. **원본이 아니라 라이브러리가 만들어 둔 표시용 사본이다.**
    ///
    /// `originalBytes`와 경로가 다르다는 것이 이 메서드의 존재 이유다. 라이브러리는 저해상도
    /// 사본을 로컬에 들고 있어서, 원본이 iCloud에만 있는 사진(`R8`)도 여기서는 즉시 돌아올 수 있다.
    /// **얼마나 즉시인지는 실기기가 답한다** — 화면설계서 §5 항목 13·14의 입력이 이 갈림이다.
    ///
    /// 분류 신호는 여기서 오지 않는다. 신호는 원본 파일의 `iTXt`에 있고 그것은 `originalBytes`
    /// 만이 준다 — 두 경로를 섞으면 ADR 0001 결정 6의 "생산 과정도 계약이다"가 깨진다.
    ///
    /// `CGImage`를 돌려주는 것은 플랫폼 중립이라서다. SwiftUI가 `Image(decorative:scale:)`로
    /// 바로 받고, `App`이 `UIKit`에 묶이지 않는다.
    ///
    /// - Parameter maxPixelSize: 긴 변의 상한. 종횡비는 유지된다.
    public func image(of asset: SourceAsset,
                      maxPixelSize: Int,
                      allowingNetwork: Bool) async throws -> CGImage {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil).firstObject
        else { throw PhotoSourceError.assetNotFound(assetID: asset.id) }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        // .fast는 타겟보다 큰 사본을 줄 수 있다. 211장을 캐시에 얹는 쪽이라 크기를 못 박는다.
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
                // deliveryMode가 .highQualityFormat이면 콜백은 한 번이지만, 그 보장에 기대지 않는다.
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

    /// 이번 호출이 처음이면 `true`. 두 번째부터는 `false`.
    func open() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

// PhotoKit이 돌려주는 이미지 타입이 플랫폼마다 다르다. `CGImage`로 좁히는 곳은 여기 한 곳뿐이고,
// 공개 API는 이미 플랫폼 중립이다 — 이 분기가 밖으로 새지 않는다.
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
