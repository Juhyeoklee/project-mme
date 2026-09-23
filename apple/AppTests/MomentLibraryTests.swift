// 소스를 갈아 끼우고 (`SRC-01` `SRC-04` `SRC-08`), 소스에 사진이 드는 (`SRC-03`) 계약.
// 사진 라이브러리 없이 도는 자리만 본다.

import PhotoSource
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

    // MARK: - 새 사진이 들어온다 (`SRC-03`)

    @Test func 자산_식별자로_지금의_첨자를_되물을_수_있다() throws {
        let library = seeded()
        let asset = try #require(Fixture.assets.first)

        let index = try #require(library.index(of: asset.id))

        #expect(library.asset(at: index)?.id == asset.id)
    }

    /// **`SRC-03`이 깨뜨리는 전제가 여기 있다** — 자산은 최신순이라 새 사진이 앞에 붙고
    /// 뒤가 전부 밀린다. 첨자로 사진을 붙들어 둔 자리는 그때 다른 사진을 가리킨다.
    @Test func 새_사진이_앞에_붙으면_같은_사진의_첨자가_밀린다() throws {
        let asset = try #require(Fixture.assets.first)
        let before = try #require(seeded().index(of: asset.id))

        let arrived = SourceAsset(id: "새-사진", filename: "새.png", pixelWidth: 0, pixelHeight: 0)
        let reloaded = MomentLibrary.preview(Fixture.classification,
                                             assets: [arrived] + Fixture.assets)

        #expect(reloaded.index(of: asset.id) == before + 1)
        #expect(reloaded.index(of: arrived.id) == 0)
    }

    @Test func 소스에서_사라진_사진은_첨자를_못_얻는다() {
        let library = seeded()
        library.use(albumID: "다른-앨범")

        #expect(library.index(of: Fixture.assets[0].id) == nil)
    }

    // MARK: - 원본을 끝내 못 받은 사진 (`R8`)

    /// **화면이 묻는 길이다** — 초안은 첨자가 아니라 자산을 쥐고 재분류 너머로 산다.
    @Test func 원본을_못_받은_사진은_자산_식별자로_가려진다() throws {
        let missing = try #require(Fixture.assets.first)
        let received = try #require(Fixture.assets.last)
        let library = MomentLibrary.preview(Fixture.classification, assets: Fixture.assets,
                                            missingOriginals: [0])

        #expect(library.isMissingOriginal(missing.id))
        #expect(!library.isMissingOriginal(received.id))
    }

    /// 소스에서 사라진 사진은 첨자가 없다 — **「못 받았다」가 아니라 「모른다」다.**
    @Test func 소스에_없는_자산은_못_받은_것으로_치지_않는다() {
        let library = MomentLibrary.preview(Fixture.classification, assets: Fixture.assets,
                                            missingOriginals: [0])

        #expect(!library.isMissingOriginal("소스에-없는-자산"))
    }

    /// `05`의 연사 셀이 여러 장을 대표하므로 **셈이 배지의 계약이다.**
    @Test func 못_받은_장수는_넘긴_사진_중에서만_센다() {
        let library = MomentLibrary.preview(Fixture.classification, assets: Fixture.assets,
                                            missingOriginals: [0, 1, 5])

        #expect(library.missingOriginalCount(in: [0, 1, 2]) == 2)
        #expect(library.missingOriginalCount(in: [2, 3]) == 0)
    }
}
