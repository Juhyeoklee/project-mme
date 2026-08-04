// `05` 순간 상세 — 한 순간의 사진 전체를 본다.
//
// **자르지 않는다.** `04`는 훑기라 정사각 크롭으로 충분하지만 여기는 `BRW-05`의 *"그 순간의
// 사진 전체를 본다"* 를 맡는다. 여기서도 자르면 `05`가 `04`보다 더 보여주는 것이 개수뿐이 되어
// 층위가 사라진다 (설계서 §3.2).
//
// **탭 대상이 둘인 것이 이 화면의 유일한 복잡함이다.** 셀 탭은 어느 셀에서나 `06`으로 가고
// (*"누르면 커진다"* 가 모든 셀에서 같아야 한다), 펼침은 배지라는 명시적 어포던스가 맡는다.
// 셀 탭을 펼침으로 하면 연사 셀만 동작이 달라져 그리드가 예측 불가능해진다.

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
        // `05`에는 아래로 당기기가 없다 — 새로고침은 `04`에만.
        .fullScreenCover(item: $viewing) { position in
            PhotoViewerScreen(library: library, moment: moment, start: position.index)
        }
        // 선택이 바뀌면(iPad) 펼침을 접고 처음으로 돌아간다. 앞 순간의 상태가 따라오면
        // "무엇이 펼쳐져 있는지"가 설명되지 않는다.
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
        // `05-G3` — 펼쳐진 셀만 사진에 3pt 인셋. 셀 배경이 사진 둘레에 띠로 보인다.
        // 사진이 3pt 작아지는 것은 크기 축소가 아니라 **상태 표시**다 — 접으면 돌아온다.
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

    /// `05-G2` 연사 배지 / `05-G4` 접기. **장면이 2장 이상일 때만**, 그리고 대표 셀에만 붙는다.
    ///
    /// 시각적으로 작게 두되 **히트 영역을 44×44로 넓힌다** — 배지는 셀 탭 위에 얹힌 두 번째
    /// 탭 대상이라, 작으면 셀 탭을 누르려다 배지가 눌린다.
    @ViewBuilder
    private func badge(_ cell: Cell) -> some View {
        if cell.isRepresentative, cell.sceneSize > 1 {
            Button {
                if expanded.contains(cell.sceneIndex) {
                    expanded.remove(cell.sceneIndex)
                } else {
                    // 펼쳐도 대표 셀의 화면상 위치는 바뀌지 않는다 — 삽입이 **대표 뒤에서**
                    // 일어나므로 앞선 칸 수가 그대로다. 그래서 스크롤이 튀지 않는다.
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

    /// 열 수 규칙 — 최대 iPhone 3 / iPad 4. **접힌 장면 수가 그보다 적으면 장면 수에 맞춘다.**
    /// `04`에서 1장짜리 순간을 압축하지 않기로 해놓고 여기서 작은 칸 하나로 되돌릴 수는 없다.
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

/// `05-G2` — 겹친 스택 + 숫자. **형태가 "여러 장"을 말하고 숫자는 개수만 말한다** —
/// `05-N3`이 이미 장수 어휘를 쓰고 있어 여기서 `3장`이라고 또 쓰지 않는다 (설계서 §3.2).
struct BurstBadge: View {
    let count: Int
    let expanded: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !expanded {
                // 뒤에 겹친 한 장.
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
                    // `05-G4` 접기는 `05-G2` **자리를 대체한다**.
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
