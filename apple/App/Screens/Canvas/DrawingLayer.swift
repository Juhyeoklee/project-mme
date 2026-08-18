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

    func makeUIView(context: Context) -> PKCanvasView {
        let view = SharedUndoCanvasView()
        view.sharedUndoManager = session.undoManager
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.drawingPolicy = .anyInput
        view.delegate = context.coordinator
        context.coordinator.load(session.strokes, into: view, page: session.page.id)
        view.tool = Self.pencilTool(tool, ink: ink)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.load(session.strokes, into: view, page: session.page.id)
        view.tool = Self.pencilTool(tool, ink: ink)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    /// 굵기 기본값은 도구마다 다르다 — 펜은 가늘고 마커는 두껍다.
    private static func pencilTool(_ tool: CanvasTool, ink: InkColor) -> PKTool {
        switch tool {
        case .pen: PKInkingTool(.pen, color: UIColor(ink.color), width: 3)
        case .marker: PKInkingTool(.marker, color: UIColor(ink.color), width: 24)
        case .eraser: PKEraserTool(.bitmap, width: 24)
        default: PKInkingTool(.pen, color: UIColor(ink.color), width: 3)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let session: CanvasSession
        private var shownPage: UUID?
        /// ⚠️ **문서에서 그림을 넣는 동안은 델리게이트를 무시한다** — 안 그러면 페이지를
        /// 넘길 때마다 방금 넣은 그림이 다시 저장돼 되돌리기가 한 칸씩 밀린다.
        private var isLoading = false

        init(session: CanvasSession) {
            self.session = session
        }

        func load(_ strokes: Data?, into view: PKCanvasView, page: UUID) {
            guard shownPage != page else { return }
            shownPage = page
            isLoading = true
            view.drawing = (strokes.flatMap { try? PKDrawing(data: $0) }) ?? PKDrawing()
            isLoading = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isLoading, let page = shownPage else { return }
            session.setStrokes(canvasView.drawing.dataRepresentation(), page: page)
        }
    }
}

/// 되돌리기를 바깥 매니저에 등록하게 만드는 캔버스.
///
/// ⚠️ **`undoManager`는 응답자 사슬에서 찾아온다** — 이 프로퍼티를 안 덮으면 PencilKit이
/// 자기 창의 매니저에 등록하고, 그러면 요소 변경과 획이 서로 다른 스택에 쌓인다.
private final class SharedUndoCanvasView: PKCanvasView {
    var sharedUndoManager: UndoManager?

    override var undoManager: UndoManager? { sharedUndoManager }
}
