// `11` 캔버스 에디터 — iPad·macOS 전용. 창 전체를 쓴다.

import SwiftUI

/// 일기장처럼 꾸미는 화면.
///
/// **하단 바는 하나고 상태가 셋이다** — 도구 팔레트 · 선택 인스펙터 · 「팝오버 + 팔레트」.
/// 자리와 높이가 같아 손이 기억한 위치가 안 흔들린다.
///
/// ⚠️ **문서 좌표(920×690)와 화면 좌표가 다르다.** 배율은 이 화면이 걸고 아래 조각들은
/// 문서 좌표만 안다 — 섞으면 창 크기가 저장된 자리를 바꾼다.
struct CanvasScreen: View {
    let session: CanvasSession
    /// 앨범이 2패스로 원본을 받아오면 값이 바뀐다 — 캔버스에 놓인 사진도 그때 다시 묻는다.
    let retryToken: Int
    /// 저장하지 않고 나간다.
    let onClose: () -> Void
    /// 저장했다. 도착지는 `08`이라 뼈대가 정한다.
    let onSaved: (Record) -> Void

    @Environment(\.recordStore) private var store
    @Environment(\.originalBytes) private var originalBytes

    @State private var tool: CanvasTool = .select
    @State private var ink: InkColor = .sumi
    @State private var selection: UUID?
    @State private var popover: CanvasPopover?
    @State private var isConfirmingCancel = false
    /// 화면 맞춤 배율 위에 곱해지는 사용자 줌.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var zoomAnchor: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            topBar
            stage
        }
        .background(Palette.paneOutside)
        .task { enter() }
        .confirmationDialog(cancelTitle, isPresented: $isConfirmingCancel,
                            titleVisibility: .visible) {
            cancelActions
        }
        .alert(Wording.saveFailed, isPresented: saveFailed) {
            Button(Wording.acknowledge) { session.draft.clearFailure() }
        }
    }

    // MARK: - `11-N` 상단바

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(Wording.cancel) { isConfirmingCancel = true }
                .buttonStyle(PlainActionStyle())
            Spacer(minLength: 0)
            historyButton(Glyph.undo, name: Wording.undo, enabled: session.canUndo) {
                session.undoChange()
            }
            historyButton(Glyph.redo, name: Wording.redo, enabled: session.canRedo) {
                session.redoChange()
            }
            Button(Wording.save) { Task { await save() } }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!session.draft.canSave)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 20)
        .frame(height: Layout.canvasTopBar)
        .background(Chrome.header)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.placeholder).frame(height: 1)
        }
    }

    private func historyButton(_ glyph: String, name: String, enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlyphIcon(glyph, size: 22)
                .foregroundStyle(enabled ? Palette.label : Palette.disabled)
                .frame(width: Layout.hitTarget, height: Layout.hitTarget)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(name)
    }

    // MARK: - 무대

    /// 레일은 왼쪽에 붙고 캔버스는 남는 자리 가운데에 선다 — 앱 전체의 「좌측 목록 ‖ 우측
    /// 지금 보는 것」과 같은 문법이라 어휘가 하나도 안 는다.
    private var stage: some View {
        GeometryReader { geometry in
            let inset = Spacing.paneGap
            let stageWidth = geometry.size.width - Layout.canvasRailWidth - inset * 2
            let scale = fitScale(width: stageWidth, height: geometry.size.height - inset * 2)
            ZStack(alignment: .topLeading) {
                CanvasSurface(session: session, selection: $selection, tool: tool, ink: ink,
                              scale: scale * zoom, retryToken: retryToken,
                              onBackgroundTap: clearSelection)
                    .scaleEffect(scale * zoom)
                    .offset(pan)
                    .frame(width: Layout.canvasSize.width * scale,
                           height: Layout.canvasSize.height * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.leading, Layout.canvasRailWidth + inset)
                    .simultaneousGesture(zoomGesture, including: zooming)
                    // ⚠️ **선택이 있으면 끈다** — 더블탭 인식기가 살아 있으면 그 아래 단일
                    // 탭이 실패를 기다렸다 발화해 고른 것을 바꾸는 일이 한 박자 늦는다.
                    .gesture(TapGesture(count: 2).onEnded { fitToScreen() }, including: zooming)
                CanvasPageRail(session: session)
                    .padding(inset)
            }
            // ⚠️ **무대에서 자른다** — 종이 밖으로 나간 사진이 상단바와 레일을 덮으면
            // 크롬이 캔버스 아래로 가라앉는다.
            .clipped()
            .overlay(alignment: .bottom) { bottomBar.padding(.bottom, inset) }
        }
    }

    /// 두 손가락이 캔버스에 걸리는가. **고른 것이 있으면 그쪽이 먼저 가져간다** — 같은 손짓
    /// 하나가 「지금 다루는 것」에 걸린다 (사용자 판정 2026-08-18).
    private var zooming: GestureMask { selection == nil ? .all : .none }

    /// 두 손가락 핀치 — 캔버스 자체의 배율.
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { zoom = clamped($0.magnification * zoomAnchor) }
            .onEnded { _ in zoomAnchor = zoom }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, Layout.canvasZoomRange.lowerBound), Layout.canvasZoomRange.upperBound)
    }

    /// 더블탭 — 화면 맞춤으로 되돌린다.
    private func fitToScreen() {
        zoom = 1
        zoomAnchor = 1
        pan = .zero
    }

    /// 캔버스가 무대 안에 다 들어오는 배율. 두 손가락 줌은 이 값 위에 곱해진다.
    private func fitScale(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return 1 }
        let room = min(width / Layout.canvasSize.width, height / Layout.canvasSize.height)
        return min(room, 1)
    }

    /// ⚠️ **팔레트는 캔버스 영역 가운데다** — 무대 전체 가운데에 두면 레일 폭만큼 왼쪽으로
    /// 밀려 캔버스와 축이 어긋난다.
    private var bottomBar: some View {
        VStack(spacing: 8) {
            openPopover
            barContent
        }
        .padding(.leading, Layout.canvasRailWidth + Spacing.paneGap)
    }

    /// 하단 바의 세 상태 중 둘. ⚠️ **팝오버가 열려 있으면 선택이 있어도 팔레트다** —
    /// 팝오버의 주인 버튼이 팔레트 안에 있어야 어느 도구의 옵션인지가 보인다.
    @ViewBuilder
    private var barContent: some View {
        if let id = selection, popover == nil {
            CanvasInspector(session: session, elementID: id, ink: ink,
                            onInkTap: { popover = .ink },
                            onDelete: { session.remove(id); selection = nil })
        } else {
            CanvasToolPalette(tool: $tool, ink: ink, onReselect: openOptions,
                              onInkTap: { toggle(.ink) })
        }
    }

    @ViewBuilder
    private var openPopover: some View {
        switch popover {
        case .ink: InkRow(ink: $ink)
        case .paper: PaperPicker(session: session)
        case .photos: PhotoDrawer(session: session, retryToken: retryToken, onPlace: place)
        case nil: EmptyView()
        }
    }

    /// 활성 도구를 다시 누르면 옵션이 열린다 — iPadOS 관례 그대로다.
    private func openOptions(_ candidate: CanvasTool) {
        switch candidate {
        case .photo: toggle(.photos)
        case .paper: toggle(.paper)
        case .pen, .marker, .eraser: toggle(.ink)
        case .select, .text: popover = nil
        }
    }

    private func clearSelection() {
        selection = nil
        popover = nil
    }

    private func toggle(_ candidate: CanvasPopover) {
        popover = popover == candidate ? nil : candidate
    }

    /// 서랍에서 탭한 사진은 캔버스 가운데에 놓인다.
    private func place(imageID: UUID) {
        session.place(imageID: imageID, at: CGPoint(x: Layout.canvasSize.width / 2,
                                                    y: Layout.canvasSize.height / 2),
                      fitting: Layout.canvasEntryPhotoSize)
        selection = session.page.elements.last?.id
    }

    /// 승격 직후의 진입 상태 — 첫 사진이 선택돼 있고 서랍이 열려 있다.
    private func enter() {
        guard session.entry == .promotion, selection == nil else { return }
        selection = session.page.elements.first?.id
        popover = .photos
    }

    // MARK: - 나가기

    private var cancelTitle: String {
        session.entry == .promotion ? Wording.discardCanvasTitle : Wording.discardCanvasEditTitle
    }

    @ViewBuilder
    private var cancelActions: some View {
        if session.entry == .promotion {
            Button(Wording.keepAsDraft) { Task { await save(status: .draft) } }
            Button(Wording.discard, role: .destructive) { onClose() }
        } else {
            Button(Wording.discard, role: .destructive) { onClose() }
            Button(Wording.keepEditing, role: .cancel) {}
        }
    }

    private func save(status: Record.Status = .published) async {
        guard let saved = await session.save(status: status, to: store, bytes: originalBytes)
        else { return }
        onSaved(saved)
    }

    private var saveFailed: Binding<Bool> {
        Binding(get: { session.draft.saveState.isFailed }, set: { _ in })
    }
}
