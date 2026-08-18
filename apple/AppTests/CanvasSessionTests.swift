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

@MainActor
private func draft() throws -> RecordDraft {
    RecordDraft(day: day, start: try clock(18, 0),
                startsFromMoment: true,
                photos: [sourcePhoto("a", at: try clock(18, 5)),
                         sourcePhoto("b", at: try clock(18, 30))])
}

@Suite("편집 중인 캔버스")
@MainActor
struct CanvasSessionTests {

    // MARK: - 진입

    @Test func 승격하면_첫_사진_한_장만_놓인다() throws {
        let draft = try draft()

        let session = try #require(CanvasSession.opening(draft))

        #expect(session.document.pages.count == 1)
        #expect(session.page.elements.count == 1)
        #expect(session.page.elements[0].imageID == draft.included[0].id)
    }

    @Test func 승격_직후에는_되돌릴_것이_없다() throws {
        let session = try #require(CanvasSession.opening(try draft()))

        #expect(!session.canUndo)
    }

    @Test func 사진이_없으면_승격하지_못한다() throws {
        let draft = RecordDraft(day: day, start: try clock(18, 0),
                                startsFromMoment: true, photos: [])

        #expect(CanvasSession.opening(draft) == nil)
    }

    @Test func 이미_캔버스를_가진_초안은_그_문서를_이어받는다() throws {
        let first = try #require(CanvasSession.opening(try draft()))
        first.addPage()
        first.draft.setCanvas(first.document)

        let again = try #require(CanvasSession.opening(first.draft))

        #expect(again.document == first.document)
        // 첫 진입이 아니다 — 다시 열 때마다 선택이 튀고 서랍이 열리면 안 된다.
        #expect(again.entry == .editingRecord)
    }

    // MARK: - `CAN-07` 되돌리기

    @Test func 요소를_옮겼다_되돌리면_처음_자리로_간다() throws {
        let session = try #require(CanvasSession.opening(try draft()))
        let element = session.page.elements[0]
        let before = element.frame

        session.update(element.id, frame: before.offsetBy(dx: 100, dy: 40),
                       rotation: element.rotation)
        session.undoChange()

        #expect(session.element(element.id)?.frame == before)
    }

    @Test func 획은_요소_되돌리기에_딸려가지_않는다() throws {
        let session = try #require(CanvasSession.opening(try draft()))
        let element = session.page.elements[0]
        let strokes = Data("획".utf8)
        session.setStrokes(strokes, page: session.page.id)

        session.update(element.id, frame: .zero, rotation: 0)
        session.undoChange()

        #expect(session.strokes == strokes)
    }

    @Test func 되돌린_것을_다시_할_수_있다() throws {
        let session = try #require(CanvasSession.opening(try draft()))
        let element = session.page.elements[0]
        let moved = element.frame.offsetBy(dx: 100, dy: 40)

        session.update(element.id, frame: moved, rotation: element.rotation)
        session.undoChange()
        session.redoChange()

        #expect(session.element(element.id)?.frame == moved)
    }

    // MARK: - 페이지

    @Test func 페이지를_더하면_그리로_옮겨간다() throws {
        let session = try #require(CanvasSession.opening(try draft()))

        session.addPage()

        #expect(session.document.pages.count == 2)
        #expect(session.pageIndex == 1)
        #expect(session.page.elements.isEmpty)
    }

    @Test func 마지막_한_장은_지울_수_없다() throws {
        let session = try #require(CanvasSession.opening(try draft()))

        session.deletePage(session.page.id)

        #expect(session.document.pages.count == 1)
    }

    // MARK: - `CAN-06` 겹침 순서

    @Test func 맨_뒤로_보내면_배열의_앞으로_간다() throws {
        let draft = try draft()
        let session = try #require(CanvasSession.opening(draft))
        session.place(imageID: draft.included[1].id, at: .zero,
                      fitting: CGSize(width: 10, height: 10))
        let last = try #require(session.page.elements.last)

        session.move(last.id, toFront: false)

        #expect(session.page.elements.first?.id == last.id)
    }

    // MARK: - `CAN-02` 원본 비율

    @Test func 놓인_사진은_원본_비율을_지킨다() throws {
        // 1600×738 — 상자(520×361)보다 훨씬 납작해서 폭이 먼저 닿는다.
        let session = try #require(CanvasSession.opening(try draft()))

        let frame = try #require(session.page.elements.first?.frame)

        #expect(frame.width == 520)
        #expect(abs(frame.height - 520 * 738 / 1600) < 0.01)
    }

    // MARK: - 저장

    @Test func 저장하면_캔버스가_기록에_실려_디스크에서_돌아온다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft()))
        session.setStrokes(Data("획".utf8), page: session.page.id)

        let saved = await session.save(status: .draft, to: store) { _ in Data("바이트".utf8) }

        let record = try #require(saved)
        #expect(record.isCanvas)
        #expect(record.canvas?.pages.count == 1)
        let loaded = try #require(try store.all().first)
        #expect(loaded.canvas == record.canvas)
        #expect(loaded.status == .draft)
    }

    @Test func 저장하면_되돌릴_것이_없어진다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft()))
        session.addPage()
        #expect(session.canUndo)

        _ = await session.save(status: .draft, to: store) { _ in Data("바이트".utf8) }

        #expect(!session.canUndo)
    }

    @Test func 지운_페이지의_획은_저장할_때_떨어진다() async throws {
        let store = RecordStore(root: FileManager.default.temporaryDirectory
            .appending(path: "CanvasSaveTests-\(UUID().uuidString)"))
        let session = try #require(CanvasSession.opening(try draft()))
        let first = session.page.id
        session.setStrokes(Data("획".utf8), page: first)
        session.addPage()
        session.deletePage(first)

        let saved = await session.save(status: .draft, to: store) { _ in Data("바이트".utf8) }

        #expect(try #require(saved).canvas?.strokes.isEmpty == true)
    }

    // MARK: - 서랍

    @Test func 같은_사진을_두_번_놓으면_수량이_둘이다() throws {
        let draft = try draft()
        let session = try #require(CanvasSession.opening(draft))
        let imageID = draft.included[0].id

        session.place(imageID: imageID, at: .zero, fitting: CGSize(width: 10, height: 10))

        #expect(session.placedCount(imageID: imageID) == 2)
    }
}
