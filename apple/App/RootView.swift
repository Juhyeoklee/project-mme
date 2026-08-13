// 최상위 구조 — 탭 둘(`순간` ‖ `기록`)과 기기 분기.
//
// **표현 분기가 사는 유일한 곳이다** (ADR `0001` 결정 5) — 화면들은 자기가 어느 레이아웃 안에
// 있는지 모르고, 편집기가 덮개로 뜨는지 지면으로 뜨는지도 여기가 정한다.

import MomentKernel
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
    /// 그 편집기 위에 `10` 시트까지 띄운다.
    var opensPhotoAdd = false
    var initialTab: RootTab = .moments
    /// 합성 데이터로 `08`을 바로 띄운다. ⚠️ **탭 안쪽으로 밀어 넣어야 값이 있다** — 밖에서
    /// 띄우면 탭 바가 없는 화면을 보게 되고, 그 조합이 실물과 다르다(2026-08-13).
    var opensFirstRecord = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.recordStore) private var store
    @Environment(\.originalBytes) private var originalBytes
    /// 편집 중에 이 지면을 떠나려는 시도. **확인을 받아야 실행된다.**
    @State private var pendingExit: (() -> Void)?
    /// 지우려는 기록. ⚠️ **iPad에서만 채워진다** — iPhone은 부른 화면이 자기가 시트를 띄운다.
    @State private var pendingDelete: Record?
    @State private var selectedMoment: Moment?
    @State private var selectedRecord: Record?
    @State private var editing: RecordDraft?
    @State private var tab: RootTab
    @State private var recordPath: [Record] = []

    init(library: MomentLibrary, records: RecordLibrary, initialEditing: RecordDraft? = nil,
         opensPhotoAdd: Bool = false, initialTab: RootTab = .moments,
         opensFirstRecord: Bool = false) {
        self.library = library
        self.records = records
        self.initialEditing = initialEditing
        self.opensPhotoAdd = opensPhotoAdd
        self.initialTab = initialTab
        self.opensFirstRecord = opensFirstRecord
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        // ⚠️ **탭을 갈아끼우지 않고 둘 다 살려 둔다** — 갈아끼우면 화면 트리가 통째로 다시
        // 서면서 한 프레임이 깜빡이고, 스크롤 위치도 같이 사라진다 (2026-08-12 실물).
        ZStack {
            pane(momentsTab, shown: tab == .moments)
            pane(recordsTab, shown: tab == .records)
        }
        .onChange(of: tab) { if tab == .records { records.reload() } }
        .modifier(EditorCover(editing: $editing, library: library, records: records,
                              opensPhotoAdd: opensPhotoAdd, isCompact: sizeClass == .compact))
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
        .task { if editing == nil { editing = initialEditing } }
    }

    /// iPad에서 확인 시트는 전부 여기서 뜬다 — **같은 결정이 부른 자리마다 다른 데 서지 않게.**
    /// ⚠️ 지면 안에서 띄우면 팝오버가 그 지면을 앵커로 잡는다 (사용자 판정 2026-08-13).
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
                                            selection: guardingEditor(effectiveMoment),
                                            editing: $editing),
                     detail: momentPane)
        } else {
            NavigationStack {
                MomentListScreen(library: library, selection: nil, editing: $editing)
                    .tabBar(selection: $tab)
                    .navigationDestination(for: Moment.self) { moment in
                        // 뒤로 버튼은 시스템이 붙여준다. iPad는 pane 교체라 안 붙어 분기가 없다.
                        MomentDetailScreen(library: library, moment: moment, editing: $editing)
                    }
            }
        }
    }

    @ViewBuilder
    private var momentPane: some View {
        if let draft = editing {
            editor(draft)
        } else if let moment = effectiveMoment.wrappedValue {
            MomentDetailScreen(library: library, moment: moment, editing: $editing)
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
                               editing: $editing, onRequestDelete: { pendingDelete = $0 })
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
                        // 바닥선이 어긋나 높이가 달라 보인다(2026-08-13 실측).
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
    /// 지면 가운데에 서서 목록·탭에서 부른 같은 시트와 자리가 달라진다 (사용자 판정 2026-08-13).
    private func editor(_ draft: RecordDraft) -> some View {
        RecordEditorScreen(library: library, draft: draft,
                           initialAddingPhotos: opensPhotoAdd,
                           onRequestDiscard: { pendingExit = {} }) {
            editing = nil
            records.reload()
        }
    }

    // MARK: - 선택

    /// ⚠️ **목록과 지면이 같은 값을 봐야 한다** — 아무것도 안 고른 상태에서도 지면은 첫 항목을
    /// 보여주므로, 그 사실을 목록에 돌려주지 않으면 **선택 표시가 아무 데도 안 붙는다.**
    private var effectiveMoment: Binding<Moment?> {
        Binding(get: { selectedMoment ?? library.days.first?.moments.first },
                set: { selectedMoment = $0 })
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
        content.fullScreenCover(item: isCompact ? $editing : .constant(nil)) { draft in
            RecordEditorScreen(library: library, draft: draft,
                               initialAddingPhotos: opensPhotoAdd) {
                editing = nil
                records.reload()
            }
        }
    }
}

extension View {
    /// 탭 바를 이 화면 바닥에 앉힌다. ⚠️ **탭의 뿌리 화면에만 건다** — `NavigationStack`이
    /// 바깥 인셋을 푸시 대상에 안 내려줘 `08` 툴바와 같은 자리에 포개진다(2026-08-13 실측).
    func tabBar(selection: Binding<RootTab>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            RootTabBar(selection: selection).padding(.bottom, 12)
        }
    }
}

/// 최상위 탭 바 — **손글씨 두 낱말**과 형광펜 하나.
///
/// 고른 것을 색이 아니라 **형광펜**이 말한다. 앱이 자기가 준 도구(`CAN-05`)로 자기 상태를
/// 말하므로 새 어휘가 0이고, iPad 목록의 포커스 표시와 같은 획이다.
private struct RootTabBar: View {
    @Binding var selection: RootTab

    @Environment(\.colorScheme) private var scheme

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
        // 어긋나고, 둘이 한 화면에 서는 iPad에서 그 차이가 그대로 보인다(2026-08-13 실기기).
        .frame(height: Layout.floatingBarHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        .blocksNearbyTaps()
    }

    /// ⚠️ **획은 낱말 자체를 덮는다** — 배경을 패딩 바깥에 두면 알약만큼 길어져 마커가 아니라
    /// 채워진 칸으로 읽힌다.
    private func word(_ tab: RootTab) -> some View {
        Text(tab.title)
            .font(Typography.tabLabel)
            .foregroundStyle(selection == tab ? Palette.accent : Palette.secondaryLabel)
            .background {
                // ⚠️ **긋는 쪽에만 애니메이션이 있다** — 지우는 쪽에도 걸면 획 둘이 동시에
                // 움직여 어느 쪽을 고른 것인지가 그 동안 흐려진다.
                HighlighterSweep(drawn: selection == tab ? 1 : 0)
                    .fill(Palette.highlighter)
                    .blendMode(scheme == .dark ? .normal : .multiply)
                    .animation(selection == tab ? .easeOut(duration: 0.35) : nil,
                               value: selection)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .contentShape(.rect)
    }
}
