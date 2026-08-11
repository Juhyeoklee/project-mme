// `04` 순간 목록 (홈). 날짜와 순간을 훑으며 회상한다.
//
// `List`가 아니라 `ScrollView` + `LazyVStack(pinnedViews:)`를 쓴다 — 간격이 여섯 개 확정인데
// `List`는 자기 인셋과 구분선을 먼저 깔아, 값을 볼 때마다 두 층을 같이 봐야 한다.
//
// ⚠️ **시스템 네비 바를 쓰지 않는다.** iOS 26의 유리 바는 배경색을 주면 large title을 통째로
// 안 그린다 — 색의 종류와 무관하다(2026-08-11 탐침으로 확정). 머리는 직접 그린다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentListScreen: View {
    let library: MomentLibrary
    /// iPad 2단에서 우측 pane이 보고 있는 순간. iPhone에서는 `nil`을 넘긴다.
    var selection: Binding<Moment?>?
    /// 편집기가 뜰 자리는 `RootView`가 정한다 — 화면은 초안을 넣기만 한다.
    var editing: Binding<RecordDraft?>

    /// **한 행의 장수를 이 값이 정한다** — iPad 세로에서 pane이 좁아지면 3장이 안 들어간다.
    @State private var stripWidth: CGFloat = Layout.thumbnail
    /// 머리가 얼마나 줄었나. 0이면 펼침, 1이면 접힘.
    @State private var collapse: Double = 0
    /// 지금 네비가 말하는 날짜. 접힌 타이틀과 `04-B3`의 대상이 함께 이 값을 본다.
    @State private var topDayIndex = 0
    #if DEBUG
    @State private var showingSaved = false
    #endif

    var body: some View {
        // ⚠️ **머리를 겹쳐 띄운다** — 나란히 쌓으면 콘텐츠가 머리 아래로 지나가지 못해
        // 유리가 비출 것이 없다. 첫 화면에서 가려지지 않는 것은 목록의 상단 여백이 맡는다.
        list
            .overlay(alignment: .top) { header }
            .background(Palette.background)
        .overlay(alignment: .topLeading) { ThreadBinding() }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if library.phase.isWorking {
                ProgressBar(value: library.progress)
            }
        }
        #if DEBUG
        .sheet(isPresented: $showingSaved) { SavedRecordsDebugScreen() }
        #endif
    }

    // MARK: - `04-N` 머리

    /// **스크롤해도 남는다** — `04-N3` 설정이 여기 살아서, 사라지면 진입점이 사라진다.
    ///
    /// 대신 **줄어든다** — 타이틀이 32에서 18로 가고 요약 줄이 접힌다. 훑는 화면에서 상시
    /// 머리가 세로를 계속 먹는 것을 그렇게 갚는다.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ⚠️ **접힌 타이틀은 아이콘과 같은 줄에 선다** — 나눠 두면 스크롤한 뒤에도 두 줄이
            // 남아 네비 바로 안 읽힌다. 펼친 타이틀은 그 줄 왼쪽에 서고, 둘이 교차한다.
            ZStack {
                collapsedTitle.glassCapsule().collapsingInlineTitle(collapse)
                HStack(spacing: 0) {
                    expandedTitle
                        .lineLimit(1)
                        .opacity(1 - min(collapse * 2, 1))
                    Spacer(minLength: 0)
                    // **아이콘들이 유리 하나를 나눠 쓴다** — 낱개로 띄우면 알약이 흩어져 보이고,
                    // 이 셋은 「이 화면의 도구」라는 한 묶음이다.
                    HStack(spacing: 0) {
                        #if DEBUG
                        iconButton("tray.full", label: "저장") { showingSaved = true }
                        #endif
                        iconButton(Glyph.createRecord, label: Wording.createRecord) { startRecord() }
                        settingsSlot
                    }
                    .glassEffect(.regular, in: .capsule)
                }
            }
            .frame(height: Layout.hitTarget)
            Text(Wording.summary(moments: library.momentCount, photos: library.photoCount))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
                .collapsingSummary(collapse)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .padding(.leading, Spacing.listLeading)
        .padding(.trailing, Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .headerScrim()
    }

    /// 머리의 아이콘 하나. **유리는 이 뷰가 아니라 묶음이 진다.**
    private func iconButton(_ symbol: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // ⚠️ **심볼에 `.resizable()`을 쓰지 않는다** — 글리프마다 다른 안쪽 여백을 무시해
            // 광학 중심이 어긋난다. 크기는 활자로 준다.
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: Layout.hitTarget, height: Layout.hitTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.accent)
        .accessibilityLabel(label)
    }

    private var expandedTitle: Text {
        Text(Wording.listTitle)
            .font(Typography.accentTitle(Typography.headerLarge))
            .foregroundStyle(Palette.label)
    }

    /// 접히면 **지금 보고 있는 날짜**가 된다 — 목록에서 걷어낸 스티키가 하던 일이다.
    ///
    /// ⚠️ **액센트 서체를 쓰지 않는다.** 그 서체는 숫자 폭 편차가 17.8%라 날짜처럼 숫자가
    /// 쌓이는 자리에서 자릿수가 흔들린다. 네비 inline은 UI 서체의 몫이다.
    private var collapsedTitle: Text {
        Text(topDay.map(Wording.dateHeader) ?? Wording.listTitle)
            .font(Typography.time)
            .foregroundStyle(Palette.label)
    }

    /// `04-N3` — **설정 진입점은 앱 전체에서 여기 하나다.**
    /// ⚠️ 갈 화면은 아직 없다. 자리를 지금 세우는 것은 머리의 폭 계산이 그 슬롯을 전제하기 때문이다.
    private var settingsSlot: some View {
        Image(systemName: "gearshape")
            .font(.system(size: 20))
            .foregroundStyle(Palette.accent)
            .frame(width: Layout.hitTarget, height: Layout.hitTarget)
    }

    /// 헤더가 네비 아래로 지나가면 그 날짜가 「지금 보고 있는 날」이 된다.
    /// 되돌아 올라오면 앞 날짜로 돌아간다 — 그래서 최대·최소를 함께 본다.
    private func trackTopDay(index: Int, headerMinY: CGFloat) {
        if headerMinY < 0 {
            topDayIndex = max(topDayIndex, index)
        } else {
            topDayIndex = min(topDayIndex, max(index - 1, 0))
        }
    }

    private var topDay: CalendarDay? {
        library.days.indices.contains(topDayIndex) ? library.days[topDayIndex].date : nil
    }

    // MARK: - 목록

    /// ⚠️ **스티키를 끈다** (사용자 판정 2026-08-11). 날짜가 상단에 늘 붙어 있는 것이 촌스럽고,
    /// 네비와 두 띠로 갈리는 문제도 거기서 왔다. 대신 **지금 보고 있는 날짜가 네비에 뜬다** —
    /// 목록의 헤더는 날짜 경계를 표시하는 일만 남기고 함께 흘러간다.
    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(library.days.enumerated()), id: \.element.date) { index, day in
                    dayHeader(day)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .scrollView).minY
                        } action: { minY in
                            trackTopDay(index: index, headerMinY: minY)
                        }
                    ForEach(day.moments, id: \.photoIndices.first) { moment in
                        row(day: day, moment: moment)
                    }
                    Color.clear.frame(height: Spacing.dayGap)
                }
                if library.days.isEmpty { emptyOrSkeleton }
            }
        }
        // 머리가 겹쳐 떠 있으므로 첫 화면의 시작 자리를 여기서 준다. 펼친 높이 기준이라
        // 접힌 뒤에는 콘텐츠가 머리 아래로 더 지나간다 — 그게 유리가 하는 일이다.
        .contentMargins(.top, Layout.listHeaderHeight, for: .scrollContent)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            collapse = min(max(offset / Layout.hitTarget, 0), 1)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            stripWidth = max(Layout.thumbnail,
                             width - Spacing.listLeading - Spacing.screenMargin)
        }
        .refreshable { await library.refresh() }
    }

    private func row(day: Day, moment: Moment) -> some View {
        let card = MomentCard(moment: moment,
                              assetAt: library.asset(at:),
                              stripWidth: stripWidth,
                              retryToken: library.generation,
                              isSelected: selection?.wrappedValue == moment)
            .padding(.bottom, Spacing.momentGap)
            .padding(.leading, Spacing.listLeading)
            .padding(.trailing, Spacing.screenMargin)

        return Group {
            if let selection {
                Button { selection.wrappedValue = moment } label: { card }
                    .buttonStyle(.plain)
            } else {
                NavigationLink(value: moment) { card }
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - `04-B` 날짜 헤더

    /// ⚠️ **날짜 경계를 표시하는 일만 남았다** — 배경도 구분선도 없이 목록과 함께 흘러간다.
    /// 상단에 붙어 있는 동안 하던 일(지금 어느 날인가)은 네비가 가져갔다.
    private func dayHeader(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Wording.dateHeader(day.date))
                .font(Typography.date)
                .foregroundStyle(Palette.label)
            Text(Wording.summary(moments: day.moments.count, photos: day.photoCount))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .padding(.leading, Spacing.listLeading)
        .padding(.trailing, Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `04-B3` — `REC-02`의 진입점.
    ///
    /// ⚠️ **날짜마다 있던 것이 네비로 하나 올라왔다** (사용자 판정 2026-08-11). 대상은
    /// **지금 네비에 뜬 그 날짜**다 — 스크롤 위치가 곧 맥락이라, 무엇을 남기는지가 화면에 보인다.
    private func startRecord() {
        guard library.days.indices.contains(topDayIndex) else { return }
        editing.wrappedValue = RecordDraft.from(day: library.days[topDayIndex], library: library)
    }

    // MARK: - 빈 상태

    @ViewBuilder
    private var emptyOrSkeleton: some View {
        if library.phase.isWorking {
            // 1행 높이로 고정 — 실제 데이터가 더 커서 아래로 늘어나는 방향은 스크롤이 안 튄다.
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Palette.placeholder)
                    .frame(width: 140, height: 22)
                    .padding(.bottom, 12)
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Radius.thumbnail)
                        .fill(Palette.placeholder)
                        .frame(height: Layout.thumbnail)
                        .padding(.bottom, Spacing.momentGap)
                }
            }
            .padding(.leading, Spacing.listLeading)
            .padding(.trailing, Spacing.screenMargin)
            .padding(.top, 8)
        } else {
            Text(Wording.empty)
                .font(Typography.emptyState)
                .foregroundStyle(Palette.secondaryLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
        }
    }
}

/// ⚠️ **채움은 뉴트럴이면 안 된다** — 자리표시 위에 뉴트럴을 얹었더니 다크에서 둘 다
/// 검정에 가까워 바가 통째로 안 보였다 (2026-08-04). 강조색이 두 모드에서 그 문제를 없앤다.
private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Palette.placeholder
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

#if DEBUG
#Preview("04 정상") {
    NavigationStack {
        MomentListScreen(library: Fixture.library, selection: nil, editing: .constant(nil))
    }
    .environment(Fixture.store)
}

#Preview("04 첫 분류 중") {
    NavigationStack {
        MomentListScreen(library: Fixture.working, selection: nil, editing: .constant(nil))
    }
    .environment(Fixture.store)
}

#Preview("04 사진 0장") {
    NavigationStack {
        MomentListScreen(library: Fixture.emptyLibrary, selection: nil, editing: .constant(nil))
    }
    .environment(Fixture.store)
}
#endif
