// `11-C5` 그리기 층 — PencilKit이 획을 받는 자리.
//
// ⚠️ **되돌리기 매니저를 캔버스와 공유한다.** 안 하면 스택이 둘이 되고, `11-N2` 버튼 하나가
// 어느 쪽을 되돌리는지 사용자가 못 고른다.

import PencilKit
import SwiftUI

/// 종이 위에 겹쳐 놓는 투명한 획 층.
///
/// **손가락도 그린다** (사용자 판정 2026-08-18). 시스템 기본값(`.default`)은 펜슬이 붙은
/// 기기에서 펜슬만 받는데, 그러면 펜슬을 안 든 순간 그리기가 통째로 막힌다.
///
/// ⚠️ **그 대가로 손가락 한 개짜리 이동이 사라진다** — 캔버스를 옮기고 크기를 바꾸려면
/// `선택` 도구로 가야 한다. 두 손가락 핀치는 두 모드에서 다 산다.
struct DrawingLayer: UIViewRepresentable {
    let session: CanvasSession
    let tool: CanvasTool
    let ink: InkColor
    let width: CGFloat
    /// 마커 진하기 (`11-O1`). 다른 도구는 안 본다.
    let opacity: Double

    func makeUIView(context: Context) -> PKCanvasView {
        let view = IsolatedUndoCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.drawingPolicy = .anyInput
        view.delegate = context.coordinator
        context.coordinator.load(session.strokes, into: view, page: session.page.id,
                                 revision: session.strokesRevision)
        view.tool = Self.pencilTool(tool, ink: ink, width: width, opacity: opacity)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.load(session.strokes, into: view, page: session.page.id,
                                 revision: session.strokesRevision)
        view.tool = Self.pencilTool(tool, ink: ink, width: width, opacity: opacity)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    private static func pencilTool(_ tool: CanvasTool, ink: InkColor,
                                   width: CGFloat, opacity: Double) -> PKTool {
        switch tool {
        // ⚠️ **마커는 반투명이다** — 불투명하면 겹쳐 그었을 때 아래 글자가 지워진 것처럼 된다.
        case .marker: PKInkingTool(.marker, color: UIColor(ink.markerColor(opacity)), width: width)
        case .eraser: PKEraserTool(.bitmap, width: width)
        default: PKInkingTool(.pen, color: UIColor(ink.color), width: width)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let session: CanvasSession
        /// 지금 뷰에 올려둔 것 — 페이지와 그 획의 판.
        private var shown: (page: UUID, revision: Int)?
        /// ⚠️ **문서에서 그림을 넣는 동안은 델리게이트를 무시한다** — 안 그러면 페이지를
        /// 넘길 때마다 방금 넣은 그림이 다시 저장돼 되돌리기가 한 칸씩 밀린다.
        private var isLoading = false

        init(session: CanvasSession) {
            self.session = session
        }

        /// ⚠️ **판이 오르면 페이지가 같아도 다시 읽는다** — 되돌리기가 문서의 획을 바꿔도
        /// 화면은 손이 만든 변화만 알고 있어서, 안 읽으면 지운 획이 화면에 남는다.
        func load(_ strokes: Data?, into view: PKCanvasView, page: UUID, revision: Int) {
            guard shown?.page != page || shown?.revision != revision else { return }
            let sameStrokes = shown?.page == page
                && view.drawing.dataRepresentation() == strokes
            shown = (page, revision)
            guard !sameStrokes else { return }
            isLoading = true
            view.drawing = (strokes.flatMap { try? PKDrawing(data: $0) }) ?? PKDrawing()
            isLoading = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isLoading, let page = shown?.page else { return }
            session.setStrokes(canvasView.drawing.dataRepresentation(), page: page)
            shown = (page, session.strokesRevision)
        }
    }
}

/// 손을 안 받는 획 그림 — 결과를 보여주는 자리가 쓴다(`CAN-09` 굽기).
///
/// ⚠️ **화면의 그리기 층과 겸하지 않는다.** 저쪽은 손을 받아야 해서 `PKCanvasView`가 필요하고,
/// 이쪽은 비트맵 한 장이면 된다 — 겸하면 결과를 그리는 자리마다 편집 가능한 뷰가 선다.
struct StrokeImage: View {
    let strokes: Data
    /// 비트맵을 뜨는 배율. 굽는 배율과 같아야 획만 흐려지지 않는다.
    let scale: CGFloat

    var body: some View {
        if let drawing = try? PKDrawing(data: strokes) {
            Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: Layout.canvasSize),
                                         scale: scale))
                .resizable()
                .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height)
        }
    }
}

/// 자기 되돌리기를 앱 스택에 안 흘리는 캔버스.
///
/// ⚠️ **PencilKit의 되돌리기는 그림이 아니라 이 뷰에 걸린다.** 페이지를 넘기면 같은 뷰에
/// 다른 그림이 올라가므로, 그 스택을 앱 버튼에 물리면 **되돌리기가 이전 페이지의 그림을
/// 지금 페이지에 써 넣는다**(2026-08-18 실기기). 획의 되돌리기는 `CanvasSession`이 진다.
private final class IsolatedUndoCanvasView: PKCanvasView {
    private let isolated = UndoManager()

    override var undoManager: UndoManager? { isolated }
}
