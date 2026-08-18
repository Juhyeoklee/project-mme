// 캔버스 문서 — `11`이 고치고 기록이 들고 저장소가 적는 값.

import CoreGraphics
import Foundation

/// 캔버스 기록의 알맹이.
///
/// **이것이 있으면 캔버스 기록이다** — 기록에 종류 필드를 두지 않는다. `08`의 `수정`이 어디로
/// 가는지도, `07-C4`가 무엇을 그리는지도 이 값의 유무 하나로 갈린다.
///
/// ⚠️ **페이지 0장인 문서를 만들지 마라.** 저장하면 이미지 0장짜리 기록이 되고, 그런 기록은
/// `07`·`08`이 그릴 것을 못 찾는다.
///
/// ⚠️ **획이 페이지 안이 아니라 여기 따로 산다.** 요소는 이 앱의 되돌리기 스택이 되돌리고
/// 획은 PencilKit이 자기 스택으로 되돌리는데, 한 값에 묶으면 요소를 되돌릴 때 획이 함께
/// 딸려간다 (`CAN-07`).
struct CanvasDocument: Hashable, Sendable {
    var pages: [CanvasPage]
    /// 페이지 `id` → `PKDrawing` 바이트. 아직 안 그린 페이지는 자리가 없다.
    var strokes: [UUID: Data]
    /// 꾸미기의 재료가 된 사진 (`CAN-09`). ⚠️ **비워 두고 저장하면 다음에 열었을 때 놓인
    /// 사진이 전부 빈칸이 된다** — 요소의 `imageID`가 이 목록의 `id`다.
    var sources: [RecordImage]

    init(pages: [CanvasPage], strokes: [UUID: Data] = [:], sources: [RecordImage] = []) {
        self.pages = pages
        self.strokes = strokes
        self.sources = sources
    }
}

/// 페이지 한 장. **한 장이 그대로 이미지 한 장이 된다** (`CAN-09`).
///
/// **그리는 순서는 아래부터 `[맨 뒤로] · 사진 · 글 · 획 · [맨 앞으로]`다.** 손대지 않으면
/// 종류가 정하고, 같은 층 안에서는 넣은 순서대로 쌓인다.
///
/// ⚠️ **획의 자리는 저장되는 값이 아니라 경계다** — 두 무리 사이 한 자리에 늘 있고, 요소가
/// 어느 쪽에 서느냐만 값으로 남는다.
///
/// ⚠️ **획은 한 덩어리라 그 경계가 하나뿐이다.** 획끼리 사이에 요소를 끼울 수 없다 —
/// 그러려면 획을 낱개 요소로 세워야 하는데, 그러면 지우개가 층을 못 건넌다
/// (`PKCanvasView`는 페이지당 그림 하나를 진다).
struct CanvasPage: Identifiable, Hashable, Sendable {
    let id: UUID
    var paper: PaperKind
    /// **배열 순서가 곧 겹침 순서다** — 뒤에 있는 것이 위에 그려진다 (`CAN-06`).
    var elements: [CanvasElement]

    init(id: UUID = UUID(), paper: PaperKind = .dots, elements: [CanvasElement] = []) {
        self.id = id
        self.paper = paper
        self.elements = elements
    }

    /// 획 아래에 깔리는 요소들과 그 위에 얹히는 요소들.
    var underStrokes: [CanvasElement] { ordered.filter { !$0.isOverStrokes } }
    var overStrokes: [CanvasElement] { ordered.filter(\.isOverStrokes) }

    /// ⚠️ **넣은 순서가 같은 층 안의 순서다** — 층으로만 정렬하면 같은 종류끼리의 앞뒤가
    /// 정렬할 때마다 흔들린다.
    private var ordered: [CanvasElement] {
        elements.enumerated()
            .sorted { ($0.element.stack, $0.offset) < ($1.element.stack, $1.offset) }
            .map(\.element)
    }
}

/// 캔버스에 놓인 것 하나.
///
/// ⚠️ **요소는 넷까지만 는다** — 사진 · 이미지 · 텍스트 · 그림(`PRD` 요구 `CAN-02`~`CAN-05`).
/// 다섯째를 더하려는 자리가 오면 그건 요구 개정이지 구현 결정이 아니다.
struct CanvasElement: Identifiable, Hashable, Sendable {
    let id: UUID
    var content: Content
    /// 캔버스 좌표(920×690)에서의 자리. **회전 전 기준이다.**
    var frame: CGRect
    /// 도 단위 (`CAN-02`).
    var rotation: Double
    /// 사용자가 직접 정한 자리. **`nil`이면 종류가 정한다** (`CAN-06`).
    /// ⚠️ **앱은 이 값을 안 건드린다** — 손으로 정리해 둔 배치가 무너진다(사용자 판정 2026-08-18).
    var pinned: Pin?

    init(id: UUID = UUID(), content: Content, frame: CGRect, rotation: Double = 0,
         pinned: Pin? = nil) {
        self.id = id
        self.content = content
        self.frame = frame
        self.rotation = rotation
        self.pinned = pinned
    }

    /// 사용자가 못 박은 자리 — 맨 앞(획보다도 위)과 맨 뒤(전부보다 아래).
    enum Pin: String, Hashable, Sendable {
        case front
        case back
    }

    /// 겹침 순서의 층. **작을수록 아래고, 획은 2와 3 사이에 있다.**
    var stack: Int {
        switch pinned {
        case .back: 0
        case .front: 3
        case nil: text == nil ? 1 : 2
        }
    }

    /// 획보다 위에 그려지는가.
    var isOverStrokes: Bool { pinned == .front }

    enum Content: Hashable, Sendable {
        /// 이 기록에 든 이미지. ⚠️ **바이트가 아니라 `id`다** — 같은 사진을 두 번 놓아도
        /// 바이트는 한 벌이고, 저장 전 `DraftPhoto`와 저장 뒤 `RecordImage`가 같은 값을 쓴다.
        case photo(imageID: UUID)
        /// 캔버스에 쓴 글 (`CAN-04`).
        case text(CanvasText)
    }

    var imageID: UUID? {
        if case .photo(let imageID) = content { return imageID }
        return nil
    }

    var text: CanvasText? {
        if case .text(let text) = content { return text }
        return nil
    }
}

/// 캔버스에 쓴 글 한 덩이 (`CAN-04`).
///
/// ⚠️ **크기에 하한이 없다.** 사진 구석의 작은 주석도 정당한 쓰임이라 앱이 막지 않는다 —
/// 대신 기본값이 정책을 한다. 작게 쓴 글이 흐려지는 것은 굽는 배율이 갚는다.
struct CanvasText: Hashable, Sendable {
    var string: String
    var face: Face
    /// ⚠️ **손글씨에서는 이 값이 아무 일도 안 한다** — 그 서체는 굵기가 1단이다.
    var isBold: Bool
    var size: CGFloat
    var ink: InkColor

    /// 글꼴 2종. **역할 이름이지 서체 이름이 아니다** — 사용자가 알아야 할 것은 역할이다.
    enum Face: String, Hashable, Sendable, CaseIterable {
        case handwriting
        case serif

        /// 굵기를 고를 수 있는가.
        var hasWeights: Bool { self == .serif }

        /// 그 글꼴에서 처음 서는 크기.
        var defaultSize: CGFloat { self == .handwriting ? 24 : 17 }
    }

    /// `11-I3` 컨트롤의 범위. **하한 강제가 아니라 위젯 경계다** — 10 아래를 막는 규칙이 아니라
    /// 슬라이더가 다룰 수 있는 폭이다.
    static let sizeRange: ClosedRange<CGFloat> = 10...120

    init(face: Face = .handwriting, ink: InkColor = .sumi) {
        self.string = ""
        self.face = face
        self.isBold = false
        self.size = face.defaultSize
        self.ink = ink
    }
}

/// 캔버스 잉크 8색. **글자색과 펜색이 같은 목록을 쓴다** — 일기장에서 잉크는 하나다.
///
/// ⚠️ **강조색(테라코타)이 목록에 없다.** 캔버스 표면은 사용자 색의 영역이고 앱 색은 도구
/// 활성 표시에만 남는다 — 넣으면 그 경계가 사라진다.
enum InkColor: String, CaseIterable, Hashable, Sendable {
    case sumi
    case pencil
    case red
    case orange
    case yellow
    case green
    case navy
    case white
}

/// 종이 4종 (`CAN-08`). **색과 패턴이 고정 페어링**이라 고르는 축이 하나다.
enum PaperKind: String, CaseIterable, Hashable, Sendable {
    case grid
    case dots
    case lines
    case plain
}
