// 앱 진입점. 저장소와 앨범 어댑터를 세우고 최상위에 꽂는다. 레이아웃 분기는 `RootView`가 진다.

import MomentKernel
import PhotoSource
import SwiftUI

@main
struct MoanogiApp: App {
    @State private var library: MomentLibrary
    @State private var store: ImageStore
    @State private var records = RecordLibrary(store: .inApplicationSupport)

    /// 사용자가 고른 소스 (`SRC-02`). **빈 문자열이 미지정이다** — `@AppStorage`는 옵셔널을
    /// 안 받는다.
    @AppStorage(SourceStorage.albumKey) private var albumID = ""

    /// 지금의 읽기 권한. **`01`이 설지를 이 값이 정한다** — 시스템이 이미 「물어봤는가」를
    /// 들고 있어 온보딩을 봤다는 플래그를 따로 저장하지 않는다.
    @State private var access = Self.startingAccess
    /// 부분 접근 — 시스템 피커를 다시 여는 방아쇠.
    @State private var picksMorePhotos = false

    /// 사용자가 고른 두 축. ⚠️ **같은 키를 보는 `13`·`13-A`가 고치면 여기가 따라 갱신된다** —
    /// 값을 아래로 내려보내는 길은 하나고, 위로 올리는 길은 저장소 자신이다.
    @AppStorage(AppearanceStorage.accentKey) private var accentSet = AccentSet.default
    @AppStorage(AppearanceStorage.modeKey) private var appearanceMode = AppearanceMode.default

    /// ⚠️ 서체 등록은 **첫 렌더보다 먼저** 일어나야 한다 — `.task`에 두면 한 프레임을
    /// 시스템 서체로 그리고 나서 바뀐다.
    init() {
        Typography.register()
        Typography.applyNavigationBar()
        // ⚠️ 소스 없이 세운다 — `@State`는 `@AppStorage`를 못 읽는다. 저장된 앨범은 `.task`가 건다.
        let library = MomentLibrary(albumID: nil)
        _library = State(initialValue: library)
        // ⚠️ **어댑터를 여기서 만들지 않는다** — 라이브러리가 든 것을 그때그때 본다.
        // 사본을 쥐면 소스를 바꾼 뒤에 낡은 앨범을 든 채로 계속 돈다.
        _store = State(initialValue: ImageStore(loader: { asset, pixels, network in
            try? await library.source.image(of: asset, maxPixelSize: pixels,
                                            allowingNetwork: network)
        }))
    }

    /// 저장된 값의 「미지정」 판정. 빈 문자열과 `nil`을 가르는 유일한 자리다.
    private var chosenAlbumID: String? { albumID.isEmpty ? nil : albumID }

    // ⚠️ `SwiftUI.Scene`으로 한정한다 — 커널에도 `Scene`(연사 묶음)이 있다.
    var body: some SwiftUI.Scene {
        WindowGroup {
            screen
                .environment(shownStore)
                .environment(\.recordStore, shownRecords.store)
                .environment(\.originalBytes, shownBytes)
                .environment(\.accentSet, accentSet)
                // ⚠️ **시스템 컨트롤(스위치·슬라이더·네비 버튼)을 칠하는 유일한 길이다** —
                // `Color.accentColor`는 이 값을 안 읽는다.
                .tint(accentSet.accent)
                .preferredColorScheme(appearanceMode.colorScheme)
                .limitedLibraryPicker(isPresented: $picksMorePhotos)
                .task { load() }
                .onChange(of: albumID) { load() }
        }
    }

    /// 저장된 소스를 걸고 분류를 시작한다. **거는 것과 시작이 갈려 있다** — 같은 두 줄이
    /// 첫 실행과 소스 변경 양쪽에 선다.
    private func load() {
        guard !usesFixture else { return }
        library.use(albumID: chosenAlbumID)
        library.start()
    }

    /// `01`을 지나야 앱 안이 뜬다 (`SYS-01`). 권한을 한 번 물으면 `notDetermined`를 영영
    /// 벗어나므로 **거부해도 다시 안 뜬다** — 그 갈래는 `02`가 받는다.
    @ViewBuilder
    private var screen: some View {
        #if DEBUG
        if usesFixture, ProcessInfo.processInfo.arguments.contains("01") {
            PermissionScreen(onRequest: {})
        } else if access == .notDetermined, !usesFixture {
            permission
        } else {
            rootScreen
        }
        #else
        if access == .notDetermined { permission } else { rootScreen }
        #endif
    }

    private var permission: some View {
        PermissionScreen {
            access = await AlbumPhotoSource.requestAccess()
            load()
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
        if usesFixture, arguments.contains("11-text") {
            canvasFixture(withText: true)
        } else if usesFixture, arguments.contains("11") {
            canvasFixture(withText: false)
        } else if usesFixture, arguments.contains("09-mixed") {
            root(editing: Fixture.mixedDraft)
        } else if usesFixture, arguments.contains("10-empty") {
            root(editing: Fixture.mixedDraft, opensPhotoAdd: true)
        } else if usesFixture, arguments.contains("10") {
            root(editing: .from(group: Fixture.groupWithBurst, library: Fixture.library),
                 opensPhotoAdd: true)
        } else if usesFixture, arguments.contains("09") {
            // 사진이 여럿인 순간으로 연다 — 1장짜리로는 격자도 스크롤도 안 보인다.
            root(editing: .from(group: Fixture.groupWithBurst, library: Fixture.library))
        } else if usesFixture, arguments.contains("14") {
            root(opensDepth: .terms)
        } else if usesFixture, arguments.contains("13-A") {
            root(opensDepth: .theme)
        } else if usesFixture, arguments.contains("04-empty") {
            emptyFixture
        } else if usesFixture, arguments.contains("02") {
            root(opensSource: true)
        } else if usesFixture, arguments.contains("13") {
            root(opensSettings: true)
        } else if usesFixture, arguments.contains("08") {
            root(tab: .records, opensRecord: true)
        } else if usesFixture, arguments.contains("07") {
            root(tab: .records)
        } else if usesFixture, arguments.contains("06") {
            PhotoViewerScreen(library: Fixture.library,
                              photos: Fixture.groupWithBurst.photoIndices,
                              start: Fixture.groupWithBurst.photoIndices[0])
        } else if usesFixture, arguments.contains("05") {
            NavigationStack {
                // `-fixture 05 dateonly`는 시각이 없는 묶음으로 연다.
                MomentDetailScreen(library: Fixture.library,
                                   group: arguments.contains("dateonly")
                                          ? Fixture.dateOnlyGroup : Fixture.groupWithBurst,
                                   editing: .constant(nil))
            }
        } else {
            root()
        }
        #else
        root()
        #endif
    }

    /// 빈 `04`의 갈래 둘. `-fixture 04-empty unplaced`는 **사진은 있는데 순간이 0인 판**이다 —
    /// 게임이 만든 앨범이 아닌 소스에서 실제로 나는 상태고, 시뮬레이터에는 그 앨범이 없다.
    @ViewBuilder
    private var emptyFixture: some View {
        let unplaced = ProcessInfo.processInfo.arguments.contains("unplaced")
        RootView(library: unplaced ? Fixture.unplacedLibrary : Fixture.unsetLibrary,
                 records: Fixture.records)
    }

    /// `-fixture 11` 문. ⚠️ 캔버스가 없는 플랫폼에서는 최상위가 그대로 뜬다.
    @ViewBuilder
    private func canvasFixture(withText: Bool) -> some View {
        #if os(iOS)
        if withText {
            root(canvas: Fixture.canvasWithText())
        } else if let draft = RecordDraft.from(group: Fixture.groupWithBurst,
                                               library: Fixture.library) {
            root(canvas: .opening(draft, in: shownRecords.store))
        } else {
            root()
        }
        #else
        root()
        #endif
    }

    #if os(iOS)
    private func root(editing: RecordDraft? = nil, canvas: CanvasSession? = nil,
                      opensPhotoAdd: Bool = false, tab: RootTab = .moments,
                      opensRecord: Bool = false, opensSettings: Bool = false,
                      opensDepth: SettingsDestination? = nil,
                      opensSource: Bool = false) -> some View {
        wired(RootView(library: shownLibrary, records: shownRecords, initialEditing: editing,
                       initialCanvas: canvas, opensPhotoAdd: opensPhotoAdd, initialTab: tab,
                       opensFirstRecord: opensRecord, opensSettings: opensSettings,
                       opensDepth: opensDepth),
              opensSource: opensSource)
    }
    #else
    private func root(editing: RecordDraft? = nil, opensPhotoAdd: Bool = false,
                      tab: RootTab = .moments, opensRecord: Bool = false,
                      opensSettings: Bool = false, opensDepth: SettingsDestination? = nil,
                      opensSource: Bool = false) -> some View {
        wired(RootView(library: shownLibrary, records: shownRecords, initialEditing: editing,
                       opensPhotoAdd: opensPhotoAdd, initialTab: tab, opensFirstRecord: opensRecord,
                       opensSettings: opensSettings, opensDepth: opensDepth),
              opensSource: opensSource)
    }
    #endif

    /// `02`가 쓰는 손잡이 둘을 꽂는다. **후보를 읽는 것도 고른 것을 저장하는 것도 여기다** —
    /// 화면은 받은 것을 그리고 고른 것을 돌려줄 뿐이다.
    private func wired(_ view: RootView, opensSource: Bool) -> RootView {
        var view = view
        view.opensSource = opensSource
        view.sourceCandidates = candidateSource
        view.onChooseSource = { albumID = $0 }
        view.access = access
        view.onPickMorePhotos = { picksMorePhotos = true }
        return view
    }

    /// ⚠️ **읽기 실패를 빈 목록으로 뭉갠다** — `candidates()`가 던지는 것은 권한 없음 하나뿐이고,
    /// 이 시트는 권한을 얻은 갈래에서만 이 목록을 그린다.
    private var candidateSource: () async -> [SourceCandidate] {
        #if DEBUG
        if usesFixture { return { Fixture.candidates(for: access) } }
        #endif
        // 부분 접근에는 앨범이 없다 — 허용된 사진 집합 하나가 그대로 후보다.
        if access == .limited {
            return {
                let permitted = (try? AlbumPhotoSource.permittedAssets()) ?? []
                return [SourceCandidate(id: "permitted", title: Wording.pickedPhotos,
                                        count: permitted.count,
                                        preview: Array(permitted.prefix(Layout.sourcePreviewLimit)))]
            }
        }
        return { (try? AlbumCatalog.candidates(previewLimit: Layout.sourcePreviewLimit)) ?? [] }
    }

    /// 시작할 때의 권한. `-access`는 **권한 갈래 셋을 시뮬레이터에서 보는 유일한 문이다** —
    /// 시뮬레이터에는 부분 접근을 만들 길이 없다.
    private static var startingAccess: ReadAccess {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-access"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "limited": return .limited
            case "denied": return .denied
            default: break
            }
        }
        #endif
        return AlbumPhotoSource.currentAccess()
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

    /// ⚠️ 저장은 네트워크를 연다 — 사용자가 명시적으로 누른 자리라 훑는 동안 안 여는
    /// 규칙(`R8`)이 여기엔 안 걸린다. 기다리는 화면은 저장 버튼 하나다.
    private var shownBytes: OriginalBytesLoader {
        #if DEBUG
        if usesFixture { return Fixture.originalBytes }
        #endif
        return { [library] asset in
            try await library.source.originalBytes(of: asset, allowingNetwork: true)
        }
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
