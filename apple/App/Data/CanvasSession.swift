// 편집 중인 캔버스. `11`이 보는 상태 전부와 저장이 여기서 돈다.
//
// ⚠️ 이 객체의 수명은 화면이 아니라 **작업**이다 — `09`에서 승격해 `08`에 도착할 때까지 산다.

import Foundation

/// `11`이 고치고 있는 캔버스 하나.
///
/// **초안(`RecordDraft`)과 짝으로 산다** — 사진의 출처·발생일시·설명은 여전히 초안의 것이고
/// 캔버스는 그 사진을 어디에 놓았는지만 안다. 저장도 초안이 지므로 여기서 바이트를 안 만진다.
///
/// ⚠️ **되돌리기 스택은 캔버스 하나에 하나다** (`CAN-07`). 요소 변경은 `change(_:)`가 등록하고
/// 획은 PencilKit이 같은 `UndoManager`에 등록한다 — 스택을 둘로 두면 `11-N2` 버튼 하나가
/// 어느 쪽을 되돌리는지 사용자가 못 고른다.
@MainActor
@Observable
final class CanvasSession: Identifiable {
    /// 어디서 들어왔나. `11-N1 취소`의 갈래를 이것이 정한다.
    enum Entry: Equatable {
        /// `09`에서 승격했다.
        case promotion
        /// 저장된 캔버스 기록을 고치러 들어왔다 (`ARC-06`).
        case editingRecord
    }

    let id = UUID()
    let draft: RecordDraft
    let entry: Entry

    private(set) var document: CanvasDocument
    /// 지금 보고 있는 페이지. **항상 정확히 하나**라 옵셔널이 아니다.
    var pageIndex: Int
    private(set) var canUndo = false
    private(set) var canRedo = false

    /// **획도 이 매니저에 등록된다** — 그리기 층이 이것을 받아 쓴다.
    @ObservationIgnored let undoManager = UndoManager()

    init(draft: RecordDraft, entry: Entry, document: CanvasDocument) {
        self.draft = draft
        self.entry = entry
        self.document = document
        self.pageIndex = 0
    }

    // MARK: - 화면이 보는 것

    var page: CanvasPage { document.pages[min(pageIndex, document.pages.count - 1)] }

    var strokes: Data? { document.strokes[page.id] }

    /// 마지막 한 장은 지울 수 없다 — 페이지 0장인 캔버스는 없다.
    var canDeletePage: Bool { document.pages.count > 1 }

    func element(_ id: UUID) -> CanvasElement? {
        page.elements.first { $0.id == id }
    }

    // MARK: - 고치기

    /// 되돌릴 수 있게 페이지를 바꾼다. **획은 여기 안 든다** — 그쪽은 PencilKit이 되돌린다.
    func change(_ body: (inout [CanvasPage]) -> Void) {
        // ⚠️ **사본을 고쳐서 되쓴다** — `&document.pages`를 그대로 넘기면 문서가 잠긴 채로
        // 클로저가 돌고, 그 안에서 문서를 읽는 순간 프로세스가 죽는다(2026-08-18 실물).
        let before = document.pages
        var pages = before
        body(&pages)
        guard before != pages else { return }
        document.pages = pages
        undoManager.registerUndo(withTarget: self) { session in
            session.change { $0 = before }
        }
        refreshUndoState()
    }

    /// PencilKit이 획을 바꿨다. ⚠️ **되돌리기를 등록하지 않는다** — PencilKit이 같은 매니저에
    /// 이미 등록했고, 여기서 또 등록하면 한 획이 두 번 되돌아간다.
    func setStrokes(_ data: Data, page id: UUID) {
        document.strokes[id] = data
        refreshUndoState()
    }

    /// 되돌릴 것을 비운다. ⚠️ **거울 값도 함께 지운다** — `removeAllActions()`만 부르면
    /// `11-N2`가 켜진 채로 남아 승격 직후와 저장 직후에 누를 것이 없는 버튼이 활성으로 선다.
    func clearHistory() {
        undoManager.removeAllActions()
        refreshUndoState()
    }

    func undoChange() {
        undoManager.undo()
        refreshUndoState()
    }

    func redoChange() {
        undoManager.redo()
        refreshUndoState()
    }

    // MARK: - 페이지

    /// 새 페이지를 끝에 더하고 그리로 옮긴다 (`11-P2`).
    func addPage() {
        change { $0.append(CanvasPage(paper: page.paper)) }
        pageIndex = document.pages.count - 1
    }

    func deletePage(_ id: UUID) {
        guard canDeletePage else { return }
        change { $0.removeAll { $0.id == id } }
        pageIndex = min(pageIndex, document.pages.count - 1)
    }

    // MARK: - 요소

    /// 사진 한 장을 지금 페이지에 놓는다. **맨 위에 온다.**
    func place(imageID: UUID, at center: CGPoint, fitting box: CGSize) {
        let size = fitted(imageID, in: box)
        let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                           width: size.width, height: size.height)
        let element = CanvasElement(content: .photo(imageID: imageID), frame: frame,
                                    rotation: Self.tilt(seed: imageID))
        change { $0[pageIndex].elements.append(element) }
    }

    func update(_ id: UUID, frame: CGRect, rotation: Double) {
        change {
            guard let index = $0[pageIndex].elements.firstIndex(where: { $0.id == id }) else { return }
            $0[pageIndex].elements[index].frame = frame
            $0[pageIndex].elements[index].rotation = rotation
        }
    }

    func remove(_ id: UUID) {
        change { $0[pageIndex].elements.removeAll { $0.id == id } }
    }

    /// `CAN-06` — 배열 순서가 겹침 순서라 자리를 옮기는 것이 곧 층을 옮기는 것이다.
    func move(_ id: UUID, toFront: Bool) {
        change {
            guard let index = $0[pageIndex].elements.firstIndex(where: { $0.id == id }) else { return }
            let element = $0[pageIndex].elements.remove(at: index)
            $0[pageIndex].elements.insert(element, at: toFront ? $0[pageIndex].elements.count : 0)
        }
    }

    /// 원본 비율을 지키며 상자 안에 넣는다. 상자는 채우는 크기가 아니라 상한이다.
    private func fitted(_ imageID: UUID, in box: CGSize) -> CGSize {
        // ⚠️ 크기를 모르는 사진은 상자를 그대로 쓴다 — 그때만 채워 넣느라 잘린다.
        guard let photo = draft.photos.first(where: { $0.id == imageID }),
              let pixels = photo.pixelSize else { return box }
        let ratio = min(box.width / pixels.width, box.height / pixels.height)
        return CGSize(width: pixels.width * ratio, height: pixels.height * ratio)
    }

    /// 어느 사진이 몇 번 놓였나 — `11-O3` 서랍의 수량 배지.
    func placedCount(imageID: UUID) -> Int {
        document.pages.reduce(0) { count, page in
            count + page.elements.filter { $0.imageID == imageID }.count
        }
    }

    // MARK: - 저장

    /// 캔버스를 기록으로 저장한다. 성공하면 그 기록, 실패하면 `nil`이고 초안이 실패를 든다.
    func save(status: Record.Status, to store: RecordStore,
              bytes: @escaping OriginalBytesLoader) async -> Record? {
        draft.setCanvas(pruned())
        let saved = await draft.save(status: status, to: store, bytes: bytes)
        if saved != nil { clearHistory() }
        return saved
    }

    /// 지운 페이지의 획은 되돌리기가 살아 있는 동안만 남는다 — 저장할 때 떨군다.
    private func pruned() -> CanvasDocument {
        let alive = Set(document.pages.map(\.id))
        return CanvasDocument(pages: document.pages,
                              strokes: document.strokes.filter { alive.contains($0.key) })
    }

    // MARK: - 조각

    /// ⚠️ **한 번 더 미뤄 읽는다** — 기본 `UndoManager`는 런루프 한 바퀴 끝에 그룹을 닫아,
    /// 등록 직후에 읽은 값이 아직 옛 값일 수 있다(그러면 `11-N2`가 한 박자 늦게 켜진다).
    private func refreshUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
        Task { @MainActor in
            canUndo = undoManager.canUndo
            canRedo = undoManager.canRedo
        }
    }

    /// 절차적 기울기 −4~+4도. **id에서 뽑으므로 같은 사진은 늘 같은 각도로 놓인다.**
    private static func tilt(seed: UUID) -> Double {
        let byte = withUnsafeBytes(of: seed.uuid) { $0[0] }
        return Double(Int(byte) % 81 - 40) / 10
    }
}

extension CanvasSession {
    /// 초안 하나로 캔버스를 연다. **이미 캔버스가 있으면 이어받고 진입도 「고치러 온 것」이 된다.**
    static func opening(_ draft: RecordDraft) -> CanvasSession? {
        // ⚠️ **새 문서로 시작하면 안 된다** — 승격했다 초안으로 남긴 기록이 `09`를 한 번
        // 들르는 것만으로 배치와 획을 잃는다. `.promotion`으로 줘도 진입 상태가 잘못 발화한다.
        if let canvas = draft.canvas {
            return CanvasSession(draft: draft, entry: .editingRecord, document: canvas)
        }
        guard let first = draft.included.first else { return nil }
        let session = CanvasSession(draft: draft, entry: .promotion,
                                    document: CanvasDocument(pages: [CanvasPage()]))
        session.place(imageID: first.id, at: Layout.canvasEntryPhotoCenter,
                      fitting: Layout.canvasEntryPhotoSize)
        session.clearHistory()
        return session
    }

    /// `08`의 `수정` — 저장돼 있던 페이지 전부를 그대로 연다. 갤러리 기록이면 `nil`이다.
    static func editing(_ record: Record) -> CanvasSession? {
        guard let canvas = record.canvas else { return nil }
        return CanvasSession(draft: .editing(record), entry: .editingRecord, document: canvas)
    }
}
