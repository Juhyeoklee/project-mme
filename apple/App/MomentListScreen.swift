// `04` 순간 목록 (홈). 날짜와 순간을 훑으며 회상한다.
//
// `List`가 아니라 `ScrollView` + `LazyVStack(pinnedViews:)`를 쓴다. 확정 간격이 여섯 개인데
// (`8` `32` `16` `3` `2`, 토큰 §4) `List`는 자기 인셋과 구분선을 먼저 깔고 그 위에서 지워야 해서,
// 값이 맞는지 확인할 때마다 두 층을 같이 봐야 한다. 스티키 헤더는 `pinnedViews`가 그대로 준다.

import MomentKernel
import PhotoSource
import SwiftUI

struct MomentListScreen: View {
    let library: MomentLibrary
    /// iPad 2단에서 우측 pane이 보고 있는 순간. iPhone에서는 `nil`을 넘긴다.
    var selection: Binding<Moment?>?

    /// 스트립이 쓸 수 있는 폭. **한 행의 장수를 이 값이 정한다** (§2.3) —
    /// iPad 세로에서 목록 pane이 좁아지면 3장이 안 들어간다.
    @State private var stripWidth: CGFloat = Layout.thumbnail

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(library.days, id: \.date) { day in
                    Section {
                        ForEach(day.moments, id: \.photoIndices.first) { moment in
                            row(day: day, moment: moment)
                        }
                        // `04` 날짜 사이 32. 날짜 그룹의 **아래**에 붙는다 —
                        // 스티키 헤더가 위에서 밀려올 때 헤더 위에 빈칸이 생기면 안 된다.
                        Color.clear.frame(height: Spacing.dayGap)
                    } header: {
                        dayHeader(day)
                    }
                }
                if library.days.isEmpty { emptyOrSkeleton }
            }
        }
        .background(Palette.background)
        // 목록 폭을 재서 스트립에 넘긴다. 회전·분할 폭 변경이 그대로 따라온다.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width - Spacing.screenMargin * 2
        } action: { width in
            stripWidth = max(Layout.thumbnail, width)
        }
        .refreshable { await library.refresh() }
        .navigationTitle(Wording.listTitle)
        // 네비 배경을 항상 깐다. 기본값(스크롤에 따라 나타나는 투명 배경)에서는 사진이 네비 아래로
        // 비쳐 지나가는데, 바로 밑의 스티키 날짜 헤더는 불투명이라 **두 층이 어긋나 보인다**
        // (2026-08-04 실기기). 헤더를 반투명으로 맞추는 길도 있지만 그러면 사진 위에 글자가
        // 얹혀 훑기가 나빠진다 — 불투명 쪽을 택했다.
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .navigationSubtitle(Wording.summary(moments: library.momentCount, photos: library.photoCount))
        .toolbar {
            // `04-N3` — 출시 2의 설정이 들어올 자리. **눌러도 아무 일 없는 버튼을 놓지 않는다.**
            // 지키는 것은 썸네일 폭이 아니라 세로 공간이다 (설계서 §2.2).
            // 배경을 끄는 것이 핵심이다 — iOS 26은 툴바 아이템에 유리 캡슐을 깔아서,
            // 그냥 두면 빈 자리가 **눌러도 아무 일 없는 버튼처럼 보인다**. 설계서가 금지한 그것이다.
            ToolbarItem(placement: .topBarTrailing) {
                Color.clear.frame(width: 44, height: 44)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // `04-A1` — 네비 하단 경계선 위치. 높이 2pt. 결정형.
            // **"정리하는 중" 같은 문구가 없다** — 부제의 숫자가 올라가는 것이 그 말이다.
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
                // iPad — pane 교체. 밀고 들어가는 화면이 아니라 커서를 옮기는 것이다.
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
        // 우측은 비운다 — 출시 2의 `[기록 만들기]` 자리다.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, 12)
        // **네비 바와 같은 재질을 쓴다.** 처음에는 `바탕`(불투명 단색)을 깔았는데, 바로 위 네비 바는
        // 시스템 재질이라 **두 띠가 서로 다른 면으로 읽혔다**(2026-08-04 실기기). 둘 다 단색으로
        // 맞추는 길도 있었지만 그쪽은 평범해진다. 재질로 맞추면 스크롤 중 두 띠가 한 면처럼 붙는다.
        .background(.bar)
    }

    /// `04-E1` 또는 `04-D`. **어느 쪽인지는 아직 일하는 중인가로 갈린다.**
    @ViewBuilder
    private var emptyOrSkeleton: some View {
        if library.phase.isWorking {
            // `04-D` 지연 로드 자리표시. 스켈레톤 카드는 **1행 높이(118)로 고정**한다 —
            // 실제 데이터가 더 커서 아래로 늘어나는 방향은 스크롤이 튀지 않는다 (설계서 §2.2).
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
            // 빈 상태 "화면"이 아니다. 목록 자리를 채우는 **한 줄**이다 (설계서 §2.2).
            Text(Wording.empty)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
        }
    }
}

/// `04-A1`. 강조색 없이 회색만으로 그린다 — 출시 1에는 강조색이 들어갈 자리가 없다 (토큰 §6).
///
/// **채움에 팔레트 색을 쓰지 않는다.** 처음에는 자리표시(G5) 위에 강조면(G4)을 얹었는데
/// 다크에서 둘 다 검정에 가까워 진행바가 통째로 안 보였다(2026-08-04 프리뷰 실측).
/// 토큰 §2는 진행바에 색을 배정한 적이 없으므로 이건 토큰 개정이 아니라 **미배정 자리의 배정**이다.
/// 채움은 부제가 쓰는 `secondaryLabel`을 그대로 쓴다 — 두 모드에서 확실히 보이고,
/// 강조색을 들이지 않으며, "글자 회색은 팔레트 밖"이라는 §2의 위임과 같은 방향이다.
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
