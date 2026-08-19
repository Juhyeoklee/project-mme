// `11`의 두 손가락 변환 — 이동 · 배율 · 각도. 한 손짓의 세 성분이라 한 좌표계에서 합성한다.

import SwiftUI
import UIKit

/// 두 손가락 끌기.
///
/// ⚠️ **증분으로만 말한다** — 시작점 기준의 절대값을 쓰면 기준이 흔들릴 때(뷰가 밀리거나
/// 인식기가 다시 만들어질 때) 되먹임 진동이 난다.
struct CanvasPan: UIGestureRecognizerRepresentable {
    /// ⚠️ **끄는 조건을 인식기가 진다** — `gesture(_:)`가 이 프로토콜에 주는 오버로드는
    /// 하나뿐이라 `GestureMask`도 `isEnabled`도 밖에서 못 건다.
    let isEnabled: Bool
    let onChanged: (CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> CanvasGestureDelegate {
        CanvasGestureDelegate()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .changed else { return }
        let space = recognizer.view?.window
        let moved = recognizer.translation(in: space)
        recognizer.setTranslation(.zero, in: space)
        onChanged(CGSize(width: moved.x, height: moved.y))
    }
}

/// 두 손가락 핀치.
///
/// ★ **배율과 함께 손가락 중심을 준다.** 그 점을 고정해야 손가락 간격의 잡음(실측 0.45%)이
/// 화면에서 안 보인다 — SwiftUI `MagnifyGesture`는 이 점을 안 줘서 여기로 내려왔다.
struct CanvasPinch: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    /// 캔버스가 인식기 뷰 안에서 왼쪽으로 밀린 양. 페이지 레일이 그만큼 차지한다.
    let leadingInset: CGFloat
    /// 배율 증분과, **캔버스 중심을 원점으로 한** 손가락 중심.
    let onChanged: (CGFloat, CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> CanvasGestureDelegate {
        CanvasGestureDelegate()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let recognizer = UIPinchGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        guard recognizer.state == .changed, let view = recognizer.view else { return }
        let factor = recognizer.scale
        recognizer.scale = 1
        onChanged(factor, CanvasGestureDelegate.centered(recognizer.location(in: view),
                                                        in: view, leadingInset: leadingInset))
    }
}

/// 위 셋이 저마다 하나씩 만들어 다는 델리게이트. **무상태라 인스턴스가 갈려도 결과가 같다.**
///
/// ⚠️ **동시 인식을 허용하지 않으면 끌기가 한 번도 발화하지 않는다** — 같은 자리에 핀치와
/// PencilKit이 서 있어서 두 손가락이 닿는 순간 중재에서 진다 (2026-08-18 실기기).
final class CanvasGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer)
    -> Bool { true }

    /// 손가락 중심을 **캔버스 중심이 원점인 좌표**로 옮긴다.
    /// ⚠️ 핀치와 회전이 **같은 원점**을 써야 한다 — 다르면 두 변환이 서로를 밀어낸다.
    static func centered(_ touch: CGPoint, in view: UIView, leadingInset: CGFloat) -> CGPoint {
        CGPoint(x: touch.x - (leadingInset + (view.bounds.width - leadingInset) / 2),
                y: touch.y - view.bounds.height / 2)
    }
}

/// 두 손가락 회전.
///
/// **보는 각도만 돌린다** — 문서도 굽는 결과도 안 바뀐다 (사용자 판정 2026-08-19).
struct CanvasRotate: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let leadingInset: CGFloat
    /// 각도 증분(라디안)과, **캔버스 중심을 원점으로 한** 손가락 중심.
    let onChanged: (CGFloat, CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> CanvasGestureDelegate {
        CanvasGestureDelegate()
    }

    func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        let recognizer = UIRotationGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer,
                                         context: Context) {
        guard recognizer.state == .changed, let view = recognizer.view else { return }
        let turned = recognizer.rotation
        recognizer.rotation = 0
        onChanged(turned, CanvasGestureDelegate.centered(recognizer.location(in: view),
                                                         in: view, leadingInset: leadingInset))
    }
}

/// 캔버스를 화면에 놓는 변환. **순수 계산이라 테스트가 닿는다.**
///
/// ⚠️ **셋이 같은 원점(손가락 중심)을 공유한다** — 따로 걸면 서로를 흔든다.
struct CanvasViewport: Equatable {
    private(set) var zoom: CGFloat = 1
    private(set) var angle: CGFloat = 0
    /// 키보드 회피가 직접 앉히는 자리라 밖에서도 쓴다.
    var pan: CGSize = .zero

    /// 손가락 중심을 붙들어 둔 채 배율을 바꾼다.
    /// ⚠️ **보정에 쓰는 값은 요청한 배율이 아니라 실제로 적용된 배율이다** — 상한에 걸리면
    /// 배율은 안 변하는데 이동만 보정돼 캔버스가 미끄러진다.
    mutating func magnify(by factor: CGFloat, around touch: CGPoint,
                          within range: ClosedRange<CGFloat>) {
        let next = min(max(zoom * factor, range.lowerBound), range.upperBound)
        let applied = next / zoom
        guard applied != 1 else { return }
        zoom = next
        pan = CGSize(width: touch.x - (touch.x - pan.width) * applied,
                     height: touch.y - (touch.y - pan.height) * applied)
    }

    /// 배율과 **같은 자리를 붙들고** 각도를 바꾼다.
    mutating func turn(by delta: CGFloat, around touch: CGPoint) {
        angle += delta
        let arm = CGPoint(x: pan.width - touch.x, y: pan.height - touch.y)
        let (c, s) = (cos(delta), sin(delta))
        pan = CGSize(width: touch.x + arm.x * c - arm.y * s,
                     height: touch.y + arm.x * s + arm.y * c)
    }

    mutating func fitToScreen() {
        zoom = 1
        angle = 0
        pan = .zero
    }

    /// 문서 좌표의 한 점이 **캔버스 중심에서 얼마나 떨어져 그려지는가**. 이동은 안 더한다.
    /// ⚠️ 점 하나만 본다 — 상자를 크게 돌리면 실제 최저점은 모서리라 **덜 가려진 쪽으로 틀린다.**
    func place(_ point: CGPoint, scale: CGFloat) -> CGPoint {
        let drawn = scale * zoom
        let armX = (point.x - Layout.canvasSize.width / 2) * drawn
        let armY = (point.y - Layout.canvasSize.height / 2) * drawn
        let (c, s) = (cos(angle), sin(angle))
        return CGPoint(x: armX * c - armY * s, y: armX * s + armY * c)
    }
}
