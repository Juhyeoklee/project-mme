// 종이에 남는 손잡이의 명세 — 밀어내도 짚을 자리가 남는가.

import CoreGraphics
import Foundation
import Testing
@testable import Moanogi

@Suite("캔버스 손잡이")
struct CanvasGripTests {
    private let paper = Layout.canvasSize
    private let photo = CGSize(width: 400, height: 300)

    @Test func 왼쪽으로_아무리_밀어도_손잡이가_남는다() {
        let kept = LiveTransform.kept(CGRect(origin: CGPoint(x: -5000, y: 100), size: photo))
        #expect(kept.maxX == LiveTransform.grip)
    }

    @Test func 오른쪽도_같다() {
        let kept = LiveTransform.kept(CGRect(origin: CGPoint(x: 5000, y: 100), size: photo))
        #expect(kept.minX == paper.width - LiveTransform.grip)
    }

    @Test func 위아래도_같다() {
        let up = LiveTransform.kept(CGRect(origin: CGPoint(x: 100, y: -5000), size: photo))
        let down = LiveTransform.kept(CGRect(origin: CGPoint(x: 100, y: 5000), size: photo))
        #expect(up.maxY == LiveTransform.grip)
        #expect(down.minY == paper.height - LiveTransform.grip)
    }

    @Test func 종이_안에_있으면_안_건드린다() {
        let inside = CGRect(origin: CGPoint(x: 200, y: 150), size: photo)
        #expect(LiveTransform.kept(inside) == inside)
    }

    /// 가장자리로 흘려보내는 배치가 살아 있어야 한다 — 막는 것은 「완전히 나가는 것」뿐이다.
    @Test func 거의_다_나가는_것은_허용한다() {
        let bleeding = CGRect(origin: CGPoint(x: -(photo.width - LiveTransform.grip - 1), y: 150),
                              size: photo)
        #expect(LiveTransform.kept(bleeding) == bleeding)
    }

    /// ⚠️ 손잡이보다 작은 요소는 손잡이가 자기 크기다 — 안 그러면 가장자리에 닿지도 못한다.
    @Test func 손잡이보다_작으면_통째로_붙든다() {
        let tiny = CGSize(width: 20, height: 20)
        let kept = LiveTransform.kept(CGRect(origin: CGPoint(x: -5000, y: -5000), size: tiny))
        #expect(kept.origin == .zero)
    }

    // MARK: - 자리를 내는 셋이 전부 지나는가

    /// 끝까지 밀어 손잡이만 남은 요소에 **새로 손을 댄 상태.**
    ///
    /// ⚠️ **`.moved()`를 이어 붙이면 안 된다** — `resized`·`scaled`는 `frame`이 아니라
    /// **손대기 직전 값(`origin`)에서 다시 계산**하고 `moved`는 그 값을 안 건드린다.
    /// 이어 붙이면 클램프가 손댈 것이 없어 **테스트가 공허하게 통과한다**(리뷰 2026-08-19).
    /// 실물에서는 커밋이 그 자리를 문서에 앉히고, 다음 손짓이 거기서 새로 시작한다.
    private func gripping(_ grip: LiveTransform.Grip) -> LiveTransform {
        let pushed = LiveTransform.kept(CGRect(x: -5000, y: 0, width: 400, height: 300))
        return LiveTransform(CanvasElement(content: .photo(imageID: UUID()), frame: pushed),
                             grip: grip)
    }

    @Test func 끌어낸_뒤_모서리로_줄여도_안_사라진다() {
        let shrunk = gripping(.handle).resized(corner: .topTrailing,
                                               by: CGSize(width: -5000, height: 0))
        #expect(shrunk.frame.maxX >= min(LiveTransform.grip, shrunk.frame.width))
    }

    @Test func 끌어낸_뒤_핀치로_줄여도_안_사라진다() {
        let shrunk = gripping(.pinch).scaled(by: 0.1, turnedBy: 0)
        #expect(shrunk.frame.maxX >= min(LiveTransform.grip, shrunk.frame.width))
    }
}
