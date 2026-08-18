// `06` 사진 전체화면. 넘겨받은 목록을 좌우로 넘긴다 — **순환하지 않고, 다음 순간으로도
// 안 넘어간다.**
//
// ⚠️ **넘길 목록을 스스로 정하지 않는다** — 부르는 격자가 보여준 것이 그대로 와야 한다.
// 순간 전량을 여기서 펴면 격자에 없던 연사 컷이 튀어나와 `06-N3`의 분모가 안 맞는다.

import MomentKernel
import PhotoSource
import SwiftUI

struct PhotoViewerScreen: View {
    let library: MomentLibrary
    /// 시각을 못 읽은 사진이 나왔을 때 크롬이 기댈 자리. 넘길 목록은 `photos`가 정한다.
    let moment: Moment
    let photos: [Int]
    let start: Int

    var body: some View {
        ImageViewer(count: photos.count,
                    start: photos.firstIndex(of: start) ?? 0,
                    topLine: { Wording.time(timeOfPhoto(at: $0)) },
                    bottomLine: { Wording.position($0, of: photos.count) }) { position in
            AssetImage(asset: library.asset(at: photos[position]),
                       pixels: Layout.fullPixels,
                       fills: false,
                       emptyColor: Palette.viewerBackground,
                       // ⚠️ 여백도 검정이어야 한다 — 라이트에서 흰 여백이 깔리면
                       // 그 위의 흰 크롬이 사라진다 (2026-08-04 실기기).
                       matteColor: Palette.viewerBackground,
                       // 여기서만 네트워크를 연다 — 사용자가 이 한 장을 지목했다.
                       allowingNetwork: true,
                       retryToken: library.generation)
        }
    }

    /// **지금 보고 있는 그 사진의 시각이다** — 옆의 `06-N3`이 사진 단위라 짝이 맞는다.
    private func timeOfPhoto(at position: Int) -> WallClock {
        guard photos.indices.contains(position),
              let at = library.capturedAt(at: photos[position]) else { return moment.start }
        return at
    }
}

#if DEBUG
#Preview("06 전체화면") {
    PhotoViewerScreen(library: Fixture.library,
                      moment: Fixture.momentWithBurst,
                      photos: Fixture.momentWithBurst.photoIndices,
                      start: Fixture.momentWithBurst.photoIndices[0])
        .environment(Fixture.store)
}
#endif
