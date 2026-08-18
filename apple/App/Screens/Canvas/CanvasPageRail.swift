// `11-P` 페이지 레일 — 좌측 목록 ‖ 우측 지금 보는 것.

import SwiftUI

/// 페이지 썸네일과 `＋`. **현재 페이지는 테라코타 테두리 하나가 말한다.**
///
/// ⚠️ **`09`가 기각한 그 표현인데 여기서는 성립한다** — 그때 기각 근거가 *진입 직후 여섯 장이
/// 전부 둘러진다* 였고, 페이지는 언제나 정확히 하나다.
struct CanvasPageRail: View {
    let session: CanvasSession

    private var thumbnailHeight: CGFloat {
        Layout.canvasThumbnailWidth * Layout.canvasSize.height / Layout.canvasSize.width
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(session.document.pages.enumerated()), id: \.element.id) { index, page in
                thumbnail(page, index: index)
            }
            addPage
        }
        .padding(8)
        .frame(width: Layout.canvasRailWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        .blocksNearbyTaps()
    }

    private func thumbnail(_ page: CanvasPage, index: Int) -> some View {
        Button { session.pageIndex = index } label: {
            CanvasPageContent(session: session, page: page, pixels: Layout.thumbnailPixels)
                .scaleEffect(Layout.canvasThumbnailWidth / Layout.canvasSize.width)
                .frame(width: Layout.canvasThumbnailWidth, height: thumbnailHeight)
                .clipShape(.rect(cornerRadius: Radius.thumbnail))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.thumbnail)
                        .strokeBorder(index == session.pageIndex ? Palette.accent : Palette.placeholder,
                                      lineWidth: index == session.pageIndex ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Wording.canvasPage(index + 1))
        .accessibilityAddTraits(index == session.pageIndex ? [.isSelected] : [])
        .contextMenu {
            Button(Wording.delete, role: .destructive) { session.deletePage(page.id) }
                .disabled(!session.canDeletePage)
        }
    }

    /// `11-P2` — 격자 마지막 칸의 `＋`와 같은 문법이다.
    private var addPage: some View {
        Button { session.addPage() } label: {
            GlyphIcon(Glyph.add)
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: Layout.canvasThumbnailWidth, height: thumbnailHeight)
                .background(Palette.surface, in: .rect(cornerRadius: Radius.thumbnail))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Wording.addPage)
    }
}
