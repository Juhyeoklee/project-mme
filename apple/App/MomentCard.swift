// `04-C` 순간 카드.
//
// ⚠️ **스트립 규칙은 행이지 장수가 아니다** — 폭이 장수를 정한다. iPhone과 iPad 가로 pane이
// 둘 다 3장/행이라 6칸이 같아 보이지만, 그건 계산의 결과지 전제가 아니다. 6을 박지 마라.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentCard: View {
    let moment: Moment
    /// 커널 인덱스 → 자산. 프리뷰에서는 전부 `nil`을 돌려주는 클로저가 들어온다.
    let assetAt: (Int) -> SourceAsset?
    /// 좌우 여백을 뺀 값.
    let stripWidth: CGFloat
    var retryToken = 0
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.cellGap) {
            // ⚠️ **둘이 붙어 한 줄로 읽혀야 한다** — 양끝으로 벌리면 시각과 장수가 서로 다른
            // 것을 말하는 두 줄이 된다. 크기가 달라 baseline으로 맞춘다.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.momentGap) {
                Text(Wording.time(moment.start))
                    .font(Typography.time)
                    .foregroundStyle(Palette.label)
                Text(Wording.counts(photos: moment.photoCount, scenes: moment.sceneCount))
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            .fixedSize()
            .highlighted(isSelected, seed: seed)

            strip
        }
        // ⚠️ **가로 패딩을 두지 않는다** — `118×3 + 3×2 = 360`이 스트립의 천장이라, 카드가
        // 안쪽 여백을 먹으면 한 행이 3장에서 2장으로 깨진다.
        .contentShape(.rect)
    }

    /// 획의 신원. **순간의 첫 사진 첨자를 쓴다** — 목록이 다시 분류돼도 같은 순간이면 같은 획이다.
    private var seed: UInt64 { UInt64(truncatingIfNeeded: moment.photoIndices.first ?? 0) &+ 7 }

    // MARK: - `04-C3` 스트립

    private var strip: some View {
        let plan = Self.plan(sceneCount: moment.sceneCount, width: stripWidth)
        return VStack(alignment: .leading, spacing: Spacing.thumbnailGap) {
            ForEach(Array(plan.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Spacing.thumbnailGap) {
                    ForEach(row, id: \.self) { slot in
                        switch slot {
                        case .scene(let sceneIndex):
                            // ⚠️ 사진이 아니라 **장면 대표 컷**을 넣는다 —
                            // 사진을 앞에서부터 넣으면 스트립이 연사로만 채워질 수 있다.
                            AssetImage(asset: assetAt(moment.scenes[sceneIndex].representative),
                                       pixels: ImageStore.thumbnailPixels,
                                       fills: true,
                                       cornerRadius: Radius.thumbnail,
                                       retryToken: retryToken)
                                .frame(width: Layout.thumbnail, height: Layout.thumbnail)
                        case .more(let count):
                            // ⚠️ **배지가 아니라 칸이다** — 사진 위에 얹히지 않으므로 배지 문법을
                            // 쓰지 않는다. 스트립의 마지막 칸을 채우는 요소다.
                            Text(Wording.more(count))
                                .font(Typography.time)
                                .foregroundStyle(Palette.secondaryLabel)
                                .frame(width: Layout.thumbnail, height: Layout.thumbnail)
                                .background(Palette.surface)
                                .clipShape(.rect(cornerRadius: Radius.thumbnail))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 칸 배분

    enum Slot: Hashable {
        case scene(Int)
        case more(Int)
    }

    struct Plan {
        var rows: [[Slot]]
    }

    /// 장면을 칸에 앉힌다. 다 안 들어가면 **마지막 칸을 `+N`이 가져간다** — 폭을 뺏지 않고 칸을 쓴다.
    static func plan(sceneCount: Int, width: CGFloat) -> Plan {
        let perRow = Layout.thumbnailsPerRow(inWidth: width)
        let capacity = Layout.stripCapacity(inWidth: width)
        var slots: [Slot] = []
        if sceneCount <= capacity {
            slots = (0..<sceneCount).map { .scene($0) }
        } else {
            slots = (0..<(capacity - 1)).map { .scene($0) }
            slots.append(.more(sceneCount - (capacity - 1)))
        }
        var rows: [[Slot]] = []
        var index = 0
        while index < slots.count {
            let end = min(index + perRow, slots.count)
            rows.append(Array(slots[index..<end]))
            index = end
        }
        return Plan(rows: rows)
    }
}
