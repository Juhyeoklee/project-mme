// 오케스트레이션 — 두 패키지를 잇는 유일한 자리다. 커널은 I/O를 모르고 어댑터는 분류를 모른다.
//
// ## 2패스인 이유 — `R8` 실측(2026-08-03)이 값을 줬다
//
//   열거(파일명)      212장 **1.4초**          → 시간 구조를 즉시 그릴 수 있다
//   로컬 원본 바이트   212장 **1.4초** (장당 6.5ms)
//   기기에 없음 판정   **6~16ms**에 명확히 갈린다 — 감지 비용이 사실상 0이다
//   iCloud 받아오기   26장 **555초**, 그중 **한 장이 441초**(전체의 79%)
//
// 그래서 셋으로 갈라 돈다 — ① 전량 열거 후 즉시 분류 ② 로컬에 있는 것만 훑기 ③ 원격.
// **한 장이 7분을 먹어도 뒤가 막히면 안 되므로** ③에는 상한을 걸고 넘긴 것은 뒤로 미룬다.
// 지연은 전부 여기 몫이다 (ADR 0002 대가 3의 "순차 처리"는 메모리 얘기였고 지연은 별개 문제다).
//
// ## 손으로 지켜야 하는 계약 하나
//
// **ADR 0004 결정 2 (d)** — 1패스에 자산을 *전량 열거해 전부* 넘긴다. 기계가 강제하지 못한다.
// 일부만 넘기고 나중에 사진을 더하면 *"순간은 쪼개질 뿐 합쳐지지 않는다"* 가 조용히 사라지고
// 화면 `04`의 행이 재배치되기 시작한다. 이 파일에서 커널을 부르는 곳은 `reclassify()` 하나뿐이고,
// 그것이 넘기는 배열은 **항상 `inputs` 전체**다. 부분 배열을 넘기는 경로를 만들지 마라.

import Foundation
import MomentKernel
import PhotoSource

@MainActor
@Observable
final class MomentLibrary {
    /// 진행 단계. 화면이 보는 것은 진행바 하나뿐이고(`04-A1`) 이 구분은 여기 안에서만 쓰인다.
    enum Phase: Equatable {
        case idle
        /// 열거 중. 1.4초라 대개 눈에 안 띈다.
        case enumerating
        /// 로컬 훑기.
        case readingLocal
        /// 원격 받아오기. **여기가 분 단위다** (§5 항목 12~14).
        case readingRemote
        case ready
        /// 권한이 없거나 앨범이 없다. 화면은 `04-E1` 한 줄로 흡수한다 —
        /// `PRD.md` §9.1이 권한 실패 처리를 만들지 않기로 했고 §2.4가 상태 목록에서 뺐다.
        /// 이유를 버리지 않고 들고만 있는 것은 개발 중에 원인을 봐야 하기 때문이다.
        case blocked(String)

        var isWorking: Bool {
            switch self {
            case .enumerating, .readingLocal, .readingRemote: true
            case .idle, .ready, .blocked: false
            }
        }
    }

    // MARK: - 화면이 보는 것

    /// 최신 먼저. 1패스가 끝나면 시간 구조가 전부 여기 있다.
    private(set) var days: [Day] = []
    /// `04-N2`의 두 숫자. 장수는 1패스에 확정되고, 순간 개수는 바이트가 채워지며 **올라간다**.
    private(set) var momentCount = 0
    private(set) var photoCount = 0
    private(set) var phase: Phase = .idle
    /// `04-A1` 진행바. 결정형이다.
    private(set) var progress: Double = 0
    /// 재분류할 때마다 오른다. **썸네일 재시도의 방아쇠다** — 원본이 방금 내려받아졌으면
    /// 아까 회색이던 칸이 이번엔 그려진다. 실패를 캐시하지 않는 대신 이 값으로 다시 묻는다.
    private(set) var generation = 0

    // MARK: - 안쪽

    /// 커널 인덱스 ↔ 자산. **`inputs`와 같은 길이·같은 순서다** — 이 대응이 깨지면 전부 어긋난다.
    private(set) var assets: [SourceAsset] = []
    private var inputs: [PhotoInput] = []
    /// 바이트를 아직 못 정한 사진. 진행률의 분자는 `assets.count - pending.count`다.
    private var pending: Set<Int> = []

    private let source: AlbumPhotoSource
    private let settings: Settings
    private var task: Task<Void, Never>?

    /// 원격 한 장에 거는 상한. 실측에서 중앙은 1.7초인데 한 장이 441초였고 그 한 장이 전체의
    /// 79%였다. 상한을 걸어 뒤로 미루면 나머지가 흐른다.
    ///
    /// **상한을 넘겨도 그 다운로드는 죽지 않는다** — PhotoKit 요청은 취소되지 않고 백그라운드에서
    /// 계속 받는다. 그래서 2라운드에서 다시 부르면 대개 이미 로컬에 있다. 버리는 것은 결과지 일이 아니다.
    private let remoteTimeout: Duration = .seconds(20)
    /// 원격 도중 재분류 간격(장). 분 단위 대기 동안 화면이 얼어붙지 않게 한다.
    /// 잦아도 목록이 흐트러지지 않는 근거는 ADR 0004 결정 2 (c) — 순간은 쪼개질 뿐이다.
    private let remoteReclassifyEvery = 16

    /// 커널이 돌려준 인덱스를 자산으로 되돌린다. **커널에는 식별자 개념이 없어서**
    /// (`Reading.swift`) 원본과 잇는 일이 배열을 쥔 이쪽 몫이다.
    func asset(at index: Int) -> SourceAsset? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    init(albumTitle: String, settings: Settings = .default) {
        self.source = AlbumPhotoSource(albumTitle: albumTitle)
        self.settings = settings
    }

    // MARK: - 흐름

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.run()
            self?.task = nil
        }
    }

    /// `04` 아래로 당기기. 전부 다시 돈다 — `M1`엔 저장이 없어 증분이라는 개념 자체가 없다.
    func refresh() async {
        task?.cancel()
        task = nil
        await run()
    }

    private func run() async {
        phase = .enumerating
        progress = 0

        var access = AlbumPhotoSource.currentAccess()
        if !access.canRead { access = await AlbumPhotoSource.requestAccess() }
        guard access.canRead else {
            phase = .blocked("읽기 권한 없음 (\(access))")
            return
        }

        // ── 1패스 — 전량 열거. ADR 0004 (d)가 붙는 자리가 여기다 ──────────
        do {
            assets = try source.assets()
        } catch {
            phase = .blocked("\(error)")
            return
        }
        inputs = assets.map { PhotoInput(filename: $0.filename) }
        pending = Set(inputs.indices)
        reclassify()
        guard !assets.isEmpty else {
            phase = .ready
            return
        }

        // ── 2패스 A — 로컬에 있는 것만. 없는 것은 6~16ms에 갈리므로 전량을 훑어도 싸다 ──
        phase = .readingLocal
        var remote: [Int] = []
        for index in assets.indices {
            if Task.isCancelled { return }
            if await load(index, allowingNetwork: false) == false { remote.append(index) }
        }
        reclassify()

        // ── 2패스 B — 원격 1라운드. 상한을 걸고 넘긴 것은 뒤로 미룬다 ──────────
        guard !remote.isEmpty else {
            finish()
            return
        }
        phase = .readingRemote
        var deferred: [Int] = []
        var since = 0
        for index in remote {
            if Task.isCancelled { return }
            if await load(index, allowingNetwork: true, within: remoteTimeout) == false {
                deferred.append(index)
            }
            since += 1
            if since >= remoteReclassifyEvery {
                since = 0
                reclassify()
            }
        }
        reclassify()

        // ── 2패스 C — 미뤄둔 것. 상한 없이, 마지막에 ────────────────────────
        for index in deferred {
            if Task.isCancelled { return }
            _ = await load(index, allowingNetwork: true)
            reclassify()
        }
        finish()
    }

    /// 한 장의 바이트를 읽어 `inputs`에 채운다. 반환값은 **더 해볼 일이 남았는가**가 아니라
    /// *이번 시도로 결말이 났는가*다 — `false`면 다음 단계로 넘긴다.
    @discardableResult
    private func load(_ index: Int, allowingNetwork: Bool, within limit: Duration? = nil) async -> Bool {
        do {
            let data = try await withOptionalTimeout(limit) { [source, assets] in
                try await source.originalBytes(of: assets[index], allowingNetwork: allowingNetwork)
            }
            inputs[index] = PhotoInput(filename: assets[index].filename, bytes: [UInt8](data))
            resolve(index)
            return true
        } catch is TimedOut {
            return false
        } catch PhotoSourceError.originalNotOnDevice {
            // 네트워크를 이미 열고도 이 실패면 더 해볼 것이 없다.
            if allowingNetwork { resolve(index) }
            return allowingNetwork
        } catch {
            // 읽을 수 없는 사진은 **바이트 없는 사진과 같은 취급**을 받는다 (ADR 0004 결정 2).
            // 시간 경계에는 온전히 참여하고 장소·연사에만 빠진다. 커널에 예외 경로가 없다.
            resolve(index)
            return true
        }
    }

    private func resolve(_ index: Int) {
        pending.remove(index)
        progress = assets.isEmpty ? 0 : Double(assets.count - pending.count) / Double(assets.count)
    }

    /// **커널을 부르는 유일한 자리.** 넘기는 것은 언제나 `inputs` 전체다 — ADR 0004 (d).
    private func reclassify() {
        let result = Classifier.classify(inputs, settings: settings)
        days = result.days
        momentCount = result.momentCount
        photoCount = result.photoCount
        generation += 1
    }

    private func finish() {
        phase = .ready
        progress = 1
        // 바이트를 놓는다. 211장이면 170MB 남짓이고(실측: 장당 중앙 0.75MB) 분류가 끝난 뒤로는
        // 쓸 곳이 없다. ADR 0004 대가 2가 예고한 자리 — 커널 계약상 재분류에는 전량이 동시에
        // 필요하므로, 줄일 수 있는 것은 **들고 있는 기간**뿐이다.
        inputs = assets.map { PhotoInput(filename: $0.filename) }
    }
}

#if DEBUG
extension MomentLibrary {
    /// 프리뷰용 — 라이브러리를 건드리지 않고 결과만 얹는다.
    static func preview(_ classification: Classification,
                        assets: [SourceAsset],
                        phase: Phase = .ready,
                        progress: Double = 1) -> MomentLibrary {
        let library = MomentLibrary(albumTitle: "preview")
        library.assets = assets
        library.days = classification.days
        library.momentCount = classification.momentCount
        library.photoCount = classification.photoCount
        library.phase = phase
        library.progress = progress
        return library
    }
}
#endif

// MARK: - 상한

private struct TimedOut: Error {}

/// `limit`이 `nil`이면 그냥 기다린다.
///
/// 진 쪽 작업을 죽이지 않는다 — PhotoKit의 바이트 요청은 취소를 받지 않고, 취소되더라도
/// 이미 받은 만큼은 캐시에 남아 다음 시도를 싸게 만든다.
private func withOptionalTimeout<T: Sendable>(
    _ limit: Duration?,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard let limit else { return try await operation() }
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw TimedOut()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
