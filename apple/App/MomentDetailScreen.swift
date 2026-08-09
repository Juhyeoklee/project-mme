// `05` 순간 상세 — 한 순간의 사진 전체를 격자로 본다.
//
// **탭 대상이 둘이다** — 셀 탭은 어느 셀에서나 `06`으로 가고, 펼침은 배지가 맡는다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentDetailScreen: View {
    let library: MomentLibrary
    let moment: Moment

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// 펼쳐진 장면의 첨자. **접힌 상태의 장면 수로 열 수를 정하므로** 이 값은 열 수에 영향이 없다.
    @State private var expanded: Set<Int> = []
    @State private var viewing: PhotoPosition?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                grid(width: geometry.size.width)
            }
            .background(Palette.background)
        }
        .navigationTitle(Wording.detailTitle(moment.start))
        .navigationSubtitle(Wording.counts(photos: moment.photoCount, scenes: moment.sceneCount))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewing) { position in
            PhotoViewerScreen(library: library, moment: moment, start: position.index)
        }
        // 선택이 바뀌면(iPad) 펼침을 접는다 — 앞 순간의 첨자가 남으면 엉뚱한 셀이 펼쳐진다.
        .onChange(of: moment) { expanded = [] }
    }

    // MARK: - `05-G` 그리드

    private func grid(width: CGFloat) -> some View {
        let columns = columnCount
        let cellWidth = (width - Spacing.cellGap * CGFloat(columns + 1)) / CGFloat(columns)
        let cellHeight = cellWidth / Layout.detailCellAspect

        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: Spacing.cellGap),
                           count: columns),
            spacing: Spacing.cellGap
        ) {
            ForEach(cells, id: \.photoIndex) { cell in
                cellView(cell)
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
        .padding(Spacing.cellGap)
    }

    private func cellView(_ cell: Cell) -> some View {
        ZStack {
            Rectangle().fill(cell.isExpanded ? Palette.active : Palette.surface)
            AssetImage(asset: library.asset(at: cell.photoIndex),
                       pixels: ImageStore.gridPixels,
                       fills: false,
                       emptyColor: Palette.placeholder,
                       retryToken: library.generation)
                .padding(cell.isExpanded ? Spacing.expandedInset : 0)
        }
        .contentShape(.rect)
        .onTapGesture { viewing = PhotoPosition(index: cell.photoIndex) }
        .overlay(alignment: .topLeading) { badge(cell) }
    }

    /// 장면이 2장 이상일 때 대표 셀에만 붙는다.
    /// ⚠️ 작게 보이지만 **히트 영역은 44×44** — 셀 탭 위에 얹힌 두 번째 탭 대상이라 작으면 오폭한다.
    @ViewBuilder
    private func badge(_ cell: Cell) -> some View {
        if cell.isRepresentative, cell.sceneSize > 1 {
            Button {
                if expanded.contains(cell.sceneIndex) {
                    expanded.remove(cell.sceneIndex)
                } else {
                    // 삽입이 대표 뒤에서 일어나 앞선 칸 수가 그대로다 — 스크롤이 안 튄다.
                    expanded.insert(cell.sceneIndex)
                }
            } label: {
                BurstBadge(count: cell.sceneSize, expanded: cell.isExpanded)
                    .frame(width: 44, height: 44, alignment: .topLeading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.leading, 5)
            .padding(.top, 5)
        }
    }

    // MARK: - 칸 계산

    /// **접힌 장면 수가 최대 열 수보다 적으면 장면 수에 맞춘다.**
    private var columnCount: Int {
        let maximum = sizeClass == .regular ? Layout.detailColumnsRegular : Layout.detailColumnsCompact
        return max(1, min(maximum, moment.sceneCount))
    }

    struct Cell {
        let photoIndex: Int
        let sceneIndex: Int
        let isRepresentative: Bool
        let isExpanded: Bool
        let sceneSize: Int
    }

    /// 접힌 장면은 대표 컷 한 칸, 펼친 장면은 그 장면의 사진 전부.
    private var cells: [Cell] {
        var result: [Cell] = []
        for (sceneIndex, scene) in moment.scenes.enumerated() {
            let isExpanded = expanded.contains(sceneIndex)
            let indices = isExpanded ? scene.photoIndices : [scene.representative]
            for (offset, photoIndex) in indices.enumerated() {
                result.append(Cell(photoIndex: photoIndex,
                                   sceneIndex: sceneIndex,
                                   isRepresentative: offset == 0,
                                   isExpanded: isExpanded,
                                   sceneSize: scene.photoIndices.count))
            }
        }
        return result
    }
}

/// `05-G2` 연사 배지 — 겹친 스택 + 숫자. 펼치면 `05-G4` 접기가 같은 자리를 쓴다.
struct BurstBadge: View {
    let count: Int
    let expanded: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !expanded {
                RoundedRectangle(cornerRadius: Radius.badge)
                    .fill(Palette.surface)
                    .frame(width: 20, height: 16)
                    .offset(x: 3, y: 3)
                    .opacity(0.55)
            }
            RoundedRectangle(cornerRadius: Radius.badge)
                .fill(Palette.surface)
                .frame(width: expanded ? 34 : 20, height: 16)
                .overlay {
                    Text(expanded ? Wording.collapse : "\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                }
        }
    }
}

/// `06`으로 넘기는 자리. 사진 인덱스만으로 `Identifiable`을 만들기 위한 껍데기다.
struct PhotoPosition: Identifiable, Hashable {
    let index: Int
    var id: Int { index }
}

#if DEBUG
#Preview("05 연사 있는 순간") {
    NavigationStack {
        MomentDetailScreen(library: Fixture.library, moment: Fixture.momentWithBurst)
    }
    .environment(Fixture.store)
}

#Preview("05 1장짜리 순간") {
    NavigationStack {
        MomentDetailScreen(library: Fixture.library, moment: Fixture.singlePhotoMoment)
    }
    .environment(Fixture.store)
}
#endif
