// `08` 기록 상세. 기록 하나를 보고, 남에게 직접 보여준다.
//
// ⚠️ **순간으로 가는 길이 없다** (원칙 `P2`). 기록은 자기가 어느 순간에서 왔는지 모르고,
// 이 화면도 묻지 않는다.

import SwiftUI

struct RecordDetailScreen: View {
    let library: MomentLibrary
    let records: RecordLibrary
    let record: Record
    /// 편집기가 뜰 자리는 최상위가 정한다 — 화면은 초안을 넣기만 한다.
    var editing: Binding<RecordDraft?>

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    /// 사진이 놓일 실제 폭. **높이 상한에 걸리는지를 이 값이 정한다.**
    @State private var contentWidth: CGFloat = 320
    /// 머리가 얼마나 줄었나. 0이면 펼침, 1이면 접힘.
    @State private var collapse: Double = 0
    @State private var flipping: FlipStart?
    @State private var isConfirmingDelete = false

    /// 지금 화면에 보이는 그 기록. 저장을 거쳐 오면 목록 쪽이 새 값을 갖는다.
    private var shown: Record {
        records.records.first { $0.id == record.id } ?? record
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                content(of: shown)
                    .padding(.leading, leadingMargin)
                    .padding(.trailing, Spacing.screenMargin)
                    .padding(.top, 10)
                    // 툴바가 마지막 사진을 가리지 않을 만큼.
                    .padding(.bottom, Layout.floatingBarHeight + 24)
                    .readableWidth()
            }
            .contentMargins(.top, Layout.largeTitleHeaderHeight, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                collapse = min(max(offset / Layout.hitTarget, 0), 1)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: {
                contentWidth = max(1, min($0, Layout.readableWidth)
                    - leadingMargin - Spacing.screenMargin)
            }
            header
        }
        .background(paneBackground)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { binding }
        .safeAreaInset(edge: .bottom) { toolbar }
        .fullScreenCover(item: $flipping) { start in
            FlipThrough(record: shown, store: records.store, start: start.value)
        }
        .confirmationDialog(Wording.deleteRecordTitle, isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button(Wording.delete, role: .destructive) { delete() }
        }
    }

    // MARK: - `08-N` 머리

    /// ⚠️ **iPad 2단에서는 지면이다** — `바탕`을 칠하면 다크에서 지면과 바깥이 같은 값이 된다.
    private var paneBackground: Color {
        sizeClass == .regular ? Palette.pane : Palette.background
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            ZStack {
                collapsedTitle.glassCapsule().collapsingInlineTitle(collapse)
                HStack(spacing: 0) {
                    backButton
                    Spacer(minLength: 0)
                    moreMenu
                }
            }
            .frame(height: Layout.hitTarget)

            // `08-N2` — **숫자라 액센트 서체를 안 쓴다.** 자릿수가 흔들린다.
            Text(Wording.dateHeader(shown.occurredAt.calendarDay))
                .font(Typography.plexTitle(Typography.headerLarge))
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .collapsingLargeTitle(collapse)

            HStack(spacing: Spacing.momentGap) {
                Text(Wording.images(shown.images.count))
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
                if shown.status == .draft { DraftBadge() }
            }
            .collapsingSummary(collapse)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .readableWidth()
        .headerScrim()
    }

    /// `08-N1` — **iPhone만.** iPad 2단은 지면을 갈아끼우므로 되돌아갈 자리가 없다.
    @ViewBuilder
    private var backButton: some View {
        if sizeClass == .compact {
            Button { dismiss() } label: {
                GlyphIcon(Glyph.back)
                    .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Wording.back)
            .glassEffect(.regular, in: .circle)
        }
    }

    /// `08-N4` — **삭제가 사는 유일한 자리다.** 인라인 파괴 버튼을 만들지 않는다는 규칙이
    /// 강조색 `공유`와 파괴색이 같은 시야에 서는 유일한 충돌을 여기서 없앤다.
    private var moreMenu: some View {
        Menu {
            if shown.status == .draft {
                Button(Wording.flipThrough) { flipping = FlipStart(value: 0) }
            }
            Button(Wording.delete, role: .destructive) { isConfirmingDelete = true }
        } label: {
            GlyphIcon(Glyph.more)
                .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                .foregroundStyle(Palette.accent)
        }
        .accessibilityLabel(Wording.moreActions)
        .glassEffect(.regular, in: .circle)
    }

    private var collapsedTitle: Text {
        Text(Wording.dateHeader(shown.occurredAt.calendarDay))
            .font(Typography.time)
            .foregroundStyle(Palette.label)
    }

    // MARK: - 본문

    /// ⚠️ **설명이 사진보다 위에 온다** — 뒤에 두면 첫 화면에 글이 한 글자도 없다. 기록에는
    /// 제목이 없어서 설명 첫 줄이 그 자리를 대신하고, 그러려면 위에 있어야 한다.
    private func content(of record: Record) -> some View {
        VStack(alignment: .leading, spacing: Spacing.momentGap) {
            if !record.caption.isEmpty {
                Text(record.caption)
                    .font(Typography.body)
                    .foregroundStyle(Palette.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.momentGap)
            }
            ForEach(Array(record.images.enumerated()), id: \.element.id) { position, image in
                photo(record: record, image: image)
                    .onTapGesture { flipping = FlipStart(value: position) }
            }
        }
    }

    /// `08-G1` — **자르지 않는다.** 대신 높이 상한에서 멈추고 좌우에 `면`이 남는다.
    private func photo(record: Record, image: RecordImage) -> some View {
        RecordImageView(url: records.store.imageURL(recordID: record.id, image: image),
                        pixels: RecordImageView.detailPixels,
                        fit: .fitted(width: contentWidth,
                                     maxHeight: Layout.recordPhotoMaxHeight),
                        cornerRadius: Radius.thumbnail)
    }

    // MARK: - `08-T` 툴바

    /// **슬롯이 셋이라 카드가 서고 유리는 카드가 진다.** 내용만 상태에 따라 바뀐다.
    private var toolbar: some View {
        FloatingBar {
            if shown.status == .draft {
                Button(Wording.edit) { editing.wrappedValue = draft() }
                    .buttonStyle(PlainActionStyle())
                Spacer(minLength: 0)
                // ⚠️ 동작은 캔버스 화면이 생길 때 붙는다.
                Button(Wording.makeCanvas) {}
                    .buttonStyle(PlainActionStyle())
                Spacer(minLength: 0)
                // **`게시`는 편집기를 열지 않는다** — 초안 여부는 저장된 상태지 설명의
                // 파생값이 아니라, 여기서 상태만 올려도 기록이 된다.
                Button(Wording.publish) { records.publish(shown) }
                    .buttonStyle(PrimaryActionStyle())
            } else {
                Button(Wording.flipThrough) { flipping = FlipStart(value: 0) }
                    .buttonStyle(PlainActionStyle())
                Spacer(minLength: 0)
                Button(Wording.edit) { editing.wrappedValue = draft() }
                    .buttonStyle(PlainActionStyle())
                Spacer(minLength: 0)
                // ⚠️ 동작은 공유 세션이 붙을 때 온다.
                Button(Wording.share) {}
                    .buttonStyle(PrimaryActionStyle())
            }
        }
        .frame(maxWidth: Layout.floatingBarMaxWidth)
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 조각

    /// `ARC-06` — **이 기록을 그대로 태운다.** 순간에서 다시 누르면 새 기록이 되는 것과
    /// 갈리는 자리가 여기다: 진입점이 무엇을 싣는지가 그 차이 전부다.
    private func draft() -> RecordDraft {
        RecordDraft.editing(shown)
    }

    private func delete() {
        records.delete(id: shown.id)
        if sizeClass == .compact { dismiss() }
    }

    @ViewBuilder
    private var binding: some View {
        if sizeClass == .compact { ThreadBinding() }
    }

    private var leadingMargin: CGFloat {
        sizeClass == .compact ? Spacing.bindingMargin : Spacing.screenMargin
    }
}

/// 넘겨보기를 어느 장에서 열었나. `Int`는 `Identifiable`이 아니라 감싼다.
private struct FlipStart: Identifiable, Hashable {
    let value: Int
    var id: Int { value }
}

/// `ARC-05` 넘겨보기 — **화면이 아니라 `08`의 상태다.** 크롬을 걷고 이미지만 채운다.
///
/// ⚠️ **넘기는 것은 그 기록의 이미지 전부다.** 캔버스 기록이면 페이지가 그대로 장이 된다.
private struct FlipThrough: View {
    let record: Record
    let store: RecordStore
    let start: Int

    var body: some View {
        ImageViewer(count: record.images.count,
                    start: start,
                    topLine: { Wording.position($0, of: record.images.count) },
                    bottomLine: { _ in Wording.dateHeader(record.occurredAt.calendarDay) }) { position in
            RecordImageView(url: store.imageURL(recordID: record.id,
                                                image: record.images[position]),
                            pixels: RecordImageView.detailPixels,
                            fit: .free(fills: false))
        }
    }
}
