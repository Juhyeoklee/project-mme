// `04` 순간 목록 (홈). 날짜와 순간을 훑으며 회상한다.
//
// `List`가 아니라 `ScrollView` + `LazyVStack(pinnedViews:)`를 쓴다 — 간격이 여섯 개 확정인데
// `List`는 자기 인셋과 구분선을 먼저 깔아, 값을 볼 때마다 두 층을 같이 봐야 한다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentListScreen: View {
    let library: MomentLibrary
    /// iPad 2단에서 우측 pane이 보고 있는 순간. iPhone에서는 `nil`을 넘긴다.
    var selection: Binding<Moment?>?

    /// **한 행의 장수를 이 값이 정한다** — iPad 세로에서 pane이 좁아지면 3장이 안 들어간다.
    @State private var stripWidth: CGFloat = Layout.thumbnail

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(library.days, id: \.date) { day in
                    Section {
                        ForEach(day.moments, id: \.photoIndices.first) { moment in
                            row(day: day, moment: moment)
                        }
                        // ⚠️ 위가 아니라 아래에 붙인다 — 위면 스티키 헤더 위에 빈칸이 생긴다.
                        Color.clear.frame(height: Spacing.dayGap)
                    } header: {
                        dayHeader(day)
                    }
                }
                if library.days.isEmpty { emptyOrSkeleton }
            }
        }
        .background(Palette.background)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width - Spacing.screenMargin * 2
        } action: { width in
            stripWidth = max(Layout.thumbnail, width)
        }
        .refreshable { await library.refresh() }
        .navigationTitle(Wording.listTitle)
        // ⚠️ 네비 배경을 항상 깐다 — 기본 투명 배경이면 사진이 네비 아래로 비치는데
        // 바로 밑 스티키 헤더는 불투명이라 두 층이 어긋나 보인다 (2026-08-04 실기기).
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .navigationSubtitle(Wording.summary(moments: library.momentCount, photos: library.photoCount))
        .toolbar {
            // 세로 공간을 잡아두는 빈 자리.
            // ⚠️ 배경을 꺼야 한다 — iOS 26이 툴바 아이템에 유리 캡슐을 깔아 버튼처럼 보인다.
            ToolbarItem(placement: .topBarTrailing) {
                Color.clear.frame(width: 44, height: 44)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if library.phase.isWorking {
                ProgressBar(value: library.progress)
            }
        }
    }

    // MARK: - 조각

    private func row(day: Day, moment: Moment) -> some View {
        let card = MomentCard(moment: moment,
                              assetAt: library.asset(at:),
                              stripWidth: stripWidth,
                              retryToken: library.generation,
                              isSelected: selection?.wrappedValue == moment)
            .padding(.bottom, Spacing.momentGap)

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

    private func dayHeader(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Wording.dateHeader(day.date))
                .font(Typography.date)
            Text(Wording.summary(moments: day.moments.count, photos: day.photoCount))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, 12)
        // ⚠️ 네비 바와 같은 재질이어야 한다 — 불투명 단색은 두 띠가 다른 면으로 읽힌다
        // (2026-08-04 실기기).
        .background(.bar)
    }

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
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, 8)
        } else {
            Text(Wording.empty)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
        }
    }
}

/// ⚠️ **채움에 `Palette` 색을 쓰지 마라** — 자리표시 위에 활성색을 얹었더니 다크에서 둘 다
/// 검정에 가까워 바가 통째로 안 보였다 (2026-08-04).
struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Palette.placeholder
                Rectangle()
                    .fill(.secondary)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 2)
    }
}

#if DEBUG
#Preview("04 정상") {
    NavigationStack {
        MomentListScreen(library: Fixture.library, selection: nil)
    }
    .environment(Fixture.store)
}

#Preview("04 첫 분류 중") {
    NavigationStack {
        MomentListScreen(library: Fixture.working, selection: nil)
    }
    .environment(Fixture.store)
}

#Preview("04 사진 0장") {
    NavigationStack {
        MomentListScreen(library: Fixture.emptyLibrary, selection: nil)
    }
    .environment(Fixture.store)
}
#endif
