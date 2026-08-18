// 편집 중인 캔버스 — 되돌리기 한 스택과 저장 형태의 명세.

import Foundation
import MomentKernel
import PhotoSource
import Testing
@testable import Moanogi

private let day = CalendarDay(year: 2026, month: 8, day: 3)

private func clock(_ hour: Int, _ minute: Int) throws -> WallClock {
    try #require(WallClock(year: 2026, month: 8, day: 3,
                           hour: hour, minute: minute, second: 0, hundredth: 0))
}

private func sourcePhoto(_ id: String, at capturedAt: WallClock) -> DraftPhoto {
    DraftPhoto(id: UUID(),
               origin: .source(asset: SourceAsset(id: id, filename: "\(id).png",
                                                  pixelWidth: 1600, pixelHeight: 738),
                               capturedAt: capturedAt),
               isIncluded: true)
}

/// 저장소를 실제로 태운다 — 저장된 사진을 읽는 길이 세션 안에 있다.
private func store() -> RecordStore {
    RecordStore(root: FileManager.default.temporaryDirectory
        .appending(path: "canvas-\(UUID().uuidString)"))
}

@MainActor
private func draft() throws -> RecordDraft {
    RecordDraft(day: day, start: try clock(18, 0),
                startsFromMoment: true,
                photos: [sourcePhoto("a", at: try clock(18, 5)),
                         sourcePhoto("b", at: try clock(18, 30))])
}

/// 한 단계로 되돌아갈 변경 하나를 묶는다.
///
/// ⚠️ **테스트에는 런루프가 없다.** 기본 `UndoManager`는 런루프 한 바퀴 끝에 그룹을 닫아서,
/// 그냥 두면 테스트 안의 변경이 전부 한 그룹이 되고 되돌리기 한 번에 다 되돌아간다.
@MainActor
private func step(_ session: CanvasSession, _ body: () -> Void) {
    session.undoManager.groupsByEvent = false
    session.undoManager.beginUndoGrouping()
    body()
    session.undoManager.endUndoGrouping()
}

@Suite("편집 중인 캔버스")
@MainActor
struct CanvasSessionTests {

    // MARK: - 진입

    @Test func 승격하면_첫_사진_한_장만_놓인다() throws {
        let draft = try draft()

        let session = try #require(CanvasSession.opening(draft, in: store()))

        #expect(session.document.pages.count == 1)
        #expect(session.page.elements.count == 1)
        #expect(session.page.elements[0].imageID == draft.included[0].id)
    }

    @Test func 승격_직후에는_되돌릴_것이_없다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))

        #expect(!session.canUndo)
    }

    @Test func 사진이_없으면_승격하지_못한다() throws {
        let draft = RecordDraft(day: day, start: try clock(18, 0),
                                startsFromMoment: true, photos: [])

        #expect(CanvasSession.opening(draft, in: store()) == nil)
    }

    @Test func 이미_캔버스를_가진_초안은_그_문서를_이어받는다() throws {
        let first = try #require(CanvasSession.opening(try draft(), in: store()))
        first.addPage()
        first.draft.setCanvas(first.document)

        let again = try #require(CanvasSession.opening(first.draft, in: store()))

        #expect(again.document == first.document)
        // 첫 진입이 아니다 — 다시 열 때마다 선택이 튀고 서랍이 열리면 안 된다.
        #expect(again.entry == .editingRecord)
    }

    // MARK: - `CAN-07` 되돌리기

    @Test func 요소를_옮겼다_되돌리면_처음_자리로_간다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let element = session.page.elements[0]
        let before = element.frame

        session.update(element.id, frame: before.offsetBy(dx: 100, dy: 40),
                       rotation: element.rotation)
        session.undoChange()

        #expect(session.element(element.id)?.frame == before)
    }

    @Test func 획은_요소_되돌리기에_딸려가지_않는다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let element = session.page.elements[0]
        let strokes = Data("획".utf8)
        step(session) { session.setStrokes(strokes, page: session.page.id) }

        step(session) { session.update(element.id, frame: .zero, rotation: 0) }
        session.undoChange()

        #expect(session.strokes == strokes)
    }

    @Test func 되돌린_것을_다시_할_수_있다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let element = session.page.elements[0]
        let moved = element.frame.offsetBy(dx: 100, dy: 40)

        session.update(element.id, frame: moved, rotation: element.rotation)
        session.undoChange()
        session.redoChange()

        #expect(session.element(element.id)?.frame == moved)
    }

    // MARK: - 되돌리기와 페이지

    /// ⚠️ **되돌리기가 다른 페이지를 건드리면 그 페이지로 데려간다** — 안 데려가면 지금 안
    /// 보이는 페이지가 조용히 바뀐다 (사용자 판정 2026-08-18).
    @Test func 다른_페이지의_획을_되돌리면_그_페이지로_데려간다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let first = session.page.id
        step(session) { session.setStrokes(Data("획".utf8), page: first) }
        step(session) { session.addPage() }
        #expect(session.pageIndex == 1)

        // 페이지 추가를 먼저 되돌리고, 그다음이 앞 페이지의 획이다.
        session.undoChange()
        session.undoChange()

        #expect(session.pageIndex == 0)
        #expect(session.document.strokes[first] == nil)
    }

        // MARK: - 페이지

    @Test func 페이지를_더하면_그리로_옮겨간다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))

        session.addPage()

        #expect(session.document.pages.count == 2)
        #expect(session.pageIndex == 1)
        #expect(session.page.elements.isEmpty)
    }

    @Test func 마지막_한_장은_지울_수_없다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))

        session.deletePage(session.page.id)

        #expect(session.document.pages.count == 1)
    }

    // MARK: - `CAN-06` 겹침 순서

    @Test func 맨_뒤로_보내면_배열의_앞으로_간다() throws {
        let draft = try draft()
        let session = try #require(CanvasSession.opening(draft, in: store()))
        session.place(imageID: draft.included[1].id, at: .zero,
                      fitting: CGSize(width: 10, height: 10))
        let last = try #require(session.page.elements.last)

        session.move(last.id, toFront: false)

        #expect(session.page.elements.first?.id == last.id)
    }

    // MARK: - `CAN-02` 원본 비율

    @Test func 놓인_사진은_원본_비율을_지킨다() throws {
        // 1600×738 — 상자(520×361)보다 훨씬 납작해서 폭이 먼저 닿는다.
        let session = try #require(CanvasSession.opening(try draft(), in: store()))

        let frame = try #require(session.page.elements.first?.frame)

        #expect(frame.width == 520)
        #expect(abs(frame.height - 520 * 738 / 1600) < 0.01)
    }

    // MARK: - 저장

    @Test func 저장하면_캔버스가_기록에_실려_디스크에서_돌아온다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft(), in: store))
        session.setStrokes(Data("획".utf8), page: session.page.id)

        let saved = await session.save(status: .draft) { _ in Data("바이트".utf8) }

        let record = try #require(saved)
        #expect(record.isCanvas)
        #expect(record.canvas?.pages.count == 1)
        let loaded = try #require(try store.all().first)
        #expect(loaded.canvas == record.canvas)
        #expect(loaded.status == .draft)
    }

    @Test func 저장하면_기록이_보여주는_것은_구운_페이지다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let draft = try draft()
        let session = try #require(CanvasSession.opening(draft, in: store))
        session.addPage()

        let saved = try #require(await session.save(status: .draft) { _ in Data("바이트".utf8) })

        #expect(saved.images.count == saved.canvas?.pages.count)
        #expect(saved.images.allSatisfy { $0.origin == .baked })
        // 재료는 문서 안에 남는다 — 이것이 없으면 다시 고칠 사진이 없다.
        #expect(saved.canvas?.sources.map(\.id) == draft.included.map(\.id))
    }

    @Test func 다시_고치러_들어오면_구운_페이지가_아니라_재료를_든다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let first = try #require(CanvasSession.opening(try draft(), in: store))
        let saved = try #require(await first.save(status: .draft) { _ in Data("바이트".utf8) })

        let again = try #require(CanvasSession.editing(saved, in: store))

        #expect(again.draft.included.map(\.id) == saved.canvas?.sources.map(\.id))
    }

    @Test func 저장하면_되돌릴_것이_없어진다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft(), in: store))
        session.addPage()
        #expect(session.canUndo)

        _ = await session.save(status: .draft) { _ in Data("바이트".utf8) }

        #expect(!session.canUndo)
    }

    @Test func 지운_페이지의_획은_저장할_때_떨어진다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft(), in: store))
        let first = session.page.id
        session.setStrokes(Data("획".utf8), page: first)
        session.addPage()
        session.deletePage(first)

        let saved = await session.save(status: .draft) { _ in Data("바이트".utf8) }

        #expect(try #require(saved).canvas?.strokes.isEmpty == true)
    }

    // MARK: - `CAN-06` 겹침 순서

    /// **손대지 않으면 종류가 정한다** — 사진 → 글 → 획 (사용자 판정 2026-08-18).
    @Test func 손대지_않으면_사진_글_획_순으로_쌓인다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let photo = try #require(session.page.elements.first?.id)

        let text = session.placeText(at: .zero, ink: .sumi)

        #expect(session.page.underStrokes.map(\.id) == [photo, text])
        #expect(session.page.overStrokes.isEmpty)
    }

    @Test func 나중에_놓은_사진도_글_아래에_깔린다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let draft = session.draft
        let text = session.placeText(at: .zero, ink: .sumi)

        session.place(imageID: draft.included[1].id, at: .zero,
                      fitting: CGSize(width: 100, height: 100))

        #expect(session.page.underStrokes.map(\.id).last == text)
    }

    /// ⚠️ **못 박은 자리는 그 뒤로 안 흔들린다** — 앱이 다시 맞추면 손으로 정리해 둔 배치가
    /// 무너진다 (사용자 판정 2026-08-18).
    @Test func 못_박은_자리는_새_요소가_들어와도_그대로다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let raised = try #require(session.page.elements.first?.id)
        session.move(raised, toFront: true)

        session.setStrokes(Data("획".utf8), page: session.page.id)
        _ = session.placeText(at: .zero, ink: .sumi)

        #expect(session.page.overStrokes.map(\.id) == [raised])
    }

    @Test func 맨_뒤로_보내면_전부보다_아래로_간다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let photo = try #require(session.page.elements.first?.id)
        let text = session.placeText(at: .zero, ink: .sumi)

        session.move(text, toFront: false)

        #expect(session.page.underStrokes.map(\.id) == [text, photo])
    }

    @Test func 맨_앞으로_보내면_획_위로_돌아온다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = try #require(session.page.elements.first?.id)
        session.move(id, toFront: false)

        session.move(id, toFront: true)

        #expect(session.page.overStrokes.map(\.id) == [id])
        #expect(session.page.underStrokes.isEmpty)
    }

    /// 층은 요소가 자기 값으로 드므로 **하나를 지워도 남은 것의 층이 안 바뀐다.**
    @Test func 하나를_지워도_남은_것의_층이_안_바뀐다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let photo = try #require(session.page.elements.first?.id)
        let text = session.placeText(at: .zero, ink: .sumi)
        session.move(text, toFront: true)

        session.remove(photo)

        #expect(session.page.overStrokes.map(\.id) == [text])
        #expect(session.page.underStrokes.isEmpty)
    }

    // MARK: - `11-C4` 글

    @Test func 탭한_자리에_글_상자가_선다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))

        let id = session.placeText(at: CGPoint(x: 120, y: 300), ink: .navy)

        let element = try #require(session.element(id))
        #expect(element.frame.origin == CGPoint(x: 120, y: 300))
        #expect(element.text?.ink == .navy)
        #expect(element.frame.height > 0)
    }

    @Test func 빈_글은_앉힐_때_사라진다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)

        session.setText(id, string: "")

        #expect(session.element(id) == nil)
    }

    @Test func 글이_길어지면_상자가_높아진다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)
        session.setText(id, string: "한 줄")
        let short = try #require(session.element(id)?.frame.height)

        session.setText(id, string: (0..<8).map { "\($0)번째 줄" }.joined(separator: "\n"))

        #expect(try #require(session.element(id)?.frame.height) > short)
    }

    /// ⚠️ **왼쪽 위를 붙잡는다** — 가운데를 잡으면 글이 길어질 때마다 이미 놓은 자리가 밀린다.
    @Test func 글이_길어져도_왼쪽_위는_그대로다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: CGPoint(x: 40, y: 60), ink: .sumi)

        session.setText(id, string: "여러\n줄로\n쓴다")

        #expect(session.element(id)?.frame.origin == CGPoint(x: 40, y: 60))
    }

    @Test func 글꼴을_바꾸면_안_만진_크기는_그_글꼴의_기본값이_된다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)
        #expect(session.element(id)?.text?.size == 24)

        session.setFace(.serif, of: id)

        #expect(session.element(id)?.text?.size == 17)
    }

    /// ⚠️ **손으로 고친 크기는 글꼴을 바꿔도 안 따라간다** — 사용자가 정한 값을 덮으면 안 된다.
    @Test func 손으로_고친_크기는_글꼴을_바꿔도_그대로다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)
        session.restyle(id) { $0.size = 40 }

        session.setFace(.serif, of: id)

        #expect(session.element(id)?.text?.size == 40)
    }

    @Test func 두_손가락은_글에서_글자_크기를_바꾼다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)
        session.setText(id, string: "노을")
        session.restyle(id) { $0.size = 20 }
        let element = try #require(session.element(id))

        let live = LiveTransform(element, grip: .pinch).scaled(by: 2, turnedBy: 0)

        #expect(live.text?.size == 40)
        // 폭은 상자의 것이라 안 바뀐다 — 글자만 커진다.
        #expect(live.frame.width == element.frame.width)
    }

    /// `11-I3` 컨트롤 범위 밖으로는 안 나간다.
    @Test func 두_손가락으로도_글자_크기가_범위를_안_넘는다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let id = session.placeText(at: .zero, ink: .sumi)
        session.setText(id, string: "노을")
        let element = try #require(session.element(id))

        let huge = LiveTransform(element, grip: .pinch).scaled(by: 100, turnedBy: 0)
        let tiny = LiveTransform(element, grip: .pinch).scaled(by: 0.01, turnedBy: 0)

        #expect(huge.text?.size == CanvasText.sizeRange.upperBound)
        #expect(tiny.text?.size == CanvasText.sizeRange.lowerBound)
    }

    // MARK: - `CAN-03` 밖에서 들어온 이미지

    @Test func 드롭한_이미지는_그_자리에_놓이고_기록의_사진이_된다() throws {
        let session = try #require(CanvasSession.opening(try draft(), in: store()))
        let before = session.draft.included.count

        let id = session.addImage(Data("이미지".utf8), fileExtension: "png",
                                  at: CGPoint(x: 300, y: 200))

        #expect(session.draft.included.count == before + 1)
        #expect(session.page.elements.last?.imageID == id)
        // 바이트가 초안에 실려야 저장이 기록 디렉터리로 복사한다.
        #expect(session.draft.importedData(of: id) != nil)
    }

    @Test func 드롭한_이미지도_저장하면_재료로_남는다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasDropTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft(), in: store))
        let id = session.addImage(Data("이미지".utf8), fileExtension: "png", at: .zero)

        let saved = try #require(await session.save(status: .draft) { _ in Data("바이트".utf8) })

        #expect(saved.canvas?.sources.map(\.id).contains(id) == true)
    }

    // MARK: - 서랍

    @Test func 같은_사진을_두_번_놓으면_수량이_둘이다() throws {
        let draft = try draft()
        let session = try #require(CanvasSession.opening(draft, in: store()))
        let imageID = draft.included[0].id

        session.place(imageID: imageID, at: .zero, fitting: CGSize(width: 10, height: 10))

        #expect(session.placedCount(imageID: imageID) == 2)
    }
}
