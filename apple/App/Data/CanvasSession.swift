// 편집 중인 캔버스. `11`이 보는 상태 전부와 저장이 여기서 돈다.
//
// ⚠️ 이 객체의 수명은 화면이 아니라 **작업**이다 — `09`에서 승격해 `08`에 도착할 때까지 산다.

import Foundation

/// `11`이 고치고 있는 캔버스 하나.
///
/// **초안(`RecordDraft`)과 짝으로 산다** — 사진의 출처·발생일시·설명은 여전히 초안의 것이고
/// 캔버스는 그 사진을 어디에 놓았는지만 안다. 저장도 초안이 지므로 여기서 바이트를 안 만진다.
///
/// ⚠️ **되돌리기 스택은 캔버스 하나에 하나다** (`CAN-07`). 요소 변경도 획도 이 객체가 같은
/// `UndoManager`에 등록한다 — 스택을 둘로 두면 `11-N2` 버튼 하나가 어느 쪽을 되돌리는지
/// 사용자가 못 고른다.
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
    /// 저장할 자리이자 **이미 저장된 사진을 읽을 자리**다 — 크기를 모르는 사진의 비율이
    /// 여기서 풀린다.
    let store: RecordStore

    private(set) var document: CanvasDocument
    /// 지금 보고 있는 페이지. **항상 정확히 하나**라 옵셔널이 아니다.
    var pageIndex: Int
    private(set) var canUndo = false
    private(set) var canRedo = false
    /// 획이 밖에서 바뀔 때마다 오른다. **그리기 층이 이 값으로 다시 읽을 때를 안다.**
    private(set) var strokesRevision = 0

    /// **획도 이 매니저에 등록된다** — 그리기 층이 이것을 받아 쓴다.
    @ObservationIgnored let undoManager = UndoManager()

    init(draft: RecordDraft, entry: Entry, document: CanvasDocument, store: RecordStore) {
        self.draft = draft
        self.entry = entry
        self.document = document
        self.store = store
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

    /// 되돌릴 수 있게 페이지를 바꾼다. **되돌리면 그 일이 일어난 페이지로 돌아간다** —
    /// 안 그러면 지금 안 보이는 페이지가 조용히 바뀐다.
    func change(_ body: (inout [CanvasPage]) -> Void) {
        // ⚠️ **사본을 고쳐서 되쓴다** — `&document.pages`를 그대로 넘기면 문서가 잠긴 채로
        // 클로저가 돌고, 그 안에서 문서를 읽는 순간 프로세스가 죽는다(2026-08-18 실물).
        let before = document.pages
        let shown = pageIndex
        var pages = before
        body(&pages)
        guard before != pages else { return }
        document.pages = pages
        undoManager.registerUndo(withTarget: self) { session in
            session.change { $0 = before }
            session.pageIndex = min(shown, session.document.pages.count - 1)
        }
        refreshUndoState()
    }

    /// PencilKit이 획을 바꿨다. **겹침 순서는 안 건드린다** — 그건 사용자가 정한다.
    func setStrokes(_ data: Data, page id: UUID) {
        apply(strokes: data, page: id)
    }

    /// 획을 갈아 끼우고 되돌리기에 등록한다. **되돌리면 그 페이지로 데려간다.**
    private func apply(strokes data: Data?, page id: UUID) {
        // ⚠️ **PencilKit 스택에 안 맡긴다** — 그쪽 되돌리기는 그림이 아니라 뷰에 걸려 있어,
        // 페이지를 넘긴 뒤 되돌리면 이전 그림이 지금 페이지에 써 넣어진다(2026-08-18 실기기).
        let before = document.strokes[id]
        guard before != data else { return }
        document.strokes[id] = data
        undoManager.registerUndo(withTarget: self) { session in
            if let index = session.document.pages.firstIndex(where: { $0.id == id }) {
                session.pageIndex = index
            }
            session.apply(strokes: before, page: id)
        }
        // ⚠️ **판을 올려야 화면이 다시 읽는다** — 손이 만든 변화가 아니라서 그리기 층은
        // 이 값으로만 안다.
        strokesRevision += 1
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

    /// `CAN-03` — 밖에서 들어온 이미지를 그 자리에 놓는다. 바이트는 초안이 든다.
    @discardableResult
    func addImage(_ data: Data, fileExtension: String, at point: CGPoint) -> UUID {
        let imageID = draft.addImported(data, fileExtension: fileExtension)
        place(imageID: imageID, at: point, fitting: Layout.canvasDropSize)
        return imageID
    }

    /// `11-T5` — 탭한 자리에 빈 글 상자를 놓는다. 내용은 그 자리에서 바로 받는다.
    func placeText(at point: CGPoint, ink: InkColor) -> UUID {
        let text = CanvasText(ink: ink)
        let element = CanvasElement(content: .text(text),
                                    frame: text.box(at: point,
                                                    width: CanvasText.initialWidth(from: point.x)))
        change { $0[pageIndex].elements.append(element) }
        return element.id
    }

    /// 글을 고쳐 담는다. **빈 글은 남기지 않는다** — 쓰다 만 상자가 종이에 안 보이게 남는다.
    func setText(_ id: UUID, string: String) {
        guard var text = element(id)?.text else { return }
        guard !string.isEmpty else { return remove(id) }
        text.string = string
        apply(text, to: id)
    }

    /// `11-I1` 글꼴을 바꾼다. **크기를 안 만졌으면 새 글꼴의 기본값으로 따라간다** — 손글씨와
    /// 반듯한 것은 같은 pt에서 크기가 다르게 읽힌다.
    func setFace(_ face: CanvasText.Face, of id: UUID) {
        restyle(id) { text in
            guard text.face != face else { return }
            if text.size == text.face.defaultSize { text.size = face.defaultSize }
            text.face = face
        }
    }

    /// 글꼴·굵기·크기·색을 바꾼다. 상자는 새 활자에 맞춰 다시 잰다.
    func restyle(_ id: UUID, _ body: (inout CanvasText) -> Void) {
        guard var text = element(id)?.text else { return }
        body(&text)
        apply(text, to: id)
    }

    /// 바뀐 글로 상자를 다시 재 앉힌다. **왼쪽 위를 붙잡는다** — 가운데를 잡으면 글이 길어질
    /// 때마다 이미 놓은 자리가 위로 밀려 올라간다.
    private func apply(_ text: CanvasText, to id: UUID) {
        change {
            guard let index = $0[pageIndex].elements.firstIndex(where: { $0.id == id })
            else { return }
            let frame = $0[pageIndex].elements[index].frame
            $0[pageIndex].elements[index].content = .text(text)
            $0[pageIndex].elements[index].frame = text.box(at: frame.origin, width: frame.width)
        }
    }

    /// 손을 뗐다 — 자리와, 두 손가락이 바꾼 글까지 **한 칸으로** 앉힌다.
    /// **`frame`은 이미 `LiveTransform.kept`를 지난 값이어야 한다.**
    func update(_ id: UUID, frame: CGRect, rotation: Double, text: CanvasText? = nil) {
        // ⚠️ 여기서 다시 붙들면 되돌리기 복원이 예전 문서의 자리를 조용히 고쳐 쓴다.
        change {
            guard let index = $0[pageIndex].elements.firstIndex(where: { $0.id == id }) else { return }
            $0[pageIndex].elements[index].frame = frame
            $0[pageIndex].elements[index].rotation = rotation
            if let text { $0[pageIndex].elements[index].content = .text(text) }
        }
    }

    func remove(_ id: UUID) {
        change { $0[pageIndex].elements.removeAll { $0.id == id } }
    }

    /// `CAN-06` — **맨 앞은 획보다도 위, 맨 뒤는 전부보다 아래다.** 종류가 정하던 자리를
    /// 사용자가 못 박는 것이고, 그 뒤로는 앱이 안 건드린다.
    func move(_ id: UUID, toFront: Bool) {
        change { pages in
            guard let index = pages[pageIndex].elements.firstIndex(where: { $0.id == id })
            else { return }
            var element = pages[pageIndex].elements.remove(at: index)
            element.pinned = toFront ? .front : .back
            // 같은 층에 이미 못 박힌 것이 있으면 그것보다도 앞·뒤여야 한다.
            pages[pageIndex].elements.insert(element, at: toFront
                ? pages[pageIndex].elements.count : 0)
        }
    }

    /// 원본 비율을 지키며 상자 안에 넣는다. 상자는 채우는 크기가 아니라 상한이다.
    private func fitted(_ imageID: UUID, in box: CGSize) -> CGSize {
        guard let photo = draft.photos.first(where: { $0.id == imageID }),
              let pixels = pixelSize(of: photo) else { return box }
        let ratio = min(box.width / pixels.width, box.height / pixels.height)
        return CGSize(width: pixels.width * ratio, height: pixels.height * ratio)
    }

    /// 그 사진의 원본 화소 크기. 앨범 자산이 아니면 헤더를 읽는다.
    func pixelSize(of photo: DraftPhoto) -> CGSize? {
        // ⚠️ **안 읽으면 상자를 그대로 쓴다** — 놓이는 순간 잘리고 구운 결과에도 그대로 남는다.
        if let size = photo.pixelSize { return size }
        if let stored = photo.storedImage {
            return ImageDecoding.pixelSize(store.imageURL(recordID: draft.id, image: stored))
        }
        if let data = draft.importedData(of: photo.id) { return ImageDecoding.pixelSize(data) }
        return nil
    }

    /// 어느 사진이 몇 번 놓였나 — `11-O3` 서랍의 수량 배지.
    func placedCount(imageID: UUID) -> Int {
        document.pages.reduce(0) { count, page in
            count + page.elements.filter { $0.imageID == imageID }.count
        }
    }

    // MARK: - 저장

    /// 캔버스를 기록으로 저장한다. 성공하면 그 기록, 실패하면 `nil`이고 초안이 실패를 든다.
    func save(status: Record.Status, bytes: @escaping OriginalBytesLoader) async -> Record? {
        // ⚠️ **기록이 보여주는 것은 구운 페이지고 사진은 재료다**(`CAN-09`) — 뒤바꿔 저장하면
        // `07`·`08`이 꾸미기 전 사진을 보여주고 다시 고칠 재료가 사라진다.
        guard let resolved = await draft.resolvePhotos(bytes: bytes) else { return nil }
        var document = pruned()
        document.sources = resolved.images
        draft.setCanvas(document)

        guard let baked = await CanvasBaker.bake(document, bytes: resolved.data,
                                                 in: store, recordID: draft.id) else {
            draft.markSaveFailed()
            return nil
        }
        let saved = draft.write(images: baked.images,
                                data: resolved.data.merging(baked.data) { _, new in new },
                                status: status, to: store)
        if saved != nil { clearHistory() }
        return saved
    }

    /// 지운 페이지의 획은 되돌리기가 살아 있는 동안만 남는다 — 저장할 때 떨군다.
    private func pruned() -> CanvasDocument {
        let alive = Set(document.pages.map(\.id))
        return CanvasDocument(pages: document.pages,
                              strokes: document.strokes.filter { alive.contains($0.key) },
                              sources: document.sources)
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
    static func opening(_ draft: RecordDraft, in store: RecordStore) -> CanvasSession? {
        // ⚠️ **새 문서로 시작하면 안 된다** — 승격했다 초안으로 남긴 기록이 `09`를 한 번
        // 들르는 것만으로 배치와 획을 잃는다. `.promotion`으로 줘도 진입 상태가 잘못 발화한다.
        if let canvas = draft.canvas {
            return CanvasSession(draft: draft, entry: .editingRecord, document: canvas, store: store)
        }
        guard let first = draft.included.first else { return nil }
        let session = CanvasSession(draft: draft, entry: .promotion,
                                    document: CanvasDocument(pages: [CanvasPage()]), store: store)
        session.place(imageID: first.id, at: Layout.canvasEntryPhotoCenter,
                      fitting: Layout.canvasEntryPhotoSize)
        session.clearHistory()
        return session
    }

    /// `08`의 `수정` — 저장돼 있던 페이지 전부를 그대로 연다. 갤러리 기록이면 `nil`이다.
    static func editing(_ record: Record, in store: RecordStore) -> CanvasSession? {
        guard let canvas = record.canvas else { return nil }
        return CanvasSession(draft: .editing(record), entry: .editingRecord,
                             document: canvas, store: store)
    }
}
