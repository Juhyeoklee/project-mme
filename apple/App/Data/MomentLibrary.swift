// 오케스트레이션 — 두 패키지를 잇는 유일한 자리다. 커널은 I/O를 모르고 어댑터는 분류를 모른다.
//
// **2패스로 도는 이유** — 열거는 212장 1.4초인데 iCloud 원본은 한 장이 441초까지 간다
// (`R8` 실측 2026-08-03). 그래서 셋으로 갈라 돈다: ① 전량 열거 후 즉시 분류 ② 로컬만 훑기
// ③ 원격은 상한을 걸고, 넘긴 것을 뒤로 미룬다. 지연은 전부 여기 몫이다.
//
// **손으로 지켜야 하는 계약 하나 — 기계가 못 막는다** (ADR `0004` 결정 2 (d)). 1패스에 자산을
// *전량 열거해 전부* 넘긴다. 일부만 넘기면 출력이 입력 집합의 함수라는 것만 남고 **시간 경계의
// 불변마저 사라진다.** 커널을 부르는 곳은 `reclassify()` 하나뿐이고
// **넘기는 배열은 항상 `inputs` 전체다 — 부분 배열을 넘기는 경로를 만들지 마라.**

import Foundation
import MomentKernel
import PhotoSource

/// 앨범을 읽어 분류 결과를 화면에 내주는 오케스트레이터. 화면이 보는 상태는 여기 다 있다.
///
/// 진행 중에도 `days`는 항상 완결된 분류 결과다 — 2패스가 도는 동안 장소 경계만 다시 계산된다.
@MainActor
@Observable
final class MomentLibrary {
    /// 진행 단계. 화면이 보는 것은 진행바 하나뿐이고(`04-A1`) 이 구분은 여기 안에서만 쓰인다.
    enum Phase: Equatable {
        case idle
        /// 열거 중 — 1.4초라 대개 안 보인다.
        case enumerating
        case readingLocal
        /// 원격 받아오기 — **여기가 분 단위다.**
        case readingRemote
        case ready
        /// 권한이 없거나 앨범이 없다. 이유 문자열은 개발 중에 보려고 들고만 있다.
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
    /// 지금 유효한 실행의 번호. ⚠️ **취소만으로는 앞 실행의 쓰기를 못 막는다** — PhotoKit의
    /// 바이트 요청이 취소를 안 받아, 죽은 실행이 `await`에서 되살아나 새 배열에 쓴다.
    private var epoch = 0

    /// 원격 한 장에 거는 상한. 중앙 1.7초, 최악 441초.
    /// 넘겨도 다운로드는 안 죽는다 — 버리는 것은 결과지 일이 아니다.
    private let remoteTimeout: Duration = .seconds(20)
    /// 원격 도중 재분류 간격(장). ⚠️ 재분류마다 장소 경계가 다시 계산돼 행이 흔들린다
    /// (ADR `0011`) — 거슬리면 판정 단위가 아니라 이 값을 먼저 늘린다.
    private let remoteReclassifyEvery = 16

    /// 커널이 사진마다 읽어낸 것. **`assets`와 같은 길이·같은 순서다.**
    private var readings: [PhotoReading] = []

    /// **커널에는 식별자 개념이 없어서** 원본과 잇는 일이 배열을 쥔 이쪽 몫이다.
    func asset(at index: Int) -> SourceAsset? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    /// 그 사진 한 장의 촬영 시각. 순간에 들어간 사진이면 항상 값이 있다 —
    /// 시각을 못 얻은 사진은 애초에 `Classification.unplaced`로 빠진다.
    func capturedAt(at index: Int) -> WallClock? {
        readings.indices.contains(index) ? readings[index].capturedAt : nil
    }

    init(albumTitle: String, settings: Settings = .default) {
        self.source = AlbumPhotoSource(albumTitle: albumTitle)
        self.settings = settings
    }

    // MARK: - 흐름

    /// 아직 도는 것이 없을 때만 시작한다.
    func start() {
        guard task == nil else { return }
        let epoch = beginRun()
        task = Task { [weak self] in
            guard let self else { return }
            if await firstPass(epoch) { await laterPasses(epoch) }
            release(epoch)
        }
    }

    /// `04` 아래로 당기기. 전부 다시 돈다 — `M1`엔 저장이 없어 증분이라는 개념 자체가 없다.
    /// **1패스까지만 기다린다** — 끝까지 기다리면 새로고침 표시가 원격 내내(분 단위) 매달린다.
    func refresh() async {
        let epoch = beginRun()
        guard await firstPass(epoch) else { return }
        task = Task { [weak self] in
            guard let self else { return }
            await laterPasses(epoch)
            release(epoch)
        }
    }

    /// ⚠️ 끝난 실행은 **자리를 비운다** — 안 비우면 `start()`가 영영 no-op이 되어,
    /// 권한을 나중에 허용하고 돌아오는 경로가 조용히 죽는다.
    private func release(_ epoch: Int) {
        guard !isStale(epoch) else { return }
        task = nil
    }

    /// 앞 실행을 무효로 돌리고 새 번호를 낸다.
    private func beginRun() -> Int {
        epoch += 1
        task?.cancel()
        task = nil
        return epoch
    }

    private func isStale(_ epoch: Int) -> Bool { epoch != self.epoch }

    /// ── 1패스 — 전량 열거 후 즉시 분류. **위 계약이 붙는 자리다.**
    /// 목록이 서고 이어서 바이트를 읽을 것이 남았으면 `true`.
    private func firstPass(_ epoch: Int) async -> Bool {
        if isStale(epoch) { return false }
        phase = .enumerating
        progress = 0

        var access = AlbumPhotoSource.currentAccess()
        if !access.canRead { access = await AlbumPhotoSource.requestAccess() }
        if isStale(epoch) { return false }
        guard access.canRead else {
            phase = .blocked("읽기 권한 없음 (\(access))")
            return false
        }

        do {
            assets = try source.assets()
        } catch {
            phase = .blocked("\(error)")
            return false
        }
        inputs = assets.map { PhotoInput(filename: $0.filename) }
        pending = Set(inputs.indices)
        reclassify()
        guard !assets.isEmpty else {
            phase = .ready
            return false
        }
        return true
    }

    private func laterPasses(_ epoch: Int) async {
        if isStale(epoch) { return }

        // ── 2패스 A — 로컬만. "없음" 판정이 6~16ms라 전량을 훑어도 싸다 ──
        phase = .readingLocal
        var remote: [Int] = []
        for index in assets.indices {
            if isStale(epoch) { return }
            if await load(index, epoch: epoch, allowingNetwork: false) == false {
                remote.append(index)
            }
        }
        if isStale(epoch) { return }
        reclassify()

        // ── 2패스 B — 원격. 상한을 넘긴 것은 뒤로 미룬다 ──────────
        guard !remote.isEmpty else {
            finish()
            return
        }
        phase = .readingRemote
        var deferred: [Int] = []
        var since = 0
        for index in remote {
            if isStale(epoch) { return }
            if await load(index, epoch: epoch,
                          allowingNetwork: true, within: remoteTimeout) == false {
                deferred.append(index)
            }
            since += 1
            if since >= remoteReclassifyEvery {
                since = 0
                reclassify()
            }
        }
        if isStale(epoch) { return }
        reclassify()

        // ── 2패스 C — 미뤄둔 것. 상한 없이 ────────────────────────
        for index in deferred {
            if isStale(epoch) { return }
            _ = await load(index, epoch: epoch, allowingNetwork: true)
            reclassify()
        }
        finish()
    }

    /// 한 장의 바이트를 읽어 `inputs`에 채운다. 반환값은 **더 해볼 일이 남았는가**가 아니라
    /// *이번 시도로 결말이 났는가*다 — `false`면 다음 단계로 넘긴다.
    @discardableResult
    private func load(_ index: Int, epoch: Int,
                      allowingNetwork: Bool, within limit: Duration? = nil) async -> Bool {
        do {
            let data = try await withOptionalTimeout(limit) { [source, assets] in
                try await source.originalBytes(of: assets[index], allowingNetwork: allowingNetwork)
            }
            if isStale(epoch) { return true }
            inputs[index] = PhotoInput(filename: assets[index].filename, bytes: [UInt8](data))
            resolve(index)
            return true
        } catch is TimedOut {
            return false
        } catch PhotoSourceError.originalNotOnDevice {
            if isStale(epoch) { return true }
            // 네트워크를 이미 열고도 이 실패면 더 해볼 것이 없다.
            if allowingNetwork { resolve(index) }
            return allowingNetwork
        } catch {
            if isStale(epoch) { return true }
            // 읽기 실패는 바이트 없음과 같은 취급이다 — 커널에 예외 경로가 없다.
            resolve(index)
            return true
        }
    }

    private func resolve(_ index: Int) {
        pending.remove(index)
        progress = assets.isEmpty ? 0 : Double(assets.count - pending.count) / Double(assets.count)
    }

    /// **커널을 부르는 유일한 자리.** 넘기는 것은 언제나 `inputs` 전체다 — ADR `0004` (d).
    private func reclassify() {
        let result = Classifier.classify(inputs, settings: settings)
        days = result.days
        readings = result.readings
        momentCount = result.momentCount
        photoCount = result.photoCount
        generation += 1
    }

    private func finish() {
        phase = .ready
        progress = 1
        // 분류가 끝나면 바이트는 쓸 곳이 없다 — 211장이면 170MB다 (2026-08-03).
        // 재분류에 전량이 동시에 필요하므로 줄일 수 있는 것은 들고 있는 기간뿐이다.
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
        library.readings = classification.readings
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

/// `limit`이 `nil`이면 그냥 기다린다. 진 쪽 작업을 죽이지 않는다 — PhotoKit의 바이트 요청은
/// 취소를 받지 않고, 이미 받은 만큼은 캐시에 남아 다음 시도를 싸게 만든다.
private func withOptionalTimeout<T: Sendable>(
    _ limit: Duration?,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard let limit else { return try await operation() }
    // ⚠️ `TaskGroup`으로 경주하면 상한이 통째로 무력해진다 — 몸통이 나가도 그룹이 남은 자식을
    // 기다리는데 진 쪽이 취소를 안 받는다 (상한 1초·작업 5초에 5.3초, 2026-08-10 실측).
    let work = Task(operation: operation)
    let first = ResumeOnce()
    return try await withCheckedThrowingContinuation { continuation in
        Task {
            let result = await work.result
            if first.claim() { continuation.resume(with: result) }
        }
        Task {
            try? await Task.sleep(for: limit)
            if first.claim() { continuation.resume(throwing: TimedOut()) }
        }
    }
}

/// 먼저 도착한 쪽만 통과시킨다. 두 번째 `resume`은 크래시다.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
