// 앱 진입점. 저장소와 앨범 어댑터를 세우고 최상위에 꽂는다. 레이아웃 분기는 `RootView`가 진다.

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
    @State private var records = RecordLibrary(store: .inApplicationSupport)

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
                .environment(\.recordStore, shownRecords.store)
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

    /// 합성 데이터로 띄우는 문. `-fixture`는 앱 전체, `-fixture 09`는 그 화면을 바로 연다.
    /// ⚠️ **인자로만 열리고 릴리스 바이너리에는 없다.**
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
        if usesFixture, arguments.contains("09-mixed") {
            root(editing: Fixture.mixedDraft)
        } else if usesFixture, arguments.contains("10-empty") {
            root(editing: Fixture.mixedDraft, opensPhotoAdd: true)
        } else if usesFixture, arguments.contains("10"), let day = Fixture.library.days.first {
            root(editing: .from(moment: Fixture.momentWithBurst, day: day.date,
                                library: Fixture.library),
                 opensPhotoAdd: true)
        } else if usesFixture, arguments.contains("09"), let day = Fixture.library.days.first {
            // 사진이 여럿인 순간으로 연다 — 1장짜리로는 격자도 스크롤도 안 보인다.
            root(editing: .from(moment: Fixture.momentWithBurst, day: day.date,
                                library: Fixture.library))
        } else if usesFixture, arguments.contains("08") {
            root(tab: .records, opensRecord: true)
        } else if usesFixture, arguments.contains("07") {
            root(tab: .records)
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
            root()
        }
        #else
        root()
        #endif
    }

    private func root(editing: RecordDraft? = nil, opensPhotoAdd: Bool = false,
                      tab: RootTab = .moments, opensRecord: Bool = false) -> some View {
        RootView(library: shownLibrary, records: shownRecords, initialEditing: editing,
                 opensPhotoAdd: opensPhotoAdd, initialTab: tab, opensFirstRecord: opensRecord)
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

    private var shownRecords: RecordLibrary {
        #if DEBUG
        usesFixture ? Fixture.records : records
        #else
        records
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
