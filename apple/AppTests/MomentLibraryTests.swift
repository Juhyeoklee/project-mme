// 소스를 갈아 끼우는 계약 (`SRC-01` `SRC-04` `SRC-08`). 사진 라이브러리 없이 도는 자리만 본다.

import Testing
@testable import Moanogi

@Suite("소스 걸기")
@MainActor
struct MomentLibraryTests {

    // MARK: - 조각

    /// 합성 분류가 얹힌 라이브러리. 소스를 바꾸기 **전**의 상태다.
    private func seeded() -> MomentLibrary {
        let library = MomentLibrary.preview(Fixture.classification, assets: Fixture.assets)
        #expect(!library.days.isEmpty)
        return library
    }

    // MARK: - 계약

    /// ⚠️ **무엇이 막는지는 프로세스의 권한이 정한다** — 테스트 프로세스에는 사진 권한이 없어
    /// `blocked`가 되고, 권한을 얻은 기기에서는 `needsSource`가 된다. **두 경우 다 커널은
    /// 한 번도 안 돈다** — 이 테스트가 지는 것은 그쪽이다.
    @Test func 소스가_없으면_분류가_한_번도_안_돈다() async {
        let library = MomentLibrary(albumID: nil)
        await library.refresh()
        // 커널을 부르면 오르는 값이다 — 0이면 부른 적이 없다.
        #expect(library.generation == 0)
        #expect(library.days.isEmpty)
        #expect(!library.phase.isWorking)
    }

    /// `SRC-08` — 앞 앨범의 사진이 새 소스의 화면에 한 장도 남으면 안 된다.
    @Test func 소스를_바꾸면_앞_앨범의_결과가_한_톨도_안_남는다() {
        let library = seeded()
        library.use(albumID: "다른-앨범")

        #expect(library.albumID == "다른-앨범")
        #expect(library.days.isEmpty)
        #expect(library.assets.isEmpty)
        #expect(library.momentCount == 0)
        #expect(library.photoCount == 0)
        #expect(library.sourceName == nil)
        #expect(library.phase == .idle)
    }

    /// ⚠️ **앱이 뜰 때마다 같은 값으로 다시 건다** — 여기서 지우면 첫 화면이 매번 비워진다.
    @Test func 같은_소스를_다시_걸면_아무_일도_안_일어난다() {
        let library = seeded()
        let before = library.days
        library.use(albumID: library.albumID)
        #expect(library.days.count == before.count)
        #expect(library.phase == .ready)
    }

    /// 썸네일은 실패를 캐시하지 않는 대신 이 값으로 다시 묻는다 — 안 오르면 옛 사진이 남는다.
    @Test func 소스를_바꾸면_썸네일이_다시_묻는다() {
        let library = seeded()
        let before = library.generation
        library.use(albumID: "다른-앨범")
        #expect(library.generation > before)
    }
}
