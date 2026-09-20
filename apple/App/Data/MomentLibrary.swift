// 오케스트레이션 — 두 패키지를 잇는 유일한 자리다. 커널은 I/O를 모르고 어댑터는 분류를 모른다.

import Foundation
import MomentKernel
import PhotoSource

/// 앨범을 읽어 분류 결과를 화면에 내주는 오케스트레이터. 화면이 보는 상태는 여기 다 있다.
///
/// 진행 중에도 `days`는 항상 완결된 분류 결과다 — 2패스가 도는 동안 장소 경계만 다시 계산된다.
/// 패스를 가른 것은 열거가 212장 1.4초인데 원본 한 장이 441초까지 가기 때문이다
/// (`R8`).
///
/// ⚠️ **손으로 지켜야 하는 계약 하나 — 기계가 못 막는다.** 1패스에
/// 자산을 *전량 열거해 전부* 넘긴다 — 일부만 넘기면 **시간 경계의 불변마저 사라진다.**
/// 커널을 부르는 곳은 `reclassify()` 하나뿐이고 **넘기는 배열은 항상 `inputs` 전체다 —
/// 부분 배열을 넘기는 경로를 만들지 마라.**
@MainActor
@Observable
final class MomentLibrary {
    /// 진행 단계. 화면이 보는 것은 진행바 하나뿐이고(`04-A1`) 이 구분은 여기 안에서만 쓰인다.
    enum Phase: Equatable {
        case idle
        /// 읽을 앨범이 없다 — 아직 안 골랐거나 고른 것이 사라졌다 (`SRC-02`).
        /// **권한과 무관하다**, 그래서 `blocked`와 갈라 둔다.
        case needsSource
        /// 열거 중 — 1.4초라 대개 안 보인다.
        case enumerating
        case readingLocal
        /// 원격 받아오기 — **여기가 분 단위다.**
        case readingRemote
        case ready
        /// 읽기 권한이 없다. 이유 문자열은 개발 중에 보려고 들고만 있다.
        case blocked(String)

        var isWorking: Bool {
            switch self {
            case .enumerating, .readingLocal, .readingRemote: true
            case .idle, .needsSource, .ready, .blocked: false
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
    /// 재분류할 때마다 오른다. **썸네일 재시도의 방아쇠다** — 실패를 캐시하지 않는 대신
    /// 이 값으로 다시 묻는다.
    private(set) var generation = 0
    /// 소스의 구성이 바뀐 횟수 (`SRC-03`). **`generation`과 다르다** — 이쪽은 사진이 들고
    /// 난 것만 세고, 2패스가 바이트를 채우며 돌리는 재분류에는 안 오른다.
    /// **`02`가 떠 있는 채로 사진이 늘면 후보를 다시 읽는 방아쇠다.**
    private(set) var sourceRevision = 0

    // MARK: - 안쪽

    /// 커널 인덱스 ↔ 자산. **`inputs`와 같은 길이·같은 순서다** — 이 대응이 깨지면 전부 어긋난다.
    ///
    /// ⚠️ **첨자는 이 배열 안에서만 뜻이 있고 소스가 바뀌면 다시 선다** (`SRC-03`). 자산은
    /// 최신순이라 새 사진이 앞에 붙으면 뒤가 전부 밀린다 — 화면이 사진 하나를 재분류 너머로
    /// 붙들려면 첨자가 아니라 **식별자**로 붙들고 `index(of:)`로 되묻어야 한다.
    private(set) var assets: [SourceAsset] = []
    private var inputs: [PhotoInput] = []
    /// 바이트를 읽을 사진 — **파일명에서 시각을 얻은 것만이다.** 날짜만 가진 사진은 장소
    /// 분할에도 연사 접기에도 못 들어가 그 바이트가 결과를 못 바꾸므로, 안 읽어야
    /// `R8`의 원격 대기(한 장 상한 20초)를 **쓸 데 없는 사진 수만큼** 안 문다.
    private var byteCandidates: [Int] = []
    /// 바이트를 아직 못 정한 사진. 진행률의 분모는 `byteCandidates`다.
    private var pending: Set<Int> = []
    /// 끝내 원본을 못 받은 사진 (`R8`). **`05`가 이 값으로 표시를 세운다.**
    private(set) var missingOriginals: Set<Int> = []

    /// 지금 소스를 읽는 어댑터. ⚠️ **원본 바이트와 썸네일도 이것을 본다** — 인스턴스가
    /// 하나라야 소스를 바꾼 뒤에 낡은 앨범을 든 사본이 남지 않는다.
    private(set) var source: AlbumPhotoSource
    /// 자산 식별자 → 첨자. `assets`와 함께 선다.
    private var indexByAssetID: [String: Int] = [:]
    /// 마지막으로 읽은 소스의 식별자 목록. **`assets`에서 못 얻는다** — 이름을 못 얻은 사진이
    /// `assets`에서만 빠져 두 목록의 길이가 다를 수 있다. 대조가 그 차이에 걸리면
    /// 무관한 변경마다 전량 재실행이 된다.
    private var lastSourceIDs: [String] = []

    /// 라이브러리 변경을 알려주는 파수꾼 (`SRC-03`). **`start()`가 처음 걸고 그 뒤로 산다.**
    private var watch: SourceWatch?
    /// 몰려 오는 통지를 묶는 자리.
    private var settleTask: Task<Void, Never>?
    /// 통지가 그친 것으로 치는 시간. 게임 스크린샷은 연사로 들어오고 라이브러리는 **장마다**
    /// 통지한다 — 낱개로 받으면 한 연사에 재분류가 수십 번 돈다.
    private let changeSettle: Duration = .milliseconds(400)

    private let settings: Settings
    private var task: Task<Void, Never>?
    /// 지금 유효한 실행의 번호. ⚠️ **취소만으로는 앞 실행의 쓰기를 못 막는다** — PhotoKit의
    /// 바이트 요청이 취소를 안 받아, 죽은 실행이 `await`에서 되살아나 새 배열에 쓴다.
    private var epoch = 0

    /// 원격 한 장에 거는 상한. 중앙 1.7초, 최악 441초.
    /// 넘겨도 다운로드는 안 죽는다 — 버리는 것은 결과지 일이 아니다.
    private let remoteTimeout: Duration = .seconds(20)
    /// 원격 도중 재분류 간격(장). ⚠️ 재분류마다 장소 경계가 다시 계산돼 행이 흔들린다
    /// — 거슬리면 판정 단위가 아니라 이 값을 먼저 늘린다.
    private let remoteReclassifyEvery = 16

    /// 커널이 사진마다 읽어낸 것. **`assets`와 같은 길이·같은 순서다.**
    private var readings: [PhotoReading] = []

    private let slowSource = SlowSource.current

    /// `R8`을 실물에서 보는 유일한 문 — 원본이 로컬이면 그 경로를 한 번도 못 밟는다.
    /// `-slowsource`는 기다리게 하고, `-slowsource fail`은 전부 못 받게 한다.
    private enum SlowSource {
        case off
        /// 한 장에 `delay`씩 기다렸다 받아온다 — 기다리는 동안의 화면을 본다.
        case slow
        /// 전부 실패한다 — 원격 전량 실패의 **끝**을 본다.
        case failing

        /// 한 장에 거는 지연. **모드마다 다르다** — `slow`는 실측 중앙 1.7초에 맞추고(212장이면
        /// 6분이라 기다림 자체가 관측 대상이다), `failing`은 **끝**을 보는 것이 목적이라 짧다.
        var delay: Duration {
            switch self {
            case .off: .zero
            case .slow: .seconds(2)
            case .failing: .milliseconds(50)
            }
        }

        static var current: SlowSource {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("-slowsource") else { return .off }
            return arguments.contains("fail") ? .failing : .slow
            #else
            .off
            #endif
        }

        var isOn: Bool { self != .off }
    }

    /// **커널에는 식별자 개념이 없어서** 원본과 잇는 일이 배열을 쥔 이쪽 몫이다.
    func asset(at index: Int) -> SourceAsset? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    /// 그 자산이 지금 몇 번째인가. 없으면 `nil` — 소스에서 사라진 사진이다.
    ///
    /// **`asset(at:)`의 반대 방향이고, 있는 이유가 다르다** — 이쪽은 첨자가 다시 서는 것을
    /// 건너뛰려고 있다. 화면이 고른 사진을 재분류 너머로 잇는 유일한 길이다.
    func index(of assetID: String) -> Int? { indexByAssetID[assetID] }

    /// 그 사진 한 장의 촬영 시각. 순간에 들어간 사진이면 항상 값이 있다 —
    /// 시각을 못 얻은 사진은 애초에 `Classification.unplaced`로 빠진다.
    func capturedAt(at index: Int) -> WallClock? {
        readings.indices.contains(index) ? readings[index].capturedAt : nil
    }

    /// 사용자가 고른 앨범 (`SRC-01`). `nil`이면 소스 미지정이다.
    private(set) var albumID: String?
    /// 그 앨범의 **지금** 이름. `13`이 값으로 보인다.
    /// ⚠️ **저장하지 않고 매번 읽는다** — 사용자가 사진 앱에서 이름을 바꾸면 따라가야 한다.
    private(set) var sourceName: String?

    init(albumID: String?, settings: Settings = .default) {
        self.albumID = albumID
        // ⚠️ 소스가 없으면 빈 식별자다 — 어댑터에 앨범을 묻는 두 경로(`assets()` · `title()`)를
        // `firstPass`의 이른 `guard`가 막는다. 그 밖의 경로는 앨범을 안 본다.
        self.source = AlbumPhotoSource(albumID: albumID ?? "")
        self.settings = settings
    }

    // MARK: - 흐름

    /// 소스를 갈아 끼운다 (`SRC-04`). **거는 것까지만 한다** — 시작은 부르는 쪽이 한다.
    func use(albumID: String?) {
        guard albumID != self.albumID else { return }
        self.albumID = albumID
        source = AlbumPhotoSource(albumID: albumID ?? "")
        // 앞 실행을 무효로 돌리고 자리를 비운다 — 안 그러면 죽은 실행이 새 앨범의 배열에 쓴다.
        _ = beginRun()
        clear()
    }

    /// 앞 소스의 결과를 지운다. ⚠️ **`generation`은 올린다** — 썸네일이 옛 자산을 붙들고 있다.
    private func clear() {
        days = []
        assets = []
        indexByAssetID = [:]
        lastSourceIDs = []
        inputs = []
        readings = []
        byteCandidates = []
        pending = []
        missingOriginals = []
        momentCount = 0
        photoCount = 0
        progress = 0
        sourceName = nil
        phase = .idle
        generation += 1
    }

    /// 아직 도는 것이 없을 때만 시작한다.
    func start() {
        watchSource()
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

    // MARK: - 소스가 바뀐다 (`SRC-03`)

    /// 파수꾼을 건다. **`start()`가 부를 때마다 다시 시도한다** — 첫 호출은 권한을 묻기 전이라
    /// 조용히 안 걸리고, 권한을 얻고 돌아오는 경로가 같은 문으로 다시 들어온다.
    private func watchSource() {
        if watch == nil {
            watch = SourceWatch { [weak self] in
                // ⚠️ 통지가 오는 큐는 보장이 없다 — 주 액터로 건너온다.
                Task { @MainActor in
                    // 문이 둘이라 **어느 쪽이 일했는지 로그로만 갈린다** — 파수꾼이 죽어도
                    // 복귀 문이 가려 주어, 안 보고 지나가면 절반이 죽은 채로 산다.
                    self?.probeSource("파수꾼")
                    self?.sourceMayHaveChanged()
                }
            }
        }
        watch?.start()
    }

    /// 소스가 바뀌었을 수 있다는 신호. **파수꾼과 포그라운드 복귀가 같은 문으로 들어온다** —
    /// 앱이 잠든 동안의 변경은 통지가 늦거나 안 오므로 문이 둘이라야 한다.
    ///
    /// **바뀌었는지는 여기서 안 본다.** 통지가 그치기를 기다렸다가 한 번만 대조한다.
    func sourceMayHaveChanged() {
        settleTask?.cancel()
        let settle = changeSettle
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled else { return }
            await self?.reloadIfChanged()
        }
    }

    /// 정말 바뀌었을 때만 다시 돈다. **라이브러리는 무엇이 바뀌었는지 안 가리고 통지한다** —
    /// 대조 없이 돌면 다른 앨범에서 사진 한 장을 지워도 우리 목록이 통째로 다시 선다.
    ///
    /// ⚠️ **증분이 아니라 전량 재실행이다** — `finish()`가 바이트를 버려서(211장 170MB)
    /// 새 사진 한 장만 읽어 얹을 수가 없다. 1패스가 1.4초라 목록은 곧 다시 선다.
    private func reloadIfChanged() async {
        let access = AlbumPhotoSource.currentAccess()
        guard access.canRead else { return }
        do {
            let current = access == .limited
                ? try AlbumPhotoSource.permittedAssetIDs()
                : try source.assetIDs()
            guard current != lastSourceIDs else { return }
        } catch {
            // 앨범이 사라졌거나 권한이 막혔다. 그 판정은 `firstPass`의 것이라 그대로 넘긴다.
        }
        sourceRevision += 1
        await refresh()
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
        // ⚠️ **여기서 권한을 요청하지 않는다** — `SRC-07`이 요청 **전에** 설명을 요구하고
        // 그 설명이 `01`이다. 분류는 묻기만 한다.
        let access = AlbumPhotoSource.currentAccess()
        guard access.canRead else {
            phase = .blocked("읽기 권한 없음 (\(access))")
            return false
        }
        // 부분 접근에는 앨범이 없다 — 고를 것이 없으므로 「미지정」이라는 상태도 없다.
        guard access == .limited || albumID != nil else {
            phase = .needsSource
            return false
        }
        phase = .enumerating
        progress = 0

        do {
            // ⚠️ **식별자를 먼저 읽는다** — 두 열거 사이에 사진이 들어오면 순서가 결말을 가른다.
            // 이 순서면 목록에만 든 사진이 생겨 다음 대조가 한 번 헛돌 뿐이지만, 뒤집으면
            // **대조가 「안 바뀌었다」고 답해 그 사진이 영영 안 들어온다.**
            if access == .limited {
                lastSourceIDs = try AlbumPhotoSource.permittedAssetIDs()
                assets = try AlbumPhotoSource.permittedAssets()
                sourceName = nil
            } else {
                lastSourceIDs = try source.assetIDs()
                assets = try source.assets()
                sourceName = try source.title()
            }
            indexByAssetID = Dictionary(assets.enumerated().map { ($1.id, $0) },
                                        uniquingKeysWith: { first, _ in first })
        } catch PhotoSourceError.albumNotFound {
            // 고른 앨범이 사라졌다. **저장은 안 지운다** — 앨범이 돌아오면 그대로 산다.
            phase = .needsSource
            return false
        } catch {
            phase = .blocked("\(error)")
            return false
        }
        inputs = assets.map(Self.input(from:))
        missingOriginals = []
        reclassify()
        // 시각을 얻었는지는 커널이 판정한다 — 파일명 규칙을 이쪽이 다시 알면 출처가 둘이 된다.
        byteCandidates = readings.indices.filter { readings[$0].capturedAt != nil }
        pending = Set(byteCandidates)
        probeSource("1패스")
        guard !byteCandidates.isEmpty else {
            finish()
            return false
        }
        return true
    }

    private func laterPasses(_ epoch: Int) async {
        if isStale(epoch) { return }

        // ── 2패스 A — 로컬만. "없음" 판정이 6~16ms라 전량을 훑어도 싸다 ──
        phase = .readingLocal
        var remote: [Int] = []
        // 문이 열려 있으면 로컬 판정을 건너뛴다 — 원본이 다 로컬인 기기에서는 그래야 원격을 밟는다.
        if slowSource.isOn {
            remote = byteCandidates
        } else {
            for index in byteCandidates {
                if isStale(epoch) { return }
                if await load(index, epoch: epoch, allowingNetwork: false) == false {
                    remote.append(index)
                }
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
            let data = try await withOptionalTimeout(limit) { [source, assets, slowSource] in
                if slowSource.isOn, allowingNetwork {
                    try await Task.sleep(for: slowSource.delay)
                    if case .failing = slowSource {
                        throw PhotoSourceError.originalNotOnDevice(assetID: assets[index].id)
                    }
                }
                return try await source.originalBytes(of: assets[index],
                                                      allowingNetwork: allowingNetwork)
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
            if allowingNetwork { miss(index) }
            return allowingNetwork
        } catch {
            if isStale(epoch) { return true }
            // 읽기 실패는 바이트 없음과 같은 취급이다 — 커널에 예외 경로가 없다.
            miss(index)
            return true
        }
    }

    /// 결말은 났는데 바이트는 못 받은 자리.
    private func miss(_ index: Int) {
        missingOriginals.insert(index)
        resolve(index)
    }

    /// `05`가 묻는다 — 이 묶음에 원본을 못 받은 사진이 몇 장인가.
    func missingOriginalCount(in photoIndices: [Int]) -> Int {
        missingOriginals.isEmpty ? 0 : photoIndices.count { missingOriginals.contains($0) }
    }

    private func resolve(_ index: Int) {
        pending.remove(index)
        let total = byteCandidates.count
        progress = total == 0 ? 1 : Double(total - pending.count) / Double(total)
    }

    /// ⚠️ **`-sourceprobe`로만 켠다** — 소스마다 어느 층에서 끊기는지 본다.
    /// **한 줄이 기준선 표의 한 행이다** — 사람이 그대로 옮겨 적으므로 열을 함부로 바꾸지 않는다.
    private func probeSource(_ stage: String) {
        #if DEBUG
        // 시각은 파일명에서 오므로 이름 규칙이 안 맞으면 사진이 시간축에 아예 안 놓인다.
        guard ProcessInfo.processInfo.arguments.contains("-sourceprobe") else { return }
        let timed = readings.count { $0.capturedAt != nil }
        let signalled = readings.count { $0.signals != nil }
        let scenes = days.reduce(0) { $0 + $1.moments.reduce(0) { $0 + $1.sceneCount } }
        let folded = days.reduce(0) {
            $0 + $1.moments.reduce(0) { $0 + $1.scenes.count { $0.isFolded } }
        }
        let dateOnly = days.reduce(0) { $0 + $1.dateOnlyPhotos.count }
        NSLog("[소스탐침·\(stage)] \(sourceName ?? "이름없음") · 사진 \(assets.count) · "
              + "신호 \(signalled) · 시각없음 \(assets.count - timed) · 날짜만 \(dateOnly) · "
              + "날짜 \(days.count) · 순간 \(momentCount) · 장면 \(scenes) · 접힌장면 \(folded) · "
              + "바이트대상 \(byteCandidates.count)")
        guard stage == "1패스" else { return }
        for (index, reading) in readings.enumerated().prefix(6) {
            NSLog("[소스탐침] \(assets[index].filename) → 시각 "
                  + "\(reading.capturedAt.map { "\($0.month)/\($0.day) \($0.hour):\($0.minute)" } ?? "없음")"
                  + " · 신호 \(reading.signalStatus)")
        }
        #endif
    }

    /// 자산 하나를 커널 입력으로 꾼다. **바이트는 여기서 안 붙는다** — 2패스가 채운다.
    ///
    /// ⚠️ **커널 입력값의 생산 과정도 계약이다.** 라이브러리가 주는 절대 시각을
    /// **기기의 현재 달력·시간대로** 달력 날짜로 꾼다 — `MOM-07`이 기기를 타도록
    /// 허용한 유일한 자리고, 다른 언어 구현은 이 과정까지 재현해야 한다.
    private static func input(from asset: SourceAsset) -> PhotoInput {
        PhotoInput(filename: asset.filename, calendarDay: asset.creationDate.map { date in
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            return CalendarDay(year: parts.year!, month: parts.month!, day: parts.day!)
        })
    }

    /// **커널을 부르는 유일한 자리.** 넘기는 것은 언제나 `inputs` 전체다.
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
        probeSource("끝")
        // 분류가 끝나면 바이트는 쓸 곳이 없다 — 211장이면 170MB다.
        // 재분류에 전량이 동시에 필요하므로 줄일 수 있는 것은 들고 있는 기간뿐이다.
        inputs = assets.map(Self.input(from:))
    }
}

#if DEBUG
extension MomentLibrary {
    /// 프리뷰용 — 라이브러리를 건드리지 않고 결과만 얹는다.
    static func preview(_ classification: Classification,
                        assets: [SourceAsset],
                        phase: Phase = .ready,
                        progress: Double = 1) -> MomentLibrary {
        let library = MomentLibrary(albumID: "preview")
        library.sourceName = "합성 앨범"
        library.assets = assets
        library.indexByAssetID = Dictionary(assets.enumerated().map { ($1.id, $0) },
                                            uniquingKeysWith: { first, _ in first })
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

/// 고른 소스의 저장 키. **식별자 하나만 저장한다** — 이름까지 저장하면 사용자가 앨범
/// 이름을 바꿨을 때 두 벌 중 한쪽만 낡는다.
enum SourceStorage {
    static let albumKey = "source.albumID"
}

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
    // 기다리는데 진 쪽이 취소를 안 받는다 (상한 1초·작업 5초에 5.3초).
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
