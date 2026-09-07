// `01` 권한 요청 — 사진 접근을 얻고, 그 **앞에** 왜 필요한지 말한다 (`SRC-07` `SYS-01`).
//
// ⚠️ **버튼이 하나다.** 거부하는 길은 시스템 대화상자가 이미 갖고 있다.

import MomentKernel
import SwiftUI

struct PermissionScreen: View {
    /// `01-B1`을 누른 것. **권한을 여기서 요청하지 않는다** — 어댑터를 아는 것은 뼈대다.
    let onRequest: () async -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// 화면이 떴는가. **덩어리마다 차례로 나타나는 방아쇠 하나다.**
    @State private var shown = false

    var body: some View {
        Group {
            if sizeClass == .regular { pad } else { phone }
        }
        .onAppear { shown = true }
    }

    // MARK: - 기기

    private var phone: some View {
        content(topInset: Layout.onboardingTopInset)
            .padding(.leading, Spacing.listLeading)
            .padding(.trailing, Spacing.screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paneBackground()
            .threadBinding(.list)
    }

    /// 지면을 창에 펴지 않고 **읽기 폭 한 장**으로 놓는다 — 온보딩에는 지면이 하나뿐이다.
    private var pad: some View {
        content(topInset: Layout.onboardingPadTopInset)
            .padding(.horizontal, Layout.onboardingPadMargin)
            .frame(maxWidth: Layout.readableWidth, maxHeight: .infinity, alignment: .topLeading)
            .pane()
            .threadBinding(.list)
            .padding(Spacing.paneGap)
            .frame(maxWidth: .infinity)
            .background(Palette.paneOutside)
    }

    // MARK: - 덩어리

    /// ⚠️ **가운데 남는 자리를 `Spacer` 둘이 나눠 먹는다** — pen 보드는 상태 표시줄을 안 그려
    /// 실기기보다 세로가 넉넉하다. 고정 간격으로 옮기면 버튼이 화면 밖으로 나간다.
    private func content(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                headline
                Text(Wording.permissionBody)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
                    .padding(.top, 24)
            }
            .fadesIn(shown, order: 0)
            Spacer(minLength: 24)
            SampleDayCard(shown: shown)
                .frame(maxWidth: Layout.sampleCardMaxWidth, alignment: .leading)
                .fadesIn(shown, order: 1)
            Spacer(minLength: 24)
            actionButton
                .fadesIn(shown, order: 3)
        }
        .padding(.top, topInset)
        .padding(.bottom, 12)
    }

    /// `01-N1` — 형광펜은 **첫 줄에만** 긋는다. 두 줄에 그으면 강조가 강조를 잃는다.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Wording.permissionHeadline.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(Typography.accentTitle(Typography.onboardingHeadline))
                    .foregroundStyle(Palette.label)
                    .frame(height: Layout.onboardingLineHeight, alignment: .leading)
                    .highlighterSweeps(index == 0, after: FadeIn.after(0),
                                       center: Self.headlineSweep)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// ⚠️ **눈으로 고른 값이다.** 손글씨 36의 글자 몸통이 줄 상자 어디에 앉는지를 따라간다.
    private static let headlineSweep: CGFloat = 0.6

    private var actionButton: some View {
        Button(Wording.chooseAlbum) { Task { await onRequest() } }
        .buttonStyle(PrimaryActionStyle(fillsWidth: true))
        .actionWidth()
    }
}

// MARK: - `01-S` 견본 카드

/// 데이터 없이 **형식만** 보인다 — 권한 전이라 보여줄 사진이 원리적으로 없다.
///
/// ⚠️ **새 어휘가 0이다** — 날짜 머리·요약 줄·스트립·`+N`이 전부 `04`의 것이고, 문구도
/// 같은 포맷터에서 나온다. 여기서 갈리면 `02`에서 진짜 사진이 채워질 때 딴 화면이 된다.
private struct SampleDayCard: View {
    let shown: Bool

    /// ⚠️ **폭을 재서 변을 정한다** — 칸을 비율로만 두면 높이가 남는 세로를 먹어 직사각이 된다.
    @State private var side: CGFloat = Layout.thumbnail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Wording.dateHeader(Self.day))
                .font(Typography.date)
                .foregroundStyle(Palette.label)
            Text(Wording.summary(moments: Self.moments, photos: Self.photos))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
                .padding(.bottom, 8)
            summaryLine
                .padding(.bottom, Spacing.cellGap)
            strip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding([.horizontal, .bottom], 18)
        .background(Palette.cardSurface)
        .clipShape(.rect(cornerRadius: Radius.card))
        .shadow(color: Chrome.cardShadowColor,
                radius: Chrome.cardShadowRadius, y: Chrome.cardShadowOffset)
        .accessibilityElement(children: .combine)
    }

    /// `04-C1` — 형광펜이 머리글 **다음에** 그어진다. 동시에 그으면 둘 다 놓친다.
    private var summaryLine: some View {
        HStack(spacing: Spacing.cellGap) {
            Text(Wording.time(hour: Self.hour, minute: Self.minute))
                .font(Typography.time)
                .foregroundStyle(Palette.label)
            Text(Wording.counts(photos: Self.cellPhotos, scenes: Self.scenes))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .highlighterSweeps(after: FadeIn.after(2))
    }

    /// ⚠️ **타일 크기를 안 박는다** — 칸이 행을 균등하게 나누고, 그래서 폭이 넓어지면
    /// 타일이 커진다(`04`는 반대로 칸 수가 는다). 견본은 한 행뿐이라 갈래가 안 생긴다.
    private var strip: some View {
        HStack(spacing: Spacing.cellGap) {
            ForEach(0..<Self.tiles, id: \.self) { _ in cell { Color.clear } }
            cell {
                Text(Wording.more(Self.hidden))
                    .font(Typography.time)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .fadesIn(shown, order: 2)
        .frame(height: side)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            let gaps = Spacing.cellGap * CGFloat(Self.tiles)
            side = max(1, (width - gaps) / CGFloat(Self.tiles + 1))
        }
    }

    private func cell(@ViewBuilder content: () -> some View) -> some View {
        Color.clear
            .overlay { content() }
            .background(Palette.innerSurface)
            .clipShape(.rect(cornerRadius: Radius.thumbnail))
    }

    private static let day = CalendarDay(year: 2026, month: 7, day: 26)
    private static let hour = 18
    private static let minute = 5
    private static let moments = 4
    private static let photos = 22
    private static let cellPhotos = 12
    private static let scenes = 8
    private static let tiles = 3
    private static let hidden = 9
}

// MARK: - 차례로 뜨는 것

/// 화면이 뜰 때 덩어리가 차례로 나타난다. **순서가 곧 읽는 순서다** — 글 · 카드 · 타일 · 버튼.
private struct FadeIn: ViewModifier {
    let shown: Bool
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .animation(reducesMotion ? nil
                       : .easeOut(duration: Self.duration).delay(Self.starts(order)),
                       value: shown)
    }

    private static func starts(_ order: Int) -> Double { Double(order) * step }

    /// 그 차례가 **다 뜨는** 시각. 획은 자기가 앉을 덩어리가 뜬 뒤에 그어진다.
    static func after(_ order: Int) -> Double { starts(order) + duration }

    private static let duration: Double = 0.35
    private static let step: Double = 0.14
}

private extension View {
    func fadesIn(_ shown: Bool, order: Int) -> some View {
        modifier(FadeIn(shown: shown, order: order))
    }
}

#if DEBUG
#Preview("01 권한 요청") {
    PermissionScreen(onRequest: {})
}
#endif
