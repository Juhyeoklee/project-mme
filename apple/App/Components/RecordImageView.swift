// 기록에 든 이미지 한 장을 디스크에서 읽어 그린다. `07` `08` `09`와 넘겨보기가 나눠 쓴다.

import CoreGraphics
import ImageIO
import SwiftUI

/// 저장된 바이트를 읽어 칸에 그린다.
///
/// **캐시를 두지 않는다** — `ImageStore`가 캐시를 지는 이유는 PhotoKit이 느리고 원본이 기기에
/// 없을 수 있어서인데(`R8`), 여기 파일은 앱 컨테이너 안이라 그 이유가 하나도 안 걸린다.
///
/// ⚠️ **원본을 통째로 디코딩하지 않는다** — 기록에 든 것은 게임 스크린샷 원본이라 목록 칸에
/// 4천 화소가 들어온다. 축소는 디코딩과 **같이** 일어나야 값이 있다.
struct RecordImageView: View {
    let url: URL
    /// 긴 변의 화소 상한.
    let pixels: Int
    /// 칸을 어떻게 차지하는가.
    let fit: Fit
    var cornerRadius: CGFloat = 0

    @State private var image: CGImage?

    /// 같은 사진이 화면마다 다르게 놓인다 — 훑는 자리는 자르고, 보는 자리는 안 자른다.
    enum Fit: Equatable {
        /// 주어진 폭에 고정 종횡비로 **자른다** (`07-C4`).
        case cropped(width: CGFloat, aspect: CGFloat)
        /// 원본 비율대로 두되 높이가 상한에서 멈춘다. 남는 좌우는 `면`이다 (`08-G1`).
        case fitted(width: CGFloat, maxHeight: CGFloat)
        /// 받은 자리를 그대로 쓴다 — 격자 칸과 뷰어.
        case free(fills: Bool)
    }

    var body: some View {
        // ⚠️ **빈 바탕도 여백도 비워 둔다** — 색을 깔면 세로 사진 좌우와 로딩 칸에서
        // 지면보다 어두운 띠가 드러난다 (2026-08-13 실기기).
        PhotoTile(image: image, fills: fills, cornerRadius: cornerRadius,
                  emptyColor: .clear, matteColor: .clear)
            .frame(width: size?.width, height: size?.height)
            .task(id: url) {
                let url = url, pixels = pixels
                image = await Task.detached { Self.decode(url, pixels: pixels) }.value
            }
    }

    private var fills: Bool {
        switch fit {
        case .cropped: true
        case .fitted: false
        case .free(let fills): fills
        }
    }

    /// ⚠️ **`.fitted`는 사진이 도착해야 높이가 정해진다** — 그 전에는 이 앨범 대다수의 모양인
    /// 가로로 둔다. 자리를 안 잡아 두면 도착할 때마다 아래 사진들이 통째로 밀린다.
    private var size: CGSize? {
        switch fit {
        case .cropped(let width, let aspect):
            CGSize(width: width, height: width / aspect)
        case .fitted(let width, let maxHeight):
            CGSize(width: width, height: min(width / naturalAspect, maxHeight))
        case .free:
            nil
        }
    }

    private var naturalAspect: CGFloat {
        guard let image, image.width > 0, image.height > 0 else { return Layout.detailCellAspect }
        return CGFloat(image.width) / CGFloat(image.height)
    }

    /// ⚠️ **본체에서 떨어져 돈다** — 화면 폭에 맞춰 줄이는 것도 원본을 읽어야 하는 일이라,
    /// 주 액터에서 하면 큰 사진이 도착할 때마다 스크롤이 걸린다.
    private nonisolated static func decode(_ url: URL, pixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ] as CFDictionary)
    }
}
