// 사진 한 칸. 세 화면이 전부 이걸 쓴다.
//
// **그리기와 끌어오기를 나눈 이유는 프리뷰다** — 개인 스크린샷을 저장소에 넣지 않으므로
// (`CLAUDE.md` 경계 규칙) 프리뷰는 합성 이미지를 `PhotoTile`에 직접 먹인다.

import CoreGraphics
import PhotoSource
import SwiftUI

/// 이미지 한 장을 칸에 그린다. 끌어오는 일은 안 한다 — 그건 `AssetImage`다.
struct PhotoTile: View {
    let image: CGImage?
    /// `true`면 칸을 채우고 넘치는 만큼 잘린다(정사각 중앙 크롭), `false`면 안 잘린다(fit).
    let fills: Bool
    var cornerRadius: CGFloat = 0
    /// 사진이 **아직 없을 때**의 바탕.
    var emptyColor: Color = Palette.placeholder
    /// 사진이 **있을 때** fit하고 남는 여백의 바탕. **두 색을 나눈 이유가 실물에서 나왔다**
    /// (2026-08-04) — 하나로 묶었더니 `06`의 여백이 라이트에서 흰색이 되어 흰 크롬이 사라졌다.
    var matteColor: Color = Palette.surface

    var body: some View {
        Rectangle()
            .fill(image == nil ? emptyColor : matteColor)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: fills ? .fill : .fit)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

/// 자산의 이미지를 캐시에서 끌어와 `PhotoTile`에 넘긴다.
///
/// `retryToken`이 바뀌면 다시 묻는다 — 실패를 캐시하지 않으므로, 아까 원본이 iCloud에만 있어
/// 회색이던 칸이 2패스가 받아온 뒤에는 그려진다.
struct AssetImage: View {
    let asset: SourceAsset?
    let pixels: Int
    let fills: Bool
    var cornerRadius: CGFloat = 0
    var emptyColor: Color = Palette.placeholder
    var matteColor: Color = Palette.surface
    var allowingNetwork = false
    var retryToken = 0

    @Environment(ImageStore.self) private var store
    @State private var image: CGImage?

    /// **캐시는 `body`에서 곧바로 읽는다.** `.task`는 첫 프레임 뒤에 도는데, 이미 갖고 있는
    /// 이미지를 그때까지 회색으로 두면 목록을 되짚어 올라갈 때마다 칸이 한 번씩 깜빡인다.
    private var displayed: CGImage? {
        if let image { return image }
        guard let asset else { return nil }
        return store.cached(asset, pixels: pixels)
    }

    var body: some View {
        PhotoTile(image: displayed, fills: fills, cornerRadius: cornerRadius,
                  emptyColor: emptyColor, matteColor: matteColor)
            .task(id: Token(assetID: asset?.id, retry: retryToken)) {
                guard let asset else { return }
                if let hit = store.cached(asset, pixels: pixels) {
                    image = hit
                    return
                }
                // 이미 그린 것이 있으면 지우지 않는다. 지우면 재시도마다 화면이 깜빡인다.
                image = await store.image(asset, pixels: pixels,
                                          allowingNetwork: allowingNetwork) ?? image
            }
    }

    private struct Token: Equatable {
        let assetID: String?
        let retry: Int
    }
}
