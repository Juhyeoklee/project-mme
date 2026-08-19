// 캔버스를 화면에 놓는 변환의 명세 — 손가락 아래가 안 움직이는가, 상한에서 안 미끄러지는가.

import CoreGraphics
import Testing
@testable import Moanogi

/// 배율·각도가 바뀐 뒤에도 그 점이 화면에서 제자리인가.
/// 화면 자리 = 이동 + 「중심에서 떨어진 만큼」이므로 둘을 더해 본다.
private func screenPlace(_ viewport: CanvasViewport, _ point: CGPoint,
                         scale: CGFloat) -> CGPoint {
    let arm = viewport.place(point, scale: scale)
    return CGPoint(x: viewport.pan.width + arm.x, y: viewport.pan.height + arm.y)
}

/// 문서 좌표에서, 화면상 `touch`에 놓여 있는 점을 되찾는다.
private func documentPoint(under touch: CGPoint, in viewport: CanvasViewport,
                           scale: CGFloat) -> CGPoint {
    let drawn = scale * viewport.zoom
    let armX = touch.x - viewport.pan.width, armY = touch.y - viewport.pan.height
    let (c, s) = (cos(-viewport.angle), sin(-viewport.angle))
    return CGPoint(x: (armX * c - armY * s) / drawn + Layout.canvasSize.width / 2,
                   y: (armX * s + armY * c) / drawn + Layout.canvasSize.height / 2)
}

@Suite("캔버스 변환")
struct CanvasViewportTests {

    @Test func 확대해도_손가락_아래는_제자리다() {
        var viewport = CanvasViewport()
        let touch = CGPoint(x: 120, y: -80)
        let held = documentPoint(under: touch, in: viewport, scale: 1)

        viewport.magnify(by: 2.5, around: touch, within: Layout.canvasZoomRange)

        let after = screenPlace(viewport, held, scale: 1)
        #expect(abs(after.x - touch.x) < 0.001)
        #expect(abs(after.y - touch.y) < 0.001)
    }

    @Test func 돌려도_손가락_아래는_제자리다() {
        var viewport = CanvasViewport()
        let touch = CGPoint(x: -90, y: 140)
        let held = documentPoint(under: touch, in: viewport, scale: 1)

        viewport.turn(by: 0.6, around: touch)

        let after = screenPlace(viewport, held, scale: 1)
        #expect(abs(after.x - touch.x) < 0.001)
        #expect(abs(after.y - touch.y) < 0.001)
    }

    /// ⚠️ **상한에 걸린 뒤로는 캔버스가 미끄러지면 안 된다** — 배율이 안 변했는데 이동만
    /// 보정하면 손가락을 계속 벌릴 때마다 그림이 밀려난다.
    @Test func 상한에_걸리면_이동도_멈춘다() {
        var viewport = CanvasViewport()
        let touch = CGPoint(x: 200, y: 60)
        viewport.magnify(by: 100, around: touch, within: Layout.canvasZoomRange)

        #expect(viewport.zoom == Layout.canvasZoomRange.upperBound)
        let parked = viewport.pan
        viewport.magnify(by: 3, around: touch, within: Layout.canvasZoomRange)
        #expect(viewport.zoom == Layout.canvasZoomRange.upperBound)
        #expect(viewport.pan == parked)
    }

    @Test func 하한도_같다() {
        var viewport = CanvasViewport()
        let touch = CGPoint(x: -40, y: -150)
        viewport.magnify(by: 0.01, around: touch, within: Layout.canvasZoomRange)

        #expect(viewport.zoom == Layout.canvasZoomRange.lowerBound)
        let parked = viewport.pan
        viewport.magnify(by: 0.5, around: touch, within: Layout.canvasZoomRange)
        #expect(viewport.pan == parked)
    }

    /// 화면 맞춤은 셋을 함께 되돌린다 — 하나라도 남으면 「돌아왔다」가 거짓이 된다.
    @Test func 화면맞춤이_셋을_함께_되돌린다() {
        var viewport = CanvasViewport()
        viewport.magnify(by: 2, around: CGPoint(x: 30, y: 30), within: Layout.canvasZoomRange)
        viewport.turn(by: 0.4, around: CGPoint(x: 30, y: 30))
        viewport.pan = CGSize(width: 300, height: -120)

        viewport.fitToScreen()

        #expect(viewport == CanvasViewport())
    }

    /// ⚠️ **`place`가 각도를 봐야 한다** — 안 보면 키보드 회피가 돌려놓은 캔버스에서 어긋난다.
    @Test func 자리는_각도를_따라_돈다() {
        var turned = CanvasViewport()
        turned.turn(by: .pi / 2, around: .zero)

        let bottom = CGPoint(x: Layout.canvasSize.width / 2, y: Layout.canvasSize.height)
        let flat = CanvasViewport().place(bottom, scale: 1)
        let spun = turned.place(bottom, scale: 1)

        // ⚠️ 화면 좌표는 y가 아래로 향한다 — 아래로 뻗은 팔이 +90도 돌면 **왼쪽**이다.
        #expect(abs(flat.x) < 0.001)
        #expect(flat.y > 0)
        #expect(abs(spun.x + flat.y) < 0.001)
        #expect(abs(spun.y) < 0.001)
    }
}
