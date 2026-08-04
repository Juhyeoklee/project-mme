// `04-C` 순간 카드. 항상 1열이고, 카드 전체가 하나의 탭 대상이다.
//
// 스트립 규칙은 **행으로** 쓰여 있다(설계서 §2.3) — "6장"은 3장/행일 때만 성립하는 값이고,
// 행으로 두면 폭이 장수를 정한다. iPhone 361과 iPad pane 374가 둘 다 3장/행이라
// 결과적으로 6칸이 같지만, 그 같음은 계산의 결과지 전제가 아니다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentCard: View {
    let moment: Moment
    /// 커널 인덱스 → 자산. 프리뷰에서는 전부 `nil`을 돌려주는 클로저가 들어온다.
    let assetAt: (Int) -> SourceAsset?
    /// 스트립이 쓸 수 있는 폭(좌우 여백을 뺀 값). **이 폭이 한 행의 장수를 정한다.**
    let stripWidth: CGFloat
    var retryToken = 0
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // `04-C1` 시각 · `04-C2` 장수·장면 수. baseline으로 맞춰야 두 크기가 한 줄로 읽힌다.
            HStack(alignment: .firstTextBaseline) {
                Text(Wording.time(moment.start))
                    .font(Typography.time)
                Spacer(minLength: Spacing.thumbnailGap)
                Text(Wording.counts(photos: moment.photoCount, scenes: moment.sceneCount))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            strip
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, isSelected ? 6 : 0)
        .background(isSelected ? Palette.active : .clear)
        .contentShape(.rect)
    }

    // MARK: - `04-C3` 스트립

    private var strip: some View {
        let plan = Self.plan(sceneCount: moment.sceneCount, width: stripWidth)
        return VStack(alignment: .leading, spacing: Spacing.thumbnailGap) {
            ForEach(Array(plan.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Spacing.thumbnailGap) {
                    ForEach(row, id: \.self) { slot in
                        switch slot {
                        case .scene(let sceneIndex):
                            // **장면 대표 컷**을 시간순으로. 원본 순서 그대로 앞에서부터 넣으면
                            // 12장 순간의 스트립 3칸이 2초 간격 연사로 채워질 수 있다 (설계서 §2.2).
                            AssetImage(asset: assetAt(moment.scenes[sceneIndex].representative),
                                       pixels: ImageStore.thumbnailPixels,
                                       fills: true,
                                       cornerRadius: Radius.thumbnail,
                                       retryToken: retryToken)
                                .frame(width: Layout.thumbnail, height: Layout.thumbnail)
                        case .more(let count):
                            // `04-C4` — 사진 위에 얹는 오버레이가 아니라 **빈 칸에 숫자만**.
                            // 오버레이는 스트립에서 유일한 "사진 위 UI"가 되어 예외를 만든다.
                            Text(Wording.more(count))
                                .font(Typography.time)
                                .foregroundStyle(.secondary)
                                .frame(width: Layout.thumbnail, height: Layout.thumbnail)
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
    ///
    /// 칸 수는 폭에서 나온다(§2.3). iPhone 361과 iPad 가로 pane 374가 둘 다 3장이라 결과적으로
    /// 6칸이 같지만, 그 같음은 **계산의 결과지 전제가 아니다** — iPad 세로에서는 2장/행이 된다.
    static func plan(sceneCount: Int, width: CGFloat) -> Plan {
        let perRow = Layout.thumbnailsPerRow(inWidth: width)
        let capacity = perRow * Layout.stripRows
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
