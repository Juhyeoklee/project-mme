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

    @Environment(\.originalBytes) private var originalBytes

    @State private var tool: CanvasTool = .select
    /// 획이 쓰는 색과 글이 쓰는 색. ⚠️ **갈라 둔다** — 잉크 목록은 하나지만 「지금 고른 색」은
    /// 아니다. 안 가르면 마커로 노랑을 쓰고 온 손이 노란 글씨를 쓰게 된다.
    @State private var ink: InkColor = .sumi
    @State private var textInk: InkColor = .sumi
    /// 도구마다 따로 기억하는 획 굵기와, 마커 진하기 (`11-O1`).
    @State private var widths: [CanvasTool: CGFloat] = [:]
    @State private var markerOpacity: CGFloat = InkColor.markerOpacity * 100
    @State private var selection: UUID?
    /// 글을 받고 있는 상자. ⚠️ **저장이 이것을 먼저 앉힌다** — 안 앉히면 방금 친 글이 사라진다.
    @State private var typing: CanvasTextEditing?
    @State private var popover: CanvasPopover?
    @State private var isConfirmingCancel = false
    /// 화면 맞춤 배율 위에 얹히는 배율·이동·각도. **문서는 안 돌아간다** — 굽는 결과도
    /// 저장 형식도 그대로다 (사용자 판정 2026-08-19).
    @State private var viewport = CanvasViewport()
    /// 소프트 키보드의 윗변(전역 좌표). **물리 키보드거나 없으면 화면 밖이라 아무 일도 안 한다.**
    @State private var keyboardTop: CGFloat = .infinity
    /// 키보드를 피하려고 올리기 전의 자리. 되돌릴 때 쓴다.
    @State private var panBeforeTyping: CGSize?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            stage
        }
        .background(Palette.paneOutside)
        // ⚠️ **키보드가 지면을 밀지 않는다** — 밀면 배율이 바뀌어 손이 기억한 자리가 통째로
        // 어긋난다. 가려지는 문제는 캔버스만 올려서 푼다 (`revealTyping`).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardTop = Self.top(of: note) ?? .infinity
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardTop = .infinity }
        }
        .task { enter() }
        // ⚠️ **글을 받기 시작하면 옵션을 닫는다** — 안 닫으면 하단 바가 팔레트에 묶여
        // `11-I`가 못 뜬다(팝오버가 열려 있으면 팔레트라는 규칙에 걸린다).
        .onChange(of: typing?.id) { _, id in
            if id != nil { popover = nil }
        }
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
                CanvasSurface(session: session, selection: $selection, typing: $typing,
                              tool: $tool, ink: ink, textInk: textInk,
                              strokeWidth: width(of: tool),
                              markerOpacity: markerOpacity / 100,
                              scale: scale * viewport.zoom, retryToken: retryToken,
                              onBackgroundTap: clearSelection, onFitToScreen: fitToScreen)
                    .scaleEffect(scale * viewport.zoom)
                    .rotationEffect(.radians(viewport.angle))
                    .offset(viewport.pan)
                    .frame(width: Layout.canvasSize.width * scale,
                           height: Layout.canvasSize.height * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.leading, Layout.canvasRailWidth + inset)
                    .gesture(panGesture)
                    .gesture(pinchGesture(leadingInset: Layout.canvasRailWidth + inset))
                    .gesture(rotateGesture(leadingInset: Layout.canvasRailWidth + inset))
                CanvasPageRail(session: session,
                               maxHeight: geometry.size.height - inset * 2)
                    .padding(inset)
            }
            // ⚠️ **무대에서 자른다** — 종이 밖으로 나간 사진이 상단바와 레일을 덮으면
            // 크롬이 캔버스 아래로 가라앉는다.
            .clipped()
            .onChange(of: TypingReveal(id: typing?.id, keyboardTop: keyboardTop)) { _, _ in
                revealTyping(in: geometry, scale: scale)
            }
            // ⚠️ **바는 키보드를 따라 올라간다** — 캔버스는 안 밀지만(배율이 바뀐다) 바까지
            // 두면 글을 받는 동안 컨트롤이 통째로 키보드 뒤에 숨는다.
            .overlay(alignment: .bottom) {
                bottomBar.padding(.bottom, inset + covered(in: geometry))
            }
        }
    }

    /// 두 손가락 핀치 — 캔버스 자체의 배율.
    private func pinchGesture(leadingInset: CGFloat) -> CanvasPinch {
        CanvasPinch(isEnabled: selection == nil, leadingInset: leadingInset) { factor, touch in
            viewport.magnify(by: factor, around: touch, within: Layout.canvasZoomRange)
        }
    }

    /// 두 손가락 회전 — 보는 각도.
    private func rotateGesture(leadingInset: CGFloat) -> CanvasRotate {
        CanvasRotate(isEnabled: selection == nil, leadingInset: leadingInset) { turned, touch in
            viewport.turn(by: turned, around: touch)
        }
    }

    /// 두 손가락 끌기 — 캔버스를 옮긴다.
    private var panGesture: CanvasPan {
        CanvasPan(
            isEnabled: selection == nil,
            onChanged: { moved in
                viewport.pan = CGSize(width: viewport.pan.width + moved.width,
                                      height: viewport.pan.height + moved.height)
            })
    }

    /// 더블탭 — 화면 맞춤으로 되돌린다. 배율·이동·각도를 함께 되돌린다.
    private func fitToScreen() { viewport.fitToScreen() }

    /// 키보드가 무대 바닥을 덮은 높이. **물리 키보드면 0이다.**
    private func covered(in geometry: GeometryProxy) -> CGFloat {
        max(0, geometry.frame(in: .global).maxY - keyboardTop)
    }

    /// 키보드가 글 상자를 가리면 캔버스를 그만큼 올린다.
    /// **물리 키보드에서는 가려지는 양이 0이라 아무 일도 안 일어난다.**
    private func revealTyping(in geometry: GeometryProxy, scale: CGFloat) {
        guard let id = typing?.id, let element = session.element(id) else {
            if let before = panBeforeTyping {
                panBeforeTyping = nil
                withAnimation(.easeOut(duration: 0.25)) { viewport.pan = before }
            }
            return
        }
        let base = panBeforeTyping ?? viewport.pan
        // ⚠️ **자리를 배율로만 재면 돌려놓은 캔버스에서 어긋난다** — 각도까지 보는 `place`가 진다.
        let bottom = CGPoint(x: element.frame.midX, y: element.frame.maxY)
        let center = geometry.frame(in: .global).minY + geometry.size.height / 2
        // 상자가 키보드뿐 아니라 **그 위에 선 하단 바**보다도 위에 와야 한다.
        let clearance = Layout.canvasPaletteHeight + Spacing.paneGap * 2
        let covered = center + base.height + viewport.place(bottom, scale: scale).y
            + clearance - keyboardTop
        guard covered > 0 else {
            if let before = panBeforeTyping {
                panBeforeTyping = nil
                withAnimation(.easeOut(duration: 0.25)) { viewport.pan = before }
            }
            return
        }
        panBeforeTyping = base
        withAnimation(.easeOut(duration: 0.25)) {
            viewport.pan = CGSize(width: base.width, height: base.height - covered)
        }
    }

    /// 키보드 윗변을 **창 좌표로** 옮긴다 — 알림이 주는 값은 화면 좌표라, 화면을 나눠 쓰면
    /// 그대로 비교할 수 없다.
    private static func top(of note: Notification) -> CGFloat? {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first
        else { return nil }
        return window.convert(frame, from: window.screen.coordinateSpace).minY
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
            CanvasInspector(session: session, elementID: id,
                            onInkTap: { popover = .ink },
                            onDelete: { session.remove(id); selection = nil })
        } else {
            CanvasToolPalette(tool: selectedTool, ink: currentInk, onReselect: openOptions,
                              onInkTap: { toggle(.ink) })
        }
    }

    @ViewBuilder
    private var openPopover: some View {
        switch popover {
        case .ink:
            InkOptions(stroke: nil, width: width(of: tool), opacity: markerOpacity,
                       ink: inkBinding, onWidth: { _ in }, onOpacity: { _ in })
        case .stroke:
            InkOptions(stroke: tool, width: width(of: tool), opacity: markerOpacity,
                       ink: inkBinding,
                       onWidth: { widths[tool] = $0 },
                       onOpacity: { markerOpacity = $0 })
        case .paper: PaperPicker(session: session)
        case .photos: PhotoDrawer(session: session, retryToken: retryToken, onPlace: place)
        case nil: EmptyView()
        }
    }

    private func width(of tool: CanvasTool) -> CGFloat {
        widths[tool] ?? tool.defaultWidth
    }

    /// 지금 쓰는 색 — **도구가 정한다.** 글자 도구면 글의 색이고 그 밖에는 획의 색이다.
    private var currentInk: InkColor {
        if let id = selection, let text = session.element(id)?.text { return text.ink }
        return tool == .text ? textInk : ink
    }

    /// 색을 고르면 **고른 글에 걸리고, 다음 글의 시작 색도 그것이 된다.**
    /// 글을 안 고른 채 고르면 획의 색이다.
    private var inkBinding: Binding<InkColor> {
        Binding(get: { currentInk }, set: { new in
            if let id = selection, session.element(id)?.text != nil {
                session.restyle(id) { $0.ink = new }
                textInk = new
            } else if tool == .text {
                textInk = new
            } else {
                ink = new
            }
        })
    }

    /// 도구를 바꾸는 한 자리. `선택` 도구만 고른 것을 지킨다.
    private var selectedTool: Binding<CanvasTool> {
        // ⚠️ **셋을 함께 놓는다** — 하나라도 남으면 하단 바가 인스펙터나 옛 팝오버에 묶여
        // 방금 고른 도구가 안 보인다.
        Binding(get: { tool }, set: { new in
            settleTyping()
            if new != .select { selection = nil }
            tool = new
            popover = new.showsOptionsWhenPicked ? options(of: new) : nil
        })
    }

    /// 활성 도구를 다시 누르면 옵션이 열린다 — iPadOS 관례 그대로다. **이미 열려 있으면 닫힌다.**
    private func openOptions(_ candidate: CanvasTool) {
        guard let options = options(of: candidate) else { return popover = nil }
        toggle(options)
    }

    /// 그 도구의 옵션 팝오버.
    private func options(of tool: CanvasTool) -> CanvasPopover? {
        switch tool {
        case .photo: .photos
        case .paper: .paper
        case .pen, .marker, .eraser: .stroke
        case .select, .text: nil
        }
    }

    private func clearSelection() {
        selection = nil
        popover = nil
    }

    /// 받고 있던 글을 앉힌다. **도구를 바꾸거나 저장하기 전에 부른다.**
    private func settleTyping() {
        typing?.commit(to: session)
        typing = nil
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
        // ⚠️ **도구도 `사진`이어야 한다** — 열린 팝오버의 주인 버튼이 활성이 아니면 그 관계가
        // 진입 상태에서만 깨진다.
        guard session.entry == .promotion, selection == nil else { return }
        selection = session.page.elements.first?.id
        tool = .photo
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
        settleTyping()
        guard let saved = await session.save(status: status, bytes: originalBytes)
        else { return }
        onSaved(saved)
    }

    private var saveFailed: Binding<Bool> {
        Binding(get: { session.draft.saveState.isFailed }, set: { _ in })
    }
}

/// 캔버스를 올려야 하는지 다시 보게 만드는 두 값. **둘 중 하나만 바뀌어도 다시 잰다** —
/// 키보드가 올라오는 것과 다른 상자로 옮겨 가는 것이 같은 일이다.
private struct TypingReveal: Equatable {
    let id: UUID?
    let keyboardTop: CGFloat
}
