// 표시용 이미지 캐시. **키는 (자산, 크기)** — 같은 사진을 세 크기로 들고 있고,
// 작은 것을 늘려 큰 자리에 쓰지 않는다.
//
// **네트워크는 `06`에서만 연다.** 훑는 동안 다운로드가 시작되면 목록을 넘기는 것만으로 분 단위
// 대기가 쌓인다(`R8` 실측 2026-08-03: 한 장 최대 441초). **실패는 캐시하지 않는다** — 못 읽은
// 이유는 대개 "아직"이라 영구 기억하면 영영 회색이다.

import CoreGraphics
import Foundation
import Observation
import PhotoSource

/// 표시용 이미지 캐시. 같은 (자산, 크기)를 동시에 여러 번 물어도 요청은 하나다.
@MainActor
@Observable
final class ImageStore {
    /// 한 장을 끌어오는 일. **주입 가능한 이음매다** — 프리뷰가 합성 이미지를 여기로 먹인다.
    typealias Loader = @MainActor (SourceAsset, Int, Bool) async -> CGImage?

    private let load: Loader
    private let cache = NSCache<NSString, Box>()
    private var inFlight: [String: Task<CGImage?, Never>] = [:]

    convenience init(source: AlbumPhotoSource, memoryLimitBytes: Int = 96 * 1024 * 1024) {
        self.init(loader: { asset, pixels, network in
            try? await source.image(of: asset, maxPixelSize: pixels, allowingNetwork: network)
        }, memoryLimitBytes: memoryLimitBytes)
    }

    init(loader: @escaping Loader, memoryLimitBytes: Int = 96 * 1024 * 1024) {
        self.load = loader
        cache.totalCostLimit = memoryLimitBytes
    }

    func cached(_ asset: SourceAsset, pixels: Int) -> CGImage? {
        cache.object(forKey: Self.key(asset, pixels) as NSString)?.image
    }

    /// 캐시에 없으면 읽어 온다.
    func image(_ asset: SourceAsset, pixels: Int, allowingNetwork: Bool = false) async -> CGImage? {
        let key = Self.key(asset, pixels)
        if let hit = cache.object(forKey: key as NSString)?.image { return hit }
        if let running = inFlight[key] { return await running.value }

        let task = Task { [load] () -> CGImage? in
            await load(asset, pixels, allowingNetwork)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            cache.setObject(Box(image), forKey: key as NSString, cost: image.height * image.bytesPerRow)
        }
        return image
    }

    private static func key(_ asset: SourceAsset, _ pixels: Int) -> String {
        "\(asset.id)@\(pixels)"
    }

    /// `NSCache`는 클래스만 담는다.
    private final class Box {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
}
