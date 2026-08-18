// `11-O` 도구 옵션 팝오버 셋 — 색 · 종이 · 사진 서랍.
//
// ⚠️ **팔레트와 겹치지 않고 8pt 떨어져 나란히 선다.** 겹치면 팝오버의 주인 버튼이 가려져
// 어느 도구의 옵션인지가 안 보인다.

import SwiftUI

/// 지금 열려 있는 옵션 팝오버.
enum CanvasPopover: Hashable {
    case ink
    case paper
    case photos
}

/// 팝오버 껍데기 — 셋이 같은 재질과 반경을 쓴다.
struct CanvasPopoverCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
            .blocksNearbyTaps()
    }
}

/// `11-O1`의 색 줄. **글자색과 펜색이 같은 목록을 쓴다.**
struct InkRow: View {
    @Binding var ink: InkColor

    var body: some View {
        CanvasPopoverCard {
            HStack(spacing: 10) {
                ForEach(InkColor.allCases, id: \.self) { candidate in
                    Button { ink = candidate } label: {
                        Circle()
                            .fill(candidate.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle().strokeBorder(
                                    candidate == ink ? Palette.accent : Palette.placeholder,
                                    lineWidth: candidate == ink ? 2 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(candidate.name)
                    .accessibilityAddTraits(candidate == ink ? [.isSelected] : [])
                }
            }
        }
    }
}

/// `11-O2` 종이 고르기.
struct PaperPicker: View {
    let session: CanvasSession

    var body: some View {
        CanvasPopoverCard {
            HStack(spacing: 10) {
                ForEach(PaperKind.allCases, id: \.self) { candidate in
                    Button { choose(candidate) } label: {
                        CanvasPaperView(paper: candidate, patternScale: 0.5)
                            .frame(width: 66, height: 50)
                            .clipShape(.rect(cornerRadius: Radius.thumbnail))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.thumbnail)
                                    .strokeBorder(
                                        candidate == session.page.paper
                                            ? Palette.accent : Palette.placeholder,
                                        lineWidth: candidate == session.page.paper ? 2 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(candidate.name)
                    .accessibilityAddTraits(candidate == session.page.paper ? [.isSelected] : [])
                }
            }
        }
    }

    private func choose(_ paper: PaperKind) {
        let index = session.pageIndex
        session.change { $0[index].paper = paper }
    }
}

/// `11-O3` 사진 서랍 — 이 기록의 사진.
///
/// ⚠️ **이미 놓은 사진에 베일을 씌우지 않는다.** 이 앱에서 베일은 「이 기록에 **없다**」는
/// 뜻이고 서랍에서는 정확히 반대가 된다 — 같은 픽셀이 반대 뜻이면 배울 것이 둘이다.
/// 놓은 수는 **우하단 배지**가 말한다.
struct PhotoDrawer: View {
    let session: CanvasSession
    let retryToken: Int
    let onPlace: (UUID) -> Void

    var body: some View {
        CanvasPopoverCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(Wording.photoDrawer)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
                HStack(spacing: 8) {
                    ForEach(session.draft.included) { photo in
                        tile(photo)
                    }
                }
            }
        }
    }

    private func tile(_ photo: DraftPhoto) -> some View {
        Button { onPlace(photo.id) } label: {
            DraftPhotoImage(photo: photo, draft: session.draft,
                            pixels: Layout.thumbnailPixels, retryToken: retryToken)
                .frame(width: 70, height: 52)
                .clipShape(.rect(cornerRadius: Radius.thumbnail))
                .overlay(alignment: .bottomTrailing) { badge(photo) }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func badge(_ photo: DraftPhoto) -> some View {
        let count = session.placedCount(imageID: photo.id)
        if count > 0 {
            Text("\(count)")
                .font(Typography.note)
                .foregroundStyle(Palette.background)
                .frame(width: Layout.badgeDiameter, height: Layout.badgeDiameter)
                .background(Palette.badgeSurface, in: .circle)
                .padding(4)
        }
    }
}
