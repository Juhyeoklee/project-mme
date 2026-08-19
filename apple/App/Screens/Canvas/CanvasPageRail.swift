// `11-P` 페이지 레일 — 좌측 목록 ‖ 우측 지금 보는 것.

import SwiftUI

/// 페이지 썸네일과 `＋`. **현재 페이지는 테라코타 테두리 하나가 말한다.**
///
/// ⚠️ **`09`가 기각한 그 표현인데 여기서는 성립한다** — 그때 기각 근거가 *진입 직후 여섯 장이
/// 전부 둘러진다* 였고, 페이지는 언제나 정확히 하나다.
struct CanvasPageRail: View {
    let session: CanvasSession
    /// 무대가 내어 주는 높이. 레일은 내용만큼만 서고 여기서 멈춘다.
    let maxHeight: CGFloat

    /// 획을 뜨는 배율. 썸네일이 줄어드는 만큼만 뜬다 — 전체 배율로 뜨면 90배 넓은 비트맵이 된다.
    private static let strokeScale =
        3 * Layout.canvasThumbnailWidth / Layout.canvasSize.width

    private var thumbnailHeight: CGFloat {
        Layout.canvasThumbnailWidth * Layout.canvasSize.height / Layout.canvasSize.width
    }

    /// 칸 수로 계산한 자연 높이 — `＋`까지 세고 사이 간격과 안쪽 여백, 머리, 구분선 1을 더한다.
    private var naturalHeight: CGFloat {
        let cells = CGFloat(session.document.pages.count + 1)
        return cells * thumbnailHeight + (cells - 1) * 8 + 16 + Self.headerHeight + 1
    }

    private static let headerHeight: CGFloat = 29

    var body: some View {
        VStack(spacing: 0) {
            position
            Divider().overlay(Palette.placeholder)
            pages
        }
        .frame(width: Layout.canvasRailWidth, height: min(naturalHeight, maxHeight))
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        .blocksNearbyTaps()
    }

    /// 지금 몇 번째인가. **스크롤과 함께 안 움직인다.**
    private var position: some View {
        Text(Wording.position(session.pageIndex, of: session.document.pages.count))
            .font(Typography.sectionLabel)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(height: Self.headerHeight)
            .accessibilityLabel(Wording.canvasPage(session.pageIndex + 1))
    }

    private var pages: some View {
        ScrollViewReader { rail in
            ScrollView {
                // ⚠️ **`Lazy`여야 한다** — 획을 그을 때마다 레일이 통째로 다시 그려지는데,
                // 안 보이는 페이지까지 획을 래스터화하면 페이지 수만큼 값이 는다.
                LazyVStack(spacing: 8) {
                    ForEach(Array(session.document.pages.enumerated()), id: \.element.id) { index, page in
                        thumbnail(page, index: index).id(page.id)
                    }
                    addPage
                }
                .padding(8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: session.pageIndex) { _, index in
                guard session.document.pages.indices.contains(index) else { return }
                withAnimation { rail.scrollTo(session.document.pages[index].id, anchor: .center) }
            }
        }
    }

    private func thumbnail(_ page: CanvasPage, index: Int) -> some View {
        Button { session.pageIndex = index } label: {
            DraftPageContent(session: session, page: page,
                             pixels: Layout.thumbnailPixels) {
                if let strokes = session.document.strokes[page.id] {
                    StrokeImage(strokes: strokes, scale: Self.strokeScale)
                }
            }
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
