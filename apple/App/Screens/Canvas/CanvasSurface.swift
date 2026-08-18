// `11-C` 캔버스 면 — 종이 · 놓인 것들 · 획 층 · 선택 표시.
//
// ⚠️ **여기는 크롬 문법이 꺼진 자리다.** 놓인 사진에 테두리도 그림자도 없다 — 앱 UI가
// 층을 쌓는 방식과 정반대인 것이 「캔버스 안에 들어왔다」는 신호를 재질만으로 세운다.

import SwiftUI

/// 캔버스 한 장을 고정 좌표(920×690)로 그린다.
///
/// **좌표계가 창 크기와 무관하다** — 배율은 바깥이 걸고 여기는 문서 좌표만 안다. 그래서 창이
/// 커져도 저장된 자리가 안 흔들린다.
///
/// ⚠️ **획 층은 그리는 도구일 때만 손을 받는다.** 늘 켜 두면 `선택` 도구에서 사진을 못 집는다.
struct CanvasSurface: View {
    let session: CanvasSession
    @Binding var selection: UUID?
    let tool: CanvasTool
    let ink: InkColor
    /// 화면에 그려지는 배율. 선택 표시가 이 값에 반비례해 굵기를 유지한다.
    let scale: CGFloat
    let retryToken: Int
    /// 빈 곳을 탭했다 — 선택 해제와 팝오버 닫기가 한 동작이라 부르는 쪽이 함께 진다.
    let onBackgroundTap: () -> Void

    /// 손이 붙어 있는 동안의 자리. **놓을 때 한 번만 되돌리기에 등록한다.**
    @State private var live: LiveTransform?

    var body: some View {
        CanvasPageContent(session: session, page: session.page, pixels: Layout.gridPixels,
                          retryToken: retryToken, override: live, castsShadow: true,
                          clipsToPaper: false)
            .overlay {
                DrawingLayer(session: session, tool: tool, ink: ink)
                    .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height)
                    .allowsHitTesting(tool.draws)
            }
            .overlay {
                if let element = selected {
                    CanvasSelectionBox(element: element, scale: scale,
                                       onResize: { resize(corner: $0, by: $1, of: element) },
                                       onRotate: { rotate(by: $0, of: element) },
                                       onCommit: commit)
                        .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height,
                               alignment: .topLeading)
                }
            }
            .contentShape(.rect)
            // ⚠️ **그리는 동안은 SwiftUI 제스처를 통째로 끈다.** 인식되는 순간
            // `cancelsTouchesInView`가 PencilKit의 터치를 잘라 획이 시작조차 안 된다.
            .gesture(pointerGesture, including: pointing)
            .simultaneousGesture(transformGesture, including: transforming)
    }

    /// 그리는 도구가 켜져 있으면 앱 제스처를 전부 비운다.
    private var pointing: GestureMask { tool.draws ? .none : .all }

    /// 두 손가락이 고른 것에 걸리는가. **아무것도 안 골랐으면 캔버스 줌으로 넘어간다.**
    private var transforming: GestureMask {
        tool.draws || selection == nil ? .none : .all
    }

    /// 선택된 요소를, 손이 붙어 있으면 그 자리로.
    private var selected: CanvasElement? {
        guard let id = selection, var element = session.element(id) else { return nil }
        if let live, live.id == id {
            element.frame = live.frame
            element.rotation = live.rotation
        }
        return element
    }

    // MARK: - 옮기기 · 크기 · 회전

    /// 탭과 끌기를 한 인식기가 진다.
    private var pointerGesture: some Gesture {
        // ⚠️ **가르지 마라** — 탭 인식기를 따로 두면 드래그·핀치가 실패하기를 기다렸다
        // 발화해서, 고른 것을 바꾸는 일이 한 박자 늦는다(2026-08-18 실물).
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard tool == .select, live?.grip ?? .move == .move else { return }
                guard live != nil || Self.moved(value.translation) else { return }
                let held = live.flatMap { session.element($0.id) }
                guard let element = held ?? topmost(at: value.startLocation) else { return }
                if selection != element.id { selection = element.id }
                let base = live?.id == element.id ? live! : LiveTransform(element)
                live = base.moved(by: value.translation)
            }
            .onEnded { value in
                if live != nil {
                    commit()
                } else if !Self.moved(value.translation) {
                    tapped(at: value.location)
                }
            }
    }

    /// 손가락이 제자리에서 떨어졌으면 탭이다.
    private static func moved(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) > 3
    }

    private func tapped(at point: CGPoint) {
        if tool == .select, let element = topmost(at: point) {
            selection = element.id
        } else {
            onBackgroundTap()
        }
    }

    /// 두 손가락 — 고른 것을 키우고 돌린다 (`CAN-02`). **손이 회전 핸들보다 먼저 안다.**
    private var transformGesture: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture())
            .onChanged { value in
                guard let id = selection, let element = session.element(id) else { return }
                let base = live?.id == id && live?.grip == .pinch
                    ? live! : LiveTransform(element, grip: .pinch)
                live = base.scaled(by: value.first?.magnification ?? 1,
                                   turnedBy: value.second?.rotation.degrees ?? 0)
            }
            .onEnded { _ in commit() }
    }

    /// 종횡비를 지킨다 — 사진이 늘어나면 「원본을 건드리지 않는다」가 눈에서 깨진다.
    private func resize(corner: CanvasCorner, by translation: CGSize, of element: CanvasElement) {
        guard live?.grip ?? .handle == .handle else { return }
        let base = live?.id == element.id ? live! : LiveTransform(element, grip: .handle)
        live = base.resized(corner: corner, by: translation)
    }

    private func rotate(by translation: CGSize, of element: CanvasElement) {
        guard live?.grip ?? .handle == .handle else { return }
        let base = live?.id == element.id ? live! : LiveTransform(element, grip: .handle)
        live = base.scaled(by: 1, turnedBy: Double(translation.width) / 4)
    }

    /// 겹쳐 있으면 위에 있는 것이 잡힌다 — 배열 뒤쪽이 위다.
    private func topmost(at point: CGPoint) -> CanvasElement? {
        session.page.elements.last { $0.frame.contains(point) }
    }

    private func commit() {
        guard let live else { return }
        session.update(live.id, frame: live.frame, rotation: live.rotation)
        self.live = nil
    }
}

/// 손이 붙어 있는 동안의 자리.
///
/// ⚠️ **기준값(`origin*`)은 손을 대기 직전의 것으로 고정된다.** 매 프레임의 결과에 다시
/// 얹으면 같은 제스처가 스스로를 먹어 배율과 각도가 폭주한다.
struct LiveTransform: Equatable {
    /// 무엇이 손에 잡혔나. **셋이 서로 끼어들지 않는다** — 자리 끌기 · 핸들 · 두 손가락.
    /// ⚠️ **두 손가락이 이긴다** — 핸들을 끌던 중에 손가락 둘이 닿으면 그쪽으로 넘어간다.
    enum Grip { case move, handle, pinch }

    let id: UUID
    let grip: Grip
    let origin: CGRect
    let originRotation: Double
    var frame: CGRect
    var rotation: Double

    init(_ element: CanvasElement, grip: Grip = .move) {
        id = element.id
        self.grip = grip
        origin = element.frame
        originRotation = element.rotation
        frame = element.frame
        rotation = element.rotation
    }

    func moved(by translation: CGSize) -> LiveTransform {
        var moved = self
        moved.frame = origin.offsetBy(dx: translation.width, dy: translation.height)
        return moved
    }

    /// 가운데를 붙잡고 키운다 — 두 손가락은 붙잡을 모서리가 없다.
    func resized(corner: CanvasCorner, by translation: CGSize) -> LiveTransform {
        var changed = self
        let radians = -originRotation * .pi / 180
        let dx = translation.width * cos(radians) - translation.height * sin(radians)
        let aspect = origin.height / max(origin.width, 1)
        let width = max(60, origin.width + dx * corner.signX)
        changed.frame = corner.rect(from: origin, width: width, height: width * aspect)
        return changed
    }

    func scaled(by magnification: CGFloat, turnedBy degrees: Double) -> LiveTransform {
        var changed = self
        let width = max(60, origin.width * magnification)
        let height = width * (origin.height / max(origin.width, 1))
        changed.frame = CGRect(x: origin.midX - width / 2, y: origin.midY - height / 2,
                               width: width, height: height)
        changed.rotation = originRotation + degrees
        return changed
    }

}

/// 페이지 하나의 알맹이 — 종이와 놓인 것들. **캔버스와 레일 썸네일이 같은 것을 쓴다.**
///
/// ⚠️ **선택 표시가 여기 없다.** 썸네일에도 딸려가면 레일에 핸들이 그려진다.
struct CanvasPageContent: View {
    let session: CanvasSession
    let page: CanvasPage
    /// 이미지 긴 변의 화소 상한. 썸네일은 훨씬 작은 값을 준다.
    let pixels: Int
    /// 앨범 2패스가 원본을 받아오면 바뀌는 값. 레일 썸네일은 안 쓴다.
    var retryToken = 0
    /// 손이 붙어 있는 요소의 자리.
    var override: LiveTransform?
    /// 종이가 지면 위에 뜬 것으로 보이는가. ⚠️ **면 전체에 걸면 안 된다** — 종이 밖으로
    /// 걸쳐 놓은 사진에까지 그림자가 붙어, 캔버스 안에서 껐던 크롬 문법이 되살아난다.
    var castsShadow = false
    /// 종이 밖으로 나간 것을 잘라내는가. **고치는 동안은 안 자르고, 결과를 보여주는
    /// 자리**(레일 썸네일 · 굽기)**만 자른다.**
    var clipsToPaper = true

    var body: some View {
        if clipsToPaper {
            stack.clipShape(.rect(cornerRadius: Radius.canvas))
        } else {
            stack
        }
    }

    private var stack: some View {
        ZStack(alignment: .topLeading) {
            CanvasPaperView(paper: page.paper)
                .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height)
                .clipShape(.rect(cornerRadius: Radius.canvas))
                .shadow(color: castsShadow ? Chrome.shadowColor : .clear,
                        radius: Chrome.shadowRadius, y: Chrome.shadowOffset)
            ForEach(page.elements) { element in
                placed(shown(element))
            }
        }
        .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height)
    }

    private func shown(_ element: CanvasElement) -> CanvasElement {
        guard let override, override.id == element.id else { return element }
        var moved = element
        moved.frame = override.frame
        moved.rotation = override.rotation
        return moved
    }

    @ViewBuilder
    private func placed(_ element: CanvasElement) -> some View {
        content(element)
            .frame(width: element.frame.width, height: element.frame.height)
            .clipShape(.rect(cornerRadius: Radius.canvas))
            .rotationEffect(.degrees(element.rotation))
            .position(x: element.frame.midX, y: element.frame.midY)
            // ⚠️ **요소는 손을 안 받는다** — 무엇을 집었는지는 면이 좌표로 판정한다.
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(_ element: CanvasElement) -> some View {
        if let imageID = element.imageID, let photo = photo(imageID) {
            DraftPhotoImage(photo: photo, draft: session.draft, pixels: pixels,
                            retryToken: retryToken)
        } else {
            Color.clear
        }
    }

    private func photo(_ imageID: UUID) -> DraftPhoto? {
        session.draft.photos.first { $0.id == imageID }
    }
}

/// 모서리 핸들 넷의 자리. **마주 보는 모서리가 고정된다.**
enum CanvasCorner: CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var signX: CGFloat { self == .topLeading || self == .bottomLeading ? -1 : 1 }
    var signY: CGFloat { self == .topLeading || self == .topTrailing ? -1 : 1 }

    func rect(from base: CGRect, width: CGFloat, height: CGFloat) -> CGRect {
        let x = signX > 0 ? base.minX : base.maxX - width
        let y = signY > 0 ? base.minY : base.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// `11-C6` 선택 표시 — 테두리 · 모서리 핸들 넷 · 회전 핸들.
///
/// ⚠️ **히트 영역이 44보다 훨씬 좁다** (사용자 판정 2026-08-18). 44는 손가락 놓는 자리와
/// 그대로 겹쳐, 두 손가락으로 키우려 하면 핸들이 먼저 물어 크기와 회전이 엉킨다.
/// **정밀 포인터(마우스 · 트랙패드 · 펜슬 끝)만 닿는 크기**이고, 손가락 쪽 길은 두 손가락이
/// 따로 갖고 있어 이 좁힘이 기능을 막지 않는다.
///
/// ⚠️ **모드를 따르지 않는다.** 캔버스 위에 얹히는 크롬은 캔버스와 함께 모드 밖에 선다 —
/// 채움을 `바탕` 토큰으로 두면 다크에서 거의 검정이 되어 밝은 종이 위에서 사라진다.
///
/// ⚠️ **테라코타 채움 + 흰 테두리다.** 뒤집으면(흰 채움) 종이 4종 중 흰색 위에서 묻힌다.
/// 이 배색이 흰 종이와 어두운 사진 양쪽을 한 값으로 푼다.
private struct CanvasSelectionBox: View {
    let element: CanvasElement
    let scale: CGFloat
    let onResize: (CanvasCorner, CGSize) -> Void
    let onRotate: (CGSize) -> Void
    let onCommit: () -> Void

    private static let fill = Color(hex: 0xB0552B)
    private static let edge = Color(hex: 0xFFFFFF)
    private static let handle: CGFloat = 12
    private static let rotationHandle: CGFloat = 14
    private static let neck: CGFloat = 26
    /// 손가락은 못 닿고 포인터는 닿는 크기.
    private static let touch: CGFloat = 16

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Self.fill, lineWidth: 2 / scale)
                .frame(width: element.frame.width, height: element.frame.height)
                .allowsHitTesting(false)
            ForEach(CanvasCorner.allCases, id: \.self) { corner in
                dot(Self.handle)
                    .offset(x: corner.signX * element.frame.width / 2,
                            y: corner.signY * element.frame.height / 2)
                    .gesture(DragGesture()
                        .onChanged { onResize(corner, $0.translation) }
                        .onEnded { _ in onCommit() })
            }
            rotationHandleView
        }
        .rotationEffect(.degrees(element.rotation))
        .position(x: element.frame.midX, y: element.frame.midY)
    }

    private var rotationHandleView: some View {
        let top = -element.frame.height / 2
        return ZStack {
            Rectangle()
                .fill(Self.fill)
                .frame(width: 2 / scale, height: Self.neck / scale)
                .offset(y: top - Self.neck / scale / 2)
                .allowsHitTesting(false)
            dot(Self.rotationHandle)
                .offset(y: top - Self.neck / scale - Self.rotationHandle / scale / 2)
                .gesture(DragGesture()
                    .onChanged { onRotate($0.translation) }
                    .onEnded { _ in onCommit() })
        }
    }

    private func dot(_ diameter: CGFloat) -> some View {
        Circle()
            .fill(Self.fill)
            .frame(width: diameter / scale, height: diameter / scale)
            .overlay(Circle().strokeBorder(Self.edge, lineWidth: 2 / scale))
            .frame(width: Self.touch / scale, height: Self.touch / scale)
            .contentShape(.circle)
    }
}
