// 앱 진입점과 기기 분기. 화면 셋을 iPhone 푸시 / iPad 2단 중 하나에 앉힌다.
//
// **표현 분기가 사는 유일한 곳이다** (ADR `0001` 결정 5) — 커널은 분기가 금지돼 있고
// 어댑터는 조건문이 아니라 구현체 교체로 간다.

import MomentKernel
import PhotoSource
import SwiftUI

/// 출시 1은 소스를 코드에 고정한다. **어느 이름이 게임 것인지는 `App`만 안다** (ADR `0002`).
private let gameAlbumTitle = "Mabinogi Mobile"

@main
struct MoanogiApp: App {
    private let source = AlbumPhotoSource(albumTitle: gameAlbumTitle)

    @State private var library = MomentLibrary(albumTitle: gameAlbumTitle)
    @State private var store = ImageStore(source: AlbumPhotoSource(albumTitle: gameAlbumTitle))
    @State private var records = RecordStore.inApplicationSupport

    /// ⚠️ 서체 등록은 **첫 렌더보다 먼저** 일어나야 한다 — `.task`에 두면 한 프레임을
    /// 시스템 서체로 그리고 나서 바뀐다.
    init() {
        Typography.register()
        Typography.applyNavigationBar()
    }

    // ⚠️ `SwiftUI.Scene`으로 한정한다 — 커널에도 `Scene`(연사 묶음)이 있다.
    var body: some SwiftUI.Scene {
        WindowGroup {
            rootScreen
                .environment(shownStore)
                .environment(\.recordStore, records)
                // ⚠️ 저장은 네트워크를 연다 — 사용자가 명시적으로 누른 자리라 훑는 동안
                // 안 여는 규칙(`R8`)이 여기엔 안 걸린다. 기다리는 화면은 저장 버튼 하나다.
                .environment(\.originalBytes, { [source] asset in
                    try await source.originalBytes(of: asset, allowingNetwork: true)
                })
                .tint(Palette.accent)
                .task { if !usesFixture { library.start() } }
        }
    }

    // MARK: - 합성 데이터로 띄우기

    /// ⚠️ **시뮬레이터에서 화면을 눈으로 보기 위한 문** — 게임 앨범이 없는 기기에서는 `04`가
    /// 비어 레이아웃을 확인할 수 없다. 인자로만 열리고 릴리스 바이너리에는 없다.
    ///
    /// `-fixture` 합성 데이터로 앱 전체 · `-fixture 09` 그 화면을 바로 띄운다.
    private var usesFixture: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-fixture")
        #else
        false
        #endif
    }

    @ViewBuilder
    private var rootScreen: some View {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if usesFixture, arguments.contains("10"), let day = Fixture.library.days.first {
            RootView(library: Fixture.library,
                     initialEditing: .from(moment: Fixture.momentWithBurst, day: day.date,
                                           library: Fixture.library),
                     opensPhotoAdd: true)
        } else if usesFixture, arguments.contains("09"), let day = Fixture.library.days.first {
            // 사진이 여럿인 순간으로 연다 — 1장짜리로는 격자도 스크롤도 안 보인다.
            RootView(library: Fixture.library,
                     initialEditing: .from(moment: Fixture.momentWithBurst, day: day.date,
                                           library: Fixture.library))
        } else if usesFixture, arguments.contains("06") {
            PhotoViewerScreen(library: Fixture.library, moment: Fixture.momentWithBurst,
                              photos: Fixture.momentWithBurst.photoIndices,
                              start: Fixture.momentWithBurst.photoIndices[0])
        } else if usesFixture, arguments.contains("05") {
            NavigationStack {
                MomentDetailScreen(library: Fixture.library,
                                   moment: Fixture.momentWithBurst, editing: .constant(nil))
            }
        } else {
            RootView(library: shownLibrary)
        }
        #else
        RootView(library: shownLibrary)
        #endif
    }

    private var shownLibrary: MomentLibrary {
        #if DEBUG
        usesFixture ? Fixture.library : library
        #else
        library
        #endif
    }

    private var shownStore: ImageStore {
        #if DEBUG
        usesFixture ? Fixture.store : store
        #else
        store
        #endif
    }
}

extension EnvironmentValues {
    /// 기록 저장소. 값 타입이라 `@Observable` 주입이 아니라 환경값으로 흐른다.
    @Entry var recordStore = RecordStore.inApplicationSupport
    /// 원본 바이트 읽기. **기본값은 실패다** — 어댑터를 실제로 넣어주는 것은 앱 진입점뿐이고,
    /// 프리뷰는 합성 바이트를 넣는다.
    @Entry var originalBytes: OriginalBytesLoader = { _ in throw NoBytesLoader() }
}

/// 바이트를 끌어올 어댑터가 안 꽂혔다. 프리뷰와 테스트에서만 나온다.
private struct NoBytesLoader: Error {}

/// 화면 셋은 자기가 어느 레이아웃 안에 있는지 모른다.
///
/// ⚠️ **편집기가 뜨는 자리도 여기가 정한다** — 화면마다 상태를 들면 iPhone과 iPad에서
/// 같은 것이 두 벌 산다. 화면은 `editing`에 초안을 넣을 뿐이고, 덮개냐 지면이냐는 여기 몫이다.
struct RootView: View {
    let library: MomentLibrary
    /// 합성 데이터로 편집기를 바로 띄울 때만 채운다.
    var initialEditing: RecordDraft?
    /// 그 편집기 위에 `10` 시트까지 띄운다.
    var opensPhotoAdd = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected: Moment?
    @State private var editing: RecordDraft?

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                NavigationStack {
                    MomentListScreen(library: library, selection: nil, editing: $editing)
                        .navigationDestination(for: Moment.self) { moment in
                            // 뒤로 버튼은 시스템이 붙여준다. iPad는 pane 교체라 안 붙어 분기가 없다.
                            MomentDetailScreen(library: library, moment: moment,
                                               editing: $editing)
                        }
                }
                .fullScreenCover(item: $editing) { draft in
                    RecordEditorScreen(library: library, draft: draft,
                                       initialAddingPhotos: opensPhotoAdd) { editing = nil }
                }
            }
        }
        .task { if editing == nil { editing = initialEditing } }
    }

    /// iPad 2단. 목록 pane 34%는 **iPhone과 같은 3장/행**이 나오는 값이라 어림수가 아니다.
    ///
    /// ⚠️ **편집기도 여기 산다** — 전체를 덮으면 어디서 시작했는지가 사라지고, iPad에서는
    /// 우측 지면이 이미 iPhone 전체화면보다 넓다 (사용자 판정 2026-08-11).
    /// ⚠️ **`NavigationSplitView`를 안 쓴다** — 두 지면이 **종이 두 장**이라 시스템이 그리는
    /// 사이드바 재질·분할선과 싸우게 된다. 사이드바는 늘 보이고 접히지 않으므로
    /// 그 컨테이너가 주는 것 중 이 화면이 쓰는 것이 없다.
    private var splitLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: Spacing.paneGap) {
                MomentListScreen(library: library, selection: $selected, editing: $editing)
                    .frame(width: geometry.size.width * Layout.listPaneFraction)
                    .pane()
                detailPane
                    .pane()
            }
            .padding(Spacing.paneGap)
        }
        .background(Palette.paneOutside)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let draft = editing {
            RecordEditorScreen(library: library, draft: draft,
                               initialAddingPhotos: opensPhotoAdd) { editing = nil }
        } else if let moment = selected ?? library.days.first?.moments.first {
            MomentDetailScreen(library: library, moment: moment, editing: $editing)
        } else {
            Color.clear
        }
    }
}
