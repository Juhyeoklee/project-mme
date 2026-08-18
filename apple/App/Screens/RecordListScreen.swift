// `07` 기록 목록. 남긴 기록을 훑어 그 날을 찾는다. 골격은 `04`와 같다.
//
// ⚠️ **만드는 입구가 없다** (원칙 `P3`). 최상위 탭이면서 `+` 버튼을 갖지 않는 것이 그 원칙의
// 강제 조건이고, 우측 슬롯도 비어 있다.

import SwiftUI

struct RecordListScreen: View {
    let records: RecordLibrary
    /// iPad 2단에서 우측 pane이 보고 있는 기록. iPhone에서는 `nil`을 넘긴다.
    var selection: Binding<Record?>?
    /// 확인 시트를 최상위가 대신 띄운다. **iPhone은 `nil`** — 지면이 창 전체라 자기가 띄운다.
    var onRequestDelete: ((Record) -> Void)?

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// 카드가 놓일 실제 폭. **대표 이미지 높이를 이 값이 정한다.**
    @State private var contentWidth: CGFloat = 320
    /// 머리가 얼마나 줄었나. 0이면 펼침, 1이면 접힘.
    @State private var collapse: Double = 0
    /// 지금 네비가 말하는 달. 스티키를 걷어낸 자리를 접힌 타이틀이 대신한다.
    @State private var topMonthIndex = 0
    @State private var deleting: Record?

    var body: some View {
        // ⚠️ **머리를 겹쳐 띄운다** — 나란히 쌓으면 콘텐츠가 머리 아래로 지나가지 못해
        // 유리가 비출 것이 없다. 첫 화면에서 가려지지 않는 것은 목록의 상단 여백이 맡는다.
        list
            .overlay(alignment: .top) { header }
            .paneBackground()
            .threadBinding(.list)
            .toolbar(.hidden, for: .navigationBar)
            .task { records.reload() }
            .confirmationDialog(Wording.deleteRecordTitle, isPresented: isConfirmingDelete,
                                titleVisibility: .visible) {
                Button(Wording.delete, role: .destructive) {
                    if let deleting { records.delete(id: deleting.id) }
                }
            }
    }

    // MARK: - `07-N` 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ⚠️ **접힌 타이틀이 우측 슬롯 자리와 같은 줄에 선다** — `04`와 골격을 맞춘다.
            // 여기 슬롯이 비어 있어도 줄 높이는 같아야 탭을 오갈 때 머리가 안 튄다.
            ZStack {
                collapsedTitle.glassCapsule().collapsingInlineTitle(collapse)
                HStack(spacing: 0) {
                    expandedTitle
                        .lineLimit(1)
                        .opacity(1 - min(collapse * 2, 1))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: Layout.hitTarget)
            Text(Wording.recordSummary(records.records.count))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
                .collapsingSummary(collapse)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .headerScrim()
    }

    private var expandedTitle: Text {
        Text(Wording.recordsTitle)
            .font(Typography.accentTitle(Typography.headerLarge))
            .foregroundStyle(Palette.label)
    }

    /// 접히면 **지금 보고 있는 달**이 된다.
    /// ⚠️ **액센트 서체를 쓰지 않는다** — 숫자 폭 편차가 17.8%라 년·월이 쌓이면 자릿수가 흔들린다.
    private var collapsedTitle: Text {
        Text(topMonth.map { Wording.monthHeader(year: $0.year, month: $0.month) }
            ?? Wording.recordsTitle)
            .font(Typography.time)
            .foregroundStyle(Palette.label)
    }

    private var topMonth: RecordLibrary.RecordMonth? {
        let months = records.months
        return months.indices.contains(topMonthIndex) ? months[topMonthIndex] : nil
    }

    /// 헤더가 네비 아래로 지나가면 그 달이 「지금 보고 있는 달」이 된다.
    private func trackTopMonth(index: Int, headerMinY: CGFloat) {
        if headerMinY < 0 {
            topMonthIndex = max(topMonthIndex, index)
        } else {
            topMonthIndex = min(topMonthIndex, max(index - 1, 0))
        }
    }

    // MARK: - 목록

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(records.months.enumerated()), id: \.element.id) { index, month in
                    monthHeader(month)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .scrollView).minY
                        } action: { minY in
                            trackTopMonth(index: index, headerMinY: minY)
                        }
                    ForEach(month.records) { record in
                        row(record)
                    }
                }
                if records.records.isEmpty { emptyOrFailure }
            }
            .padding(.leading, leadingMargin)
            .padding(.trailing, Spacing.screenMargin)
            .readableWidth()
        }
        .contentMargins(.top, Layout.listHeaderHeight, for: .scrollContent)
        .tracksHeaderCollapse($collapse)
        .measuresContentWidth($contentWidth)
    }

    /// 달 경계를 표시하는 일만 하고 목록과 함께 흘러간다.
    private func monthHeader(_ month: RecordLibrary.RecordMonth) -> some View {
        Text(Wording.monthHeader(year: month.year, month: month.month))
            .font(Typography.date)
            .foregroundStyle(Palette.label)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ record: Record) -> some View {
        let card = RecordCard(record: record,
                              imageURL: records.store.imageURL(recordID:image:),
                              width: contentWidth,
                              isSelected: selection?.wrappedValue == record)
            .padding(.bottom, Spacing.recordGap)

        return Group {
            if let selection {
                Button { selection.wrappedValue = record } label: { card }
                    .buttonStyle(.plain)
            } else {
                NavigationLink(value: record) { card }
                    .buttonStyle(.plain)
            }
        }
        // ⚠️ **`07`에서만 길게 누르기가 생긴다** — `M1` 세 화면이 그것을 안 둔 근거는 `P1`
        // (순간은 읽기 전용)인데, 기록은 사용자가 만든 것이라 그 원칙이 안 걸린다.
        .contextMenu {
            Button(Wording.delete, role: .destructive) { requestDelete(record) }
        }
    }

    // MARK: - 빈 상태

    /// `07-E1`. 읽기 실패도 이 자리를 쓴다.
    @ViewBuilder
    private var emptyOrFailure: some View {
        Text(records.loadFailed ? Wording.recordsFailed : Wording.recordsEmpty)
            .font(records.loadFailed ? Typography.body : Typography.emptyState)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
    }

    // MARK: - 조각

    private var leadingMargin: CGFloat { Layout.leadingMargin(sizeClass) }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    /// 같은 결정이 부른 자리마다 다른 데 서지 않게 iPad는 최상위에 넘긴다.
    private func requestDelete(_ record: Record) {
        if let onRequestDelete { onRequestDelete(record) } else { deleting = record }
    }
}

/// `07-C` 기록 카드 — 항상 1열.
private struct RecordCard: View {
    let record: Record
    let imageURL: (UUID, RecordImage) -> URL
    /// 좌우 여백을 뺀 값.
    let width: CGFloat
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.momentGap) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.momentGap) {
                Text(Wording.dateHeader(record.occurredAt.calendarDay))
                    .font(Typography.time)
                    .foregroundStyle(Palette.label)
                    .highlighted(isSelected, seed: seed)
                if record.status == .draft { DraftBadge() }
                Spacer(minLength: 0)
                Text(Wording.images(record.images.count))
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            cover
            // ⚠️ **빠지면 초안 배지가 무슨 뜻인지 알 수 없다** — 초안은 설명이 없는 기록이다.
            if !record.caption.isEmpty {
                Text(record.caption)
                    .font(Typography.body)
                    .foregroundStyle(Palette.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.cardInset)
        .contentShape(.rect)
    }

    /// `07-C4` — **대표 1장을 4:3으로 자른다.** 캔버스 기록은 이미 4:3이라 자를 것이 없다.
    @ViewBuilder
    private var cover: some View {
        let imageWidth = max(1, width - Spacing.cardInset * 2)
        if let first = record.images.first {
            RecordImageView(url: imageURL(record.id, first),
                            pixels: Layout.recordCoverPixels,
                            fit: .cropped(width: imageWidth, aspect: Layout.recordCoverAspect),
                            cornerRadius: Radius.thumbnail)
        }
    }

    /// 획의 신원. 기록의 `id`를 쓰므로 목록을 다시 읽어도 같은 기록이면 같은 획이다.
    private var seed: UInt64 {
        UInt64(truncatingIfNeeded: record.id.hashValue)
    }
}
