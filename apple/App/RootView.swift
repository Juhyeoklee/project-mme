// 최상위 구조 — 탭 둘(`순간` ‖ `기록`)과 기기 분기.
//
// **표현 분기가 사는 유일한 곳이다** — 화면들은 자기가 어느 레이아웃 안에
// 있는지 모르고, 편집기가 덮개로 뜨는지 지면으로 뜨는지도 여기가 정한다.

import MomentKernel
import PhotoSource
import PhotoSourceUI
import SwiftUI

/// 최상위 탭. **둘뿐이고 늘지 않는다** — 설정은 탭이 아니라 `04`의 버튼 하나다.
enum RootTab: String, CaseIterable, Identifiable {
    case moments
    case records

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moments: Wording.listTitle
        case .records: Wording.recordsTitle
        }
    }
}

struct RootView: View {
    let library: MomentLibrary
    let records: RecordLibrary
    /// 합성 데이터로 편집기를 바로 띄울 때만 채운다.
    var initialEditing: RecordDraft?
    #if os(iOS)
    /// 합성 데이터로 `11`을 바로 띄운다.
    var initialCanvas: CanvasSession?
    #endif
    /// 그 편집기 위에 `10` 시트까지 띄운다.
    var opensPhotoAdd = false
    var initialTab: RootTab = .moments
    /// 합성 데이터로 `08`을 바로 띄운다. ⚠️ **탭 안쪽으로 밀어 넣어야 값이 있다** — 밖에서
    /// 띄우면 탭 바가 없는 화면을 보게 되고, 그 조합이 실물과 다르다.
    var opensFirstRecord = false
    /// 합성 데이터로 `13`을 바로 연다.
    var opensSettings = false
    /// 합성 데이터로 `13` 아래 뎁스를 바로 연다.
    var opensDepth: SettingsDestination?
    /// 합성 데이터로 `02`를 바로 연다.
    var opensSource = false
    /// `02`가 후보를 어디서 받나. **뼈대가 진다** — 화면은 받은 것을 그리기만 한다.
    var sourceCandidates: () async -> [SourceCandidate] = { [] }
    /// 지금의 읽기 권한. `02`의 갈래를 이 값이 정한다.
    var access: ReadAccess = .authorized
    /// 부분 접근 — 시스템 피커를 다시 연다.
    var onPickMorePhotos: () -> Void = {}
    /// 고른 소스를 저장하는 길. `@AppStorage`가 앱 진입점에 있다.
    var onChooseSource: (String) -> Void = { _ in }

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.recordStore) private var store
    @Environment(\.originalBytes) private var originalBytes
    /// 편집 중에 이 지면을 떠나려는 시도. **확인을 받아야 실행된다.**
    @State private var pendingExit: (() -> Void)?
    /// 지우려는 기록. ⚠️ **iPad에서만 채워진다** — iPhone은 부른 화면이 자기가 시트를 띄운다.
    @State private var pendingDelete: Record?
    /// 고른 묶음을 **그 첫 사진의 자산 식별자로** 든다 (`SRC-03`).
    ///
    /// ⚠️ **`PhotoGroup`을 그대로 들면 안 된다** — 새 사진이 들어오면 첨자가 밀려 들고 있던
    /// 값이 **다른 사진들을 가리킨다.** 기록이 `effectiveRecord`에서 id로 되묻는 것과 같은 이유다.
    @State private var selectedAnchor: String?
    @State private var selectedRecord: Record?
    @State private var editing: RecordDraft?
    #if os(iOS)
    /// `11`이 고치고 있는 캔버스. **화면이 아니라 뼈대가 든다** — `09`에서 시작해 `08`에서
    /// 끝나는 작업이라 어느 한 화면보다 오래 산다.
    @State private var canvas: CanvasSession?
    #endif
    @State private var tab: RootTab
    @State private var recordPath: [Record] = []
    /// `13`이 떠 있는가. **뼈대가 든다** — iPad에서 창 가운데 서야 하고, 그것이 「결정이
    /// 걸린 범위」가 창이라는 뜻이다(구현 4 규칙).
    @State private var showsSettings = false
    /// iPhone에서 `13`으로 밀고 들어간 자리.
    @State private var settingsPath: [SettingsRoute] = []
    /// `02`가 떠 있는가. **소스가 없으면 저절로 올라온다**(`SYS-01`).
    @State private var showsSource = false
    /// 설정에서 열었는가. 나가는 낱말이 갈린다.
    @State private var changesSource = false
    /// `나중에`로 내렸는가. ⚠️ **안 들면 내린 자리에서 곧바로 다시 올라온다.**
    @State private var declinedSource = false
    @State private var candidates: [SourceCandidate] = []
    /// `SRC-05` — 거부 갈래에서 사진을 직접 집는 중.
    @State private var importsPhotos = false
    /// iPad 시트 **안**에서 밀고 들어간 자리. ⚠️ **바깥 경로와 갈라 둔다** — 시트가 닫히면
    /// 그 안의 깊이도 함께 사라져야 한다.
    @State private var sheetPath: [SettingsRoute] = []

    init(library: MomentLibrary, records: RecordLibrary, initialEditing: RecordDraft? = nil,
         opensPhotoAdd: Bool = false,
         initialTab: RootTab = .moments, opensFirstRecord: Bool = false,
         opensSettings: Bool = false, opensDepth: SettingsDestination? = nil) {
        self.library = library
        self.records = records
        self.initialEditing = initialEditing
        self.opensPhotoAdd = opensPhotoAdd
        self.initialTab = initialTab
        self.opensFirstRecord = opensFirstRecord
        self.opensSettings = opensSettings
        self.opensDepth = opensDepth
        _tab = State(initialValue: initialTab)
    }

    #if os(iOS)
    init(library: MomentLibrary, records: RecordLibrary, initialEditing: RecordDraft? = nil,
         initialCanvas: CanvasSession?, opensPhotoAdd: Bool = false,
         initialTab: RootTab = .moments, opensFirstRecord: Bool = false,
         opensSettings: Bool = false, opensDepth: SettingsDestination? = nil) {
        self.init(library: library, records: records, initialEditing: initialEditing,
                  opensPhotoAdd: opensPhotoAdd, initialTab: initialTab,
                  opensFirstRecord: opensFirstRecord, opensSettings: opensSettings,
                  opensDepth: opensDepth)
        self.initialCanvas = initialCanvas
    }
    #endif

    var body: some View {
        // ⚠️ **탭을 갈아끼우지 않고 둘 다 살려 둔다** — 갈아끼우면 화면 트리가 통째로 다시
        // 서면서 한 프레임이 깜빡이고, 스크롤 위치도 같이 사라진다.
        ZStack {
            pane(momentsTab, shown: tab == .moments)
            pane(recordsTab, shown: tab == .records)
        }
        .onChange(of: tab) { if tab == .records { records.reload() } }
        .modifier(EditorCover(editing: $editing, library: library, records: records,
                              opensPhotoAdd: opensPhotoAdd, isCompact: sizeClass == .compact))
        #if os(iOS)
        .fullScreenCover(item: $canvas) { session in
            CanvasScreen(session: session, retryToken: library.generation,
                         onClose: { canvas = nil }, onSaved: arrive)
        }
        #endif
        // ⚠️ **iPad에서만 뜬다** — iPhone은 밀고 들어간다. 시스템 폼 시트가 창 가운데
        // 540으로 서는 것이 곧 화면설계가 정한 폭이다.
        .sheet(isPresented: $showsSettings, onDismiss: { sheetPath = [] }) {
            NavigationStack(path: $sheetPath) {
                SettingsScreen(sourceName: library.sourceName,
                               onClose: { showsSettings = false },
                               onOpen: { sheetPath.append(SettingsRoute($0)) },
                               onChangeSource: { Task { await changeSource() } })
                    .navigationDestination(for: SettingsRoute.self) { route in
                        switch route {
                        case .theme: ThemeScreen(isInSheet: true)
                        case .terms: LegalScreen(document: Wording.terms, isInSheet: true)
                        case .privacy: LegalScreen(document: Wording.privacy, isInSheet: true)
                        case .settings: EmptyView()
                        }
                    }
            }
            .presentationBackground(Palette.pane)
        }
        .sheet(isPresented: $showsSource) {
            SourcePickerScreen(access: access, candidates: candidates,
                               current: library.albumID,
                               isChangingSource: changesSource,
                               onConfirm: { chosen in
                                   showsSource = false
                                   onChooseSource(chosen.id)
                               },
                               onDismiss: {
                                   showsSource = false
                                   declinedSource = true
                               },
                               onPickMore: onPickMorePhotos,
                               onOpenSettings: openSettings,
                               onImport: {
                                   showsSource = false
                                   importsPhotos = true
                               })
                .sourceSheet(isPad: sizeClass == .regular,
                             height: Layout.sourceSheetHeight(hasList: access.canRead,
                                                              hasCandidates: candidates.count > 1))
        }
        // ⚠️ **`09`로 곧장 간다** — 소스가 없으면 순간이 없고, 원칙 `P3`가 막은 것은
        // 「새 기록 만들기」 진입점이지 소스가 원리적으로 없는 갈래의 유일한 길이 아니다.
        .photoImporter(isPresented: $importsPhotos) { photo in
            let draft = editing ?? .importing()
            _ = draft.addImported(photo.data, fileExtension: photo.fileExtension)
            editing = draft
        }
        .confirmationDialog(Wording.discardTitle, isPresented: isConfirmingExit,
                            titleVisibility: .visible) {
            if editing?.canSave == true {
                Button(Wording.keepAsDraft) { leave(keepingDraft: true) }
            }
            Button(Wording.discard, role: .destructive) { leave(keepingDraft: false) }
        }
        .confirmationDialog(Wording.deleteRecordTitle, isPresented: isConfirmingDelete,
                            titleVisibility: .visible) {
            Button(Wording.delete, role: .destructive) { confirmDelete() }
        }
        .task { await offerSource() }
        .onChange(of: library.phase) { Task { await offerSource() } }
        // 부분 접근의 `사진 더 고르기`가 결과를 바로 보이는 자리다 — 후보는 시트를 올릴 때
        // 뜬 사본이라, 사진이 늘어도 다시 읽지 않으면 스트립이 옛것에 머문다.
        .onChange(of: library.sourceRevision) {
            guard showsSource else { return }
            Task { candidates = await sourceCandidates() }
        }
        .task {
            if opensSettings || opensDepth != nil {
                let depth = opensDepth.map(SettingsRoute.init)
                if sizeClass == .regular {
                    showsSettings = true
                    sheetPath = depth.map { [$0] } ?? []
                } else {
                    settingsPath = [.settings] + (depth.map { [$0] } ?? [])
                }
            }
            if editing == nil { editing = initialEditing }
            #if os(iOS)
            if canvas == nil { canvas = initialCanvas }
            #endif
        }
    }

    // MARK: - `02` 소스 지정

    /// 소스가 없으면 시트를 올린다. ⚠️ **`나중에`로 한 번 내리면 다시 안 올린다** — 그
    /// 자리에서 돌아올 길은 빈 `04`의 버튼이다.
    private func offerSource() async {
        guard opensSource || (library.phase == .needsSource && !declinedSource) else { return }
        guard !showsSource else { return }
        changesSource = false
        candidates = await sourceCandidates()
        showsSource = true
    }

    /// ⚠️ **`M3` 화면 문서가 iOS·iPadOS만 다룬다** — macOS 권한 모델은 「바」의 몫이다.
    private func openSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    /// `13`의 `소스` 행에서 연다. ⚠️ **설정을 먼저 내린다** — iPad에서 시트 위에 시트가 된다.
    private func changeSource() async {
        showsSettings = false
        candidates = await sourceCandidates()
        changesSource = true
        showsSource = true
    }

    /// iPad에서 확인 시트는 전부 여기서 뜬다 — **같은 결정이 부른 자리마다 다른 데 서지 않게.**
    /// ⚠️ 지면 안에서 띄우면 팝오버가 그 지면을 앵커로 잡는다.
    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func confirmDelete() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        records.delete(id: record.id)
    }

    // MARK: - 편집 중 이탈

    /// 편집 중이면 떠나기를 가로채 확인을 먼저 받는다.
    /// ⚠️ **iPhone에서는 안 걸린다** — 덮개가 목록과 탭 바를 통째로 덮어 누를 것이 없다.
    private func guardingEditor<Value>(_ binding: Binding<Value>) -> Binding<Value> {
        Binding(get: { binding.wrappedValue }, set: { new in
            if editing == nil {
                binding.wrappedValue = new
            } else {
                pendingExit = { binding.wrappedValue = new }
            }
        })
    }

    private var isConfirmingExit: Binding<Bool> {
        Binding(get: { pendingExit != nil }, set: { if !$0 { pendingExit = nil } })
    }

    /// ⚠️ **저장을 기다렸다가 떠난다** — 먼저 떠나면 실패를 말할 화면이 이미 사라지고 없어
    /// 만들던 것이 소리 없이 증발한다.
    private func leave(keepingDraft: Bool) {
        guard let go = pendingExit else { return }
        pendingExit = nil
        guard keepingDraft, let draft = editing else {
            editing = nil
            go()
            return
        }
        Task {
            guard await draft.save(status: .draft, to: store, bytes: originalBytes) != nil else {
                return
            }
            editing = nil
            records.reload()
            go()
        }
    }

    // MARK: - `11` 캔버스

    #if os(iOS)
    /// `09-T 캔버스로 만들기` — 초안을 그대로 들고 캔버스로 넘어간다.
    private func promote(_ draft: RecordDraft) {
        canvas = .opening(draft, in: store)
    }

    /// `08` — 캔버스 기록이면 그 문서를 열고, 초안이면 새 캔버스로 승격한다.
    private func openCanvas(_ record: Record) {
        canvas = CanvasSession.editing(record, in: store) ?? .opening(.editing(record), in: store)
    }

    /// `11-N4 저장` 뒤의 도착지는 `08`이다.
    private func arrive(at record: Record) {
        canvas = nil
        editing = nil
        records.reload()
        tab = .records
        selectedRecord = record
        if sizeClass == .compact { recordPath = [record] }
    }
    #endif

    /// 캔버스가 없는 플랫폼에서는 `nil`이라 `08`의 그 버튼이 죽는다.
    private var canvasOpener: ((Record) -> Void)? {
        #if os(iOS)
        openCanvas
        #else
        nil
        #endif
    }

    /// 같은 이유로 `09`의 승격 손잡이도 비운다.
    private func canvasPromoter(_ draft: RecordDraft) -> (() -> Void)? {
        #if os(iOS)
        { promote(draft) }
        #else
        nil
        #endif
    }

    /// 안 보이는 탭은 자리에 남되 눈과 손과 낭독에서 빠진다.
    /// ⚠️ **전환에 애니메이션을 걸지 않는다** — 걸면 지면이 흐려졌다 나타난다.
    private func pane(_ content: some View, shown: Bool) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
            .animation(nil, value: tab)
    }

    // MARK: - `순간` 탭

    @ViewBuilder
    private var momentsTab: some View {
        if sizeClass == .regular {
            twoPanes(list: MomentListScreen(library: library,
                                            selection: guardingEditor(effectiveGroup),
                                            editing: $editing,
                                            onOpenSettings: { showsSettings = true },
                                            onChooseSource: { Task { await changeSource() } }),
                     detail: momentPane)
        } else {
            NavigationStack(path: $settingsPath) {
                MomentListScreen(library: library, selection: nil, editing: $editing,
                                 onOpenSettings: { settingsPath.append(.settings) },
                                 onChooseSource: { Task { await changeSource() } })
                    .tabBar(selection: $tab)
                    .navigationDestination(for: PhotoGroup.self) { group in
                        // 뒤로 버튼은 시스템이 붙여준다. iPad는 pane 교체라 안 붙어 분기가 없다.
                        MomentDetailScreen(library: library, group: group, editing: $editing)
                    }
                    .navigationDestination(for: SettingsRoute.self) { route in
                        settingsDestination(route)
                    }
            }
        }
    }

    @ViewBuilder
    private func settingsDestination(_ route: SettingsRoute) -> some View {
        switch route {
        case .settings:
            SettingsScreen(sourceName: library.sourceName,
                           onOpen: { settingsPath.append(SettingsRoute($0)) },
                           onChangeSource: { Task { await changeSource() } })
        case .theme: ThemeScreen()
        case .terms: LegalScreen(document: Wording.terms)
        case .privacy: LegalScreen(document: Wording.privacy)
        }
    }

    @ViewBuilder
    private var momentPane: some View {
        if let draft = editing {
            editor(draft)
        } else if let group = effectiveGroup.wrappedValue {
            MomentDetailScreen(library: library, group: group, editing: $editing)
        } else {
            Color.clear
        }
    }

    // MARK: - `기록` 탭

    @ViewBuilder
    private var recordsTab: some View {
        if sizeClass == .regular {
            twoPanes(list: RecordListScreen(records: records,
                                            selection: guardingEditor(effectiveRecord),
                                            onRequestDelete: { pendingDelete = $0 }),
                     detail: recordPane)
        } else {
            NavigationStack(path: $recordPath) {
                RecordListScreen(records: records, selection: nil)
                    .tabBar(selection: $tab)
                    .navigationDestination(for: Record.self) { record in
                        RecordDetailScreen(library: library, records: records, record: record,
                                           editing: $editing)
                    }
            }
            .task {
                if opensFirstRecord, recordPath.isEmpty, let first = records.records.first {
                    recordPath = [first]
                }
            }
        }
    }

    @ViewBuilder
    private var recordPane: some View {
        if let draft = editing {
            editor(draft)
        } else if let record = effectiveRecord.wrappedValue {
            RecordDetailScreen(library: library, records: records, record: record,
                               editing: $editing, onRequestDelete: { pendingDelete = $0 },
                               onOpenCanvas: canvasOpener)
        } else {
            Color.clear
        }
    }

    // MARK: - iPad 2단

    /// ⚠️ **`NavigationSplitView`를 안 쓴다** — 그 컨테이너가 그리는 사이드바 재질·분할선과
    /// 싸우게 되고, 사이드바가 늘 보여 접힘도 안 쓴다.
    private func twoPanes(list: some View, detail: some View) -> some View {
        GeometryReader { geometry in
            HStack(spacing: Spacing.paneGap) {
                list
                    .frame(width: geometry.size.width * Layout.listPaneFraction)
                    .pane()
                    .overlay(alignment: .bottom) {
                        // ⚠️ **아래 여백이 `08` 툴바와 같아야 한다** — 다르면 나란히 선 두 바의
                        // 바닥선이 어긋나 높이가 달라 보인다.
                        RootTabBar(selection: guardingEditor($tab))
                            .padding(.bottom, 12)
                    }
                detail
                    .frame(maxWidth: .infinity)
                    .pane()
            }
            .padding(Spacing.paneGap)
        }
        .background(Palette.paneOutside)
    }

    /// iPad 지면의 편집기. ⚠️ **`취소`의 확인 시트를 여기가 띄운다** — 지면 안에서 띄우면
    /// 지면 가운데에 서서 목록·탭에서 부른 같은 시트와 자리가 달라진다.
    private func editor(_ draft: RecordDraft) -> some View {
        RecordEditorScreen(library: library, draft: draft,
                           initialAddingPhotos: opensPhotoAdd,
                           onRequestDiscard: { pendingExit = {} },
                           onPromoteToCanvas: canvasPromoter(draft)) {
            editing = nil
            records.reload()
        }
    }

    // MARK: - 선택

    /// ⚠️ **목록과 지면이 같은 값을 봐야 한다** — 아무것도 안 고른 상태에서도 지면은 첫 항목을
    /// 보여주므로, 그 사실을 목록에 돌려주지 않으면 **선택 표시가 아무 데도 안 붙는다.**
    ///
    /// ⚠️ **고른 묶음이 사라졌으면 최신으로 되돌아간다** — 소스에 사진이 들어오면 분류가 다시
    /// 서고(`SRC-03`) 묶음이 쪼개지거나 합쳐진다. 고른 사진이 어느 묶음에 들었는지는
    /// **새 분류가 답한다.**
    private var effectiveGroup: Binding<PhotoGroup?> {
        Binding(get: { group(anchoredAt: selectedAnchor) ?? library.days.first?.groups.first },
                set: { selectedAnchor = $0.flatMap { library.asset(at: $0.id)?.id } })
    }

    /// 그 자산이 지금 든 묶음. **날짜를 하나씩 보고 찾으면 그만둔다** — 묶음을 세우는 값이
    /// 싸지 않은데 이 값은 지면을 그릴 때마다 필요하다.
    private func group(anchoredAt assetID: String?) -> PhotoGroup? {
        guard let assetID, let index = library.index(of: assetID) else { return nil }
        for day in library.days {
            if let found = day.groups.group(containing: index) { return found }
        }
        return nil
    }

    /// ⚠️ **고른 기록이 사라졌으면 최신으로 되돌아간다** — 지운 기록을 계속 붙들면 우측
    /// 지면이 없는 것을 그리고, 저장으로 값이 바뀐 기록도 옛 값에 묶인다.
    private var effectiveRecord: Binding<Record?> {
        Binding(get: {
            let current = selectedRecord.flatMap { chosen in
                records.records.first { $0.id == chosen.id }
            }
            return current ?? records.records.first
        }, set: { selectedRecord = $0 })
    }
}

/// iPhone에서 편집기를 덮개로 띄운다. iPad는 지면을 갈아끼우므로 여기서 아무 일도 안 한다.
///
/// ⚠️ **덮개는 탭 바보다 위에 있어야 한다** — 탭 안쪽에 달면 작성 중에 탭을 옮길 수 있게 되고,
/// 그러면 만들던 것이 어디로 갔는지 화면이 말하지 않는다.
private struct EditorCover: ViewModifier {
    @Binding var editing: RecordDraft?
    let library: MomentLibrary
    let records: RecordLibrary
    let opensPhotoAdd: Bool
    let isCompact: Bool

    func body(content: Content) -> some View {
        // macOS는 좁은 판이 없어 이 덮개가 뜰 조건이 원리적으로 없다.
        #if os(iOS)
        content.fullScreenCover(item: isCompact ? $editing : .constant(nil)) { draft in
            RecordEditorScreen(library: library, draft: draft,
                               initialAddingPhotos: opensPhotoAdd) {
                editing = nil
                records.reload()
            }
        }
        #else
        content
        #endif
    }
}

extension View {
    /// 탭 바를 이 화면 바닥에 앉힌다. ⚠️ **탭의 뿌리 화면에만 건다** — `NavigationStack`이
    /// 바깥 인셋을 푸시 대상에 안 내려줘 `08` 툴바와 같은 자리에 포개진다.
    func tabBar(selection: Binding<RootTab>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            RootTabBar(selection: selection).padding(.bottom, 12)
        }
    }
}

/// 최상위 탭 바 — **손글씨 두 낱말**과 형광펜 하나.
///
/// 고른 것을 색이 아니라 **형광펜**이 말한다 — iPad 목록의 포커스 표시와 같은 획이다.
private struct RootTabBar: View {
    @Binding var selection: RootTab

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accentSet) private var accentSet

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RootTab.allCases) { tab in
                Button { selection = tab } label: { word(tab) }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 10)
        // ⚠️ **높이를 툴바와 같은 값으로 박는다** — 낱말 높이에 맡기면 `08` 툴바와 몇 pt가
        // 어긋나고, 둘이 한 화면에 서는 iPad에서 그 차이가 그대로 보인다.
        .frame(height: Layout.floatingBarHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        .blocksNearbyTaps()
    }

    /// ⚠️ **획은 낱말 자체를 덮는다** — 배경을 패딩 바깥에 두면 알약만큼 길어져 마커가 아니라
    /// 채워진 칸으로 읽힌다.
    private func word(_ tab: RootTab) -> some View {
        Text(tab.title)
            .font(Typography.tabLabel)
            .foregroundStyle(selection == tab ? accentSet.accent : Palette.secondaryLabel)
            .background {
                // ⚠️ **긋는 쪽에만 애니메이션이 있다** — 지우는 쪽에도 걸면 획 둘이 동시에
                // 움직여 어느 쪽을 고른 것인지가 그 동안 흐려진다.
                HighlighterSweep(drawn: selection == tab ? 1 : 0)
                    .fill(accentSet.glassHighlighter)
                    .blendMode(scheme == .dark ? .normal : .multiply)
                    .animation(selection == tab ? .easeOut(duration: 0.35) : nil,
                               value: selection)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .contentShape(.rect)
    }
}

/// `13` 아래로 밀고 들어가는 자리. **iPhone에서만 쓴다** — iPad는 시트 안에서 갈린다.
private enum SettingsRoute: Hashable {
    case settings
    case theme
    case terms
    case privacy

    init(_ destination: SettingsDestination) {
        switch destination {
        case .theme: self = .theme
        case .terms: self = .terms
        case .privacy: self = .privacy
        }
    }
}
