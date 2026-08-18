// 작성 중인 기록의 사진 한 장. `09` 격자와 `11` 캔버스가 같은 것을 쓴다.

import SwiftUI

/// 초안 사진 하나를 그린다. **출처 셋을 여기가 흡수한다** — 앨범 자산 · 저장된 파일 ·
/// 아직 저장 안 된 바이트.
///
/// ⚠️ **부르는 쪽이 갈래를 다시 세지 않는다.** `09`와 `11`이 따로 갈랐다가 한쪽만 고치면
/// 같은 사진이 두 화면에서 다르게 그려진다.
struct DraftPhotoImage: View {
    let photo: DraftPhoto
    let draft: RecordDraft
    /// 긴 변의 화소 상한.
    let pixels: Int
    /// `true`면 칸을 채우고 넘치는 만큼 잘린다.
    var fills = true
    /// 사진 자리에 바탕을 까는가. ⚠️ **캔버스는 안 깐다** — 투명한 이미지 뒤에서 회색 상자로
    /// 드러나고, 구운 쪽에는 없어 저장한 뒤에만 사라지는 것처럼 보인다(2026-08-18 실기기).
    var paintsBackdrop = true

    @Environment(\.recordStore) private var store
    /// 앨범 자산은 2패스가 원본을 받아오면 다시 물어야 한다.
    var retryToken: Int = 0

    var body: some View {
        if let asset = photo.asset {
            AssetImage(asset: asset, pixels: pixels, fills: fills,
                       emptyColor: emptyColor, matteColor: matteColor, retryToken: retryToken)
        } else if let stored = photo.storedImage {
            RecordImageView(url: store.imageURL(recordID: draft.id, image: stored),
                            pixels: pixels, fit: .free(fills: fills))
        } else {
            ImportedImage(data: draft.importedData(of: photo.id), pixels: pixels,
                          emptyColor: emptyColor, matteColor: matteColor)
        }
    }

    private var emptyColor: Color { paintsBackdrop ? Palette.placeholder : .clear }
    private var matteColor: Color { paintsBackdrop ? Palette.surface : .clear }
}
