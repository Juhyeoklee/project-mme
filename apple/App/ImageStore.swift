// 표시용 이미지 캐시.
//
// 층위마다 크기가 다르다(설계서 §1.1) — `04` 118 정사각, `05` 셀 폭, `06` 화면 폭. 같은 사진을
// 세 크기로 들고 있게 되므로 키는 (자산, 크기)다. 작은 것을 늘려 큰 자리에 쓰지 않는다:
// 훑기 층위의 픽셀을 보기 층위로 끌어올리면 "들어갈수록 더 보인다"가 거짓말이 된다.
//
// **네트워크는 `06`에서만 연다.** 훑는 동안 다운로드가 시작되면 목록을 넘기는 것만으로 분 단위
// 대기가 쌓인다(`R8` 실측: 한 장 최대 441초). 사용자가 사진 한 장을 지목했을 때만 값을 치른다.
// 목록에서 못 그린 칸은 회색으로 남고, 2패스가 원본을 받아오면 `generation`이 올라 다시 묻는다.
//
// **실패를 캐시하지 않는다.** 못 읽은 이유는 대개 "아직"이라 영구 기억하면 영영 회색이다.

import CoreGraphics
import Foundation
import Observation
import PhotoSource

@MainActor
@Observable
final class ImageStore {
    /// `04-C3` 썸네일 118pt. 3배 화면 기준.
    static let thumbnailPixels = 354
    /// `05-G1` 셀. iPad 4열의 셀 폭(194pt)이 상한이라 그 3배를 잡는다.
    static let gridPixels = 600
    /// `06-G1` 전체화면. 표본 원본이 1680×1167이라 그 위로는 늘려봐야 소용이 없다.
    static let fullPixels = 2400

    /// 한 장을 끌어오는 일. **주입 가능한 이음매다** — 프리뷰가 합성 이미지를 여기로 먹인다.
    /// 개인 스크린샷을 저장소에 넣지 않으므로(`CLAUDE.md` 경계 규칙) 이 자리가 없으면
    /// 프리뷰에서 볼 수 있는 것이 회색 칸뿐이 된다.
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

    /// 없으면 읽어 온다. 같은 (자산, 크기)를 동시에 여러 번 물어도 요청은 하나다.
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
