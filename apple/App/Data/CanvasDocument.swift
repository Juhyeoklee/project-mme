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

    init(pages: [CanvasPage], strokes: [UUID: Data] = [:]) {
        self.pages = pages
        self.strokes = strokes
    }
}

/// 페이지 한 장. **한 장이 그대로 이미지 한 장이 된다** (`CAN-09`).
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

    init(id: UUID = UUID(), content: Content, frame: CGRect, rotation: Double = 0) {
        self.id = id
        self.content = content
        self.frame = frame
        self.rotation = rotation
    }

    enum Content: Hashable, Sendable {
        /// 이 기록에 든 이미지. ⚠️ **바이트가 아니라 `id`다** — 같은 사진을 두 번 놓아도
        /// 바이트는 한 벌이고, 저장 전 `DraftPhoto`와 저장 뒤 `RecordImage`가 같은 값을 쓴다.
        case photo(imageID: UUID)
    }

    var imageID: UUID? {
        if case .photo(let imageID) = content { return imageID }
        return nil
    }
}

/// 종이 4종 (`CAN-08`). **색과 패턴이 고정 페어링**이라 고르는 축이 하나다.
enum PaperKind: String, CaseIterable, Hashable, Sendable {
    case grid
    case dots
    case lines
    case plain
}
