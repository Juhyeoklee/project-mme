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

    @Environment(\.recordStore) private var store
    /// 앨범 자산은 2패스가 원본을 받아오면 다시 물어야 한다.
    var retryToken: Int = 0

    var body: some View {
        if let asset = photo.asset {
            AssetImage(asset: asset, pixels: pixels, fills: fills, retryToken: retryToken)
        } else if let stored = photo.storedImage {
            RecordImageView(url: store.imageURL(recordID: draft.id, image: stored),
                            pixels: pixels, fit: .free(fills: fills))
        } else {
            ImportedImage(data: draft.importedData(of: photo.id), pixels: pixels)
        }
    }
}
