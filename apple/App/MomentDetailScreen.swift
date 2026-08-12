// `05` 순간 상세 — 한 순간의 사진 전체를 벽돌쌓기 격자로 본다.
//
// **탭 대상이 하나다** — 어느 셀을 눌러도 `06`으로 간다. 연사는 여기서 펴지지 않고,
// 그 셀을 누르면 `06`이 그 묶음만 넘긴다.
//
// ⚠️ **시스템 네비 바를 쓰지 않는다.** iOS 26의 유리 바는 배경색을 주면 large title을 통째로
// 안 그린다 — 색의 종류와 무관하다(2026-08-11 탐침으로 확정). 머리는 직접 그린다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentDetailScreen: View {
    let library: MomentLibrary
    let moment: Moment
    /// 편집기가 뜰 자리는 `RootView`가 정한다 — 화면은 초안을 넣기만 한다.
    var editing: Binding<RecordDraft?>

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    /// 격자가 놓일 실제 폭. **열 폭을 이 값이 정한다.**
    @State private var contentWidth: CGFloat = 320
    /// 머리가 얼마나 줄었나. 0이면 펼침, 1이면 접힘.
    @State private var collapse: Double = 0
    @State private var viewing: PhotoRun?

    var body: some View {
        // ⚠️ **머리를 겹쳐 띄운다** — 나란히 쌓으면 콘텐츠가 머리 아래로 지나가지 못해
        // 유리가 비출 것이 없다. 첫 화면에서 가려지지 않는 것은 격자의 상단 여백이 맡는다.
        ZStack(alignment: .top) {
            ScrollView {
                grid(width: contentWidth)
                    .padding(.leading, leadingMargin)
                    .padding(.trailing, Spacing.screenMargin)
                    .padding(.top, 10)
                    // 우하단 액션이 마지막 행을 가리지 않을 만큼.
                    .padding(.bottom, Layout.floatingActionDiameter + 24)
                    .readableWidth()
            }
            .contentMargins(.top, Layout.largeTitleHeaderHeight, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                collapse = min(max(offset / Layout.hitTarget, 0), 1)
            }
            // ⚠️ **격자가 이 값을 되먹인다** — 격자가 받은 폭보다 넓어지면 값이 상한까지
            // 기어오른다 (2026-08-12 실측: 간격 하나가 더 껴서 패스마다 6씩 늘었다).
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: {
                contentWidth = max(1, min($0, Layout.readableWidth)
                    - leadingMargin - Spacing.screenMargin)
            }
            header
        }
        .background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { binding }
        .safeAreaInset(edge: .bottom) { createRecordButton }
        .fullScreenCover(item: $viewing) { run in
            PhotoViewerScreen(library: library, moment: moment,
                              photos: run.photos, start: run.start)
        }
    }

    // MARK: - `05-N` 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ⚠️ **접힌 타이틀이 뒤로 버튼과 같은 줄에 선다** — 아래 줄에 두면 스크롤한 뒤에도
            // 두 줄이 남아 네비 바로 안 읽힌다. 큰 타이틀은 그 아래 줄에 있다가 자리를 내준다.
            ZStack {
                collapsedTitle.glassCapsule().collapsingInlineTitle(collapse)
                HStack(spacing: 0) {
                    backButton
                    Spacer(minLength: 0)
                }
            }
            .frame(height: Layout.hitTarget)

            // `05-N2` — **숫자라 액센트 서체를 안 쓴다.** 자릿수가 흔들린다.
            Text(Wording.detailTitle(moment.start))
                .font(Typography.plexTitle(Typography.headerLarge))
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .collapsingLargeTitle(collapse)

            Text(Wording.counts(photos: moment.photoCount, scenes: moment.sceneCount))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
                .collapsingSummary(collapse)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .readableWidth()
        .headerScrim()
    }

    /// `05-N1` — **iPhone만.** iPad 2단은 지면을 갈아끼우므로 되돌아갈 자리가 없다.
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

    /// 접히면 같은 날짜·시각이 네비 관례대로 가운데에 선다.
    /// ⚠️ **활자 크기를 보간하지 않는다** — 자리가 옮겨가는 것이라 두 라벨을 교차시킨다.
    private var collapsedTitle: Text {
        Text(Wording.detailTitle(moment.start))
            .font(Typography.time)
            .foregroundStyle(Palette.label)
    }

    @ViewBuilder
    private var binding: some View {
        if sizeClass == .compact { ThreadBinding() }
    }

    // MARK: - `05-T` 기록 만들기

    /// 슬롯이 하나라 `FloatingBar`를 안 쓴다 — 떠 있음은 유리가 지고 카드는 묶음을 진다.
    private var createRecordButton: some View {
        Button { editing.wrappedValue = draft() } label: {
            // ⚠️ **글리프도 강조색이다** — 성립 조건은 `Chrome.accentTint`가 갖고 있다.
            GlyphIcon(Glyph.createRecord, size: 26)
                .foregroundStyle(Palette.accent)
                .frame(width: Layout.floatingActionDiameter,
                       height: Layout.floatingActionDiameter)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Chrome.accentTint).interactive(), in: .circle)
        .accessibilityLabel(Wording.createRecord)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, Spacing.screenMargin)
        .padding(.bottom, 24)
    }

    /// 이 순간이 속한 날짜는 커널이 안다 — 새벽 컷오프 때문에 시각에서 되짚으면 어긋난다.
    private func draft() -> RecordDraft? {
        guard let day = library.days.first(where: { $0.moments.contains(moment) }) else { return nil }
        return RecordDraft.from(moment: moment, day: day.date, library: library)
    }

    // MARK: - `05-G` 격자

    private func grid(width: CGFloat) -> some View {
        let cells = cells
        let plan = Self.plan(cells: cells, width: width)
        return HStack(alignment: .top, spacing: Spacing.cellGap) {
            ForEach(Array(plan.columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: Spacing.cellGap) {
                    ForEach(column, id: \.photoIndex) { cell in
                        cellView(cell, in: cells, width: plan.columnWidth)
                    }
                }
                .frame(width: plan.columnWidth)
            }
        }
        // ⚠️ 한 열짜리 순간에서 열이 가운데로 가지 않게 잡는다. **`Spacer`로 밀지 마라** —
        // 간격이 하나 더 생겨 격자가 잰 폭보다 넓어지고, 그 폭이 다시 측정된다.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// **열 폭을 꽉 채우고 높이는 사진 비율대로다** — 채워 그려도 잘릴 것이 없다.
    private func cellView(_ cell: Cell, in cells: [Cell], width: CGFloat) -> some View {
        AssetImage(asset: library.asset(at: cell.photoIndex),
                   pixels: ImageStore.gridPixels,
                   fills: true,
                   cornerRadius: Radius.thumbnail,
                   emptyColor: Palette.placeholder,
                   retryToken: library.generation)
            .frame(width: width, height: width / cell.aspect)
            .contentShape(.rect)
            .onTapGesture { viewing = Self.run(for: cell, in: cells) }
            .overlay(alignment: .topLeading) { badge(cell) }
    }

    /// `05-G2` — **어포던스가 아니라 정보다.** 탭 대상이 셀 전체라 배지를 누를 일이 없고,
    /// 히트 영역을 넓힐 일도 없다.
    @ViewBuilder
    private func badge(_ cell: Cell) -> some View {
        if cell.scene.count > 1 {
            BurstBadge(count: cell.scene.count).padding(8)
        }
    }

    /// **`06`이 넘기는 목록은 격자가 보여준 것 그대로다** — 안 그러면 격자에 없던 연사 컷이
    /// 뷰어에서 튀어나와 `06-N3`의 분모가 화면과 안 맞는다.
    static func run(for cell: Cell, in cells: [Cell]) -> PhotoRun {
        cell.scene.count > 1
            ? PhotoRun(photos: cell.scene, start: cell.photoIndex)
            : PhotoRun(photos: cells.map(\.photoIndex), start: cell.photoIndex)
    }

    // MARK: - 칸 배분

    /// 격자에 서는 칸 하나. **접힌 대표뿐이다** — 연사는 `06`에서만 펴진다.
    struct Cell: Hashable {
        let photoIndex: Int
        /// 이 셀이 대표하는 장면 전체. **연사 셀에서 `06`이 넘길 목록이다.** 1장이면 연사가 아니다.
        let scene: [Int]
        /// 가로 ÷ 세로. 셀 높이를 이 값이 정한다.
        let aspect: CGFloat
    }

    struct Plan: Equatable {
        let columns: [[Cell]]
        let columnWidth: CGFloat
    }

    /// **행을 맞추지 않는다** — 사진을 순서대로 그때 가장 짧은 열에 넣는다.
    /// 열마다 독립적으로 흐르므로 종횡비가 섞이면 시간순이 국소적으로 어긋난다.
    static func plan(cells: [Cell], width: CGFloat) -> Plan {
        let count = max(1, min(Layout.detailColumns, cells.count))
        let columnWidth = max(1, (width - Spacing.cellGap * CGFloat(count - 1)) / CGFloat(count))
        var columns = [[Cell]](repeating: [], count: count)
        var heights = [CGFloat](repeating: 0, count: count)
        for cell in cells {
            // 동률이면 왼쪽이다 — 첫 행이 시간순 그대로 놓인다.
            let target = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[target].append(cell)
            heights[target] += columnWidth / cell.aspect + Spacing.cellGap
        }
        return Plan(columns: columns, columnWidth: columnWidth)
    }

    private var cells: [Cell] {
        moment.scenes.map { scene in
            Cell(photoIndex: scene.representative,
                 scene: scene.photoIndices,
                 aspect: aspect(of: scene.representative))
        }
    }

    /// 셀 높이가 첫 프레임에 확정되고 그 뒤로 안 바뀐다 — 격자가 사진을 기다려 재배치되지 않는다.
    /// ⚠️ 크기를 모르는 자산은 가로로 둔다 — 이 앨범 대다수의 모양이다.
    private func aspect(of photoIndex: Int) -> CGFloat {
        guard let asset = library.asset(at: photoIndex),
              asset.pixelWidth > 0, asset.pixelHeight > 0
        else { return Layout.detailCellAspect }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    /// 좌우가 비대칭인 것은 제본이 왼쪽에만 있기 때문이다. 일기장에서도 안쪽 여백이 더 넓다.
    private var leadingMargin: CGFloat {
        sizeClass == .compact ? Spacing.bindingMargin : Spacing.screenMargin
    }
}

/// `05-G2` 연사 배지 — 겹친 스택 + 숫자.
///
/// ⚠️ **모드를 따르지 않는다** — 사진 위에 얹히므로 지면이 아니라 사진이 바탕이다.
private struct BurstBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            GlyphIcon(Glyph.burst, size: 12)
            Text("\(count)")
                .font(Typography.note)
        }
        .foregroundStyle(Paper.step1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Palette.photoBadge, in: .rect(cornerRadius: Radius.badge))
    }
}

/// `06`에 넘기는 한 벌. **목록과 시작점이 함께 간다** — 어느 격자에서 들어왔는지가
/// 그 둘을 정하므로 따로 넘기면 짝이 어긋난다.
struct PhotoRun: Identifiable, Hashable {
    let photos: [Int]
    let start: Int
    var id: Int { start }
}

#if DEBUG
#Preview("05 연사 있는 순간") {
    NavigationStack {
        MomentDetailScreen(library: Fixture.library, moment: Fixture.momentWithBurst, editing: .constant(nil))
    }
    .environment(Fixture.store)
}

#Preview("05 1장짜리 순간") {
    NavigationStack {
        MomentDetailScreen(library: Fixture.library, moment: Fixture.singlePhotoMoment, editing: .constant(nil))
    }
    .environment(Fixture.store)
}
#endif
