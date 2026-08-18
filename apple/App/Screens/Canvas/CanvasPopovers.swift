// `11-O` 도구 옵션 팝오버 셋 — 색 · 종이 · 사진 서랍.
//
// ⚠️ **팔레트와 겹치지 않고 8pt 떨어져 나란히 선다.** 겹치면 팝오버의 주인 버튼이 가려져
// 어느 도구의 옵션인지가 안 보인다.

import SwiftUI

/// 지금 열려 있는 옵션 팝오버.
///
/// ⚠️ **색만 여는 자리와 굵기까지 여는 자리가 다르다** — `11-T8` 색 칩은 색 줄만 띄우고,
/// 그리는 도구를 다시 누르면 그 도구의 굵기가 함께 온다.
enum CanvasPopover: Hashable {
    case ink
    case stroke
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

/// `11-O1` 굵기와 색. **글자색과 펜색이 같은 목록을 쓴다.**
struct InkOptions: View {
    /// 굵기를 함께 보이는 도구. **`nil`이면 색 줄만 뜬다** — 색 칩에서 연 자리다.
    let stroke: CanvasTool?
    let width: CGFloat
    /// 마커 진하기(백분율). **마커에서만 줄이 하나 더 선다.**
    let opacity: CGFloat
    @Binding var ink: InkColor
    let onWidth: (CGFloat) -> Void
    let onOpacity: (CGFloat) -> Void

    var body: some View {
        CanvasPopoverCard {
            VStack(alignment: .leading, spacing: 14) {
                if let stroke {
                    // ⚠️ **미리보기 하나가 줄 전부를 진다** — 줄마다 두면 왼쪽이 그만큼
                    // 어긋나거나 빈 칸이 생긴다(pen 실치수 비교 2026-08-18).
                    HStack(spacing: 10) {
                        preview(rows: stroke == .marker ? 2 : 1)
                        VStack(spacing: 10) {
                            CanvasValueSlider(value: width, range: stroke.widthRange,
                                              name: Wording.strokeWidth, showsLabel: true,
                                              onChange: onWidth)
                            if stroke == .marker {
                                CanvasValueSlider(value: opacity,
                                                  range: InkColor.markerOpacityRange,
                                                  name: Wording.inkOpacity, showsLabel: true,
                                                  onChange: onOpacity)
                            }
                        }
                    }
                    if stroke.usesInk { label(Wording.inkColor) }
                }
                if stroke?.usesInk ?? true { colors }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Typography.note)
            .foregroundStyle(Palette.secondaryLabel)
    }

    /// 실치수 미리보기 — 굵기와 진하기가 함께 만드는 점이라 줄 전부의 왼쪽에 하나만 선다.
    /// ⚠️ **바탕을 안 깐다** — 점이 곧 결과라 상자가 뒤에 있으면 그 색까지 섞여 보인다.
    @ViewBuilder
    private func preview(rows: Int) -> some View {
        let height = CanvasValueSlider.height * CGFloat(rows) + (rows > 1 ? 10 : 0)
        let dot = min(width, min(Layout.hitTarget, height) - 6)
        Group {
            // 지우개는 색이 없다 — 옅은 회색 원과 또렷한 테두리가 「지우는 자리」의 크기를
            // 말한다. ⚠️ 테두리만 남기면 유리 위에서 사실상 안 보인다(2026-08-18 실기기).
            if stroke?.usesInk == false {
                Circle()
                    .fill(Palette.placeholder)
                    .overlay(Circle().strokeBorder(Palette.secondaryLabel, lineWidth: 1.5))
            } else {
                Circle().fill(stroke == .marker ? ink.markerColor(opacity / 100) : ink.color)
            }
        }
        .frame(width: dot, height: dot)
        .frame(width: Layout.hitTarget, height: height)
    }

    private var colors: some View {
        HStack(spacing: 8) {
            ForEach(InkColor.allCases, id: \.self) { candidate in
                Button { ink = candidate } label: {
                    Circle()
                        .fill(candidate.color)
                        .frame(width: 28, height: 28)
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
