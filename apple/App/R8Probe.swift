// R8 프로브 — 한시적 코드다. 화면 04·05·06이 들어오는 세션에서 지운다.
//
// 재는 것: 리스크 `R8`(PRD §12) — 소스 접근에 성공해도 개별 사진의 원본이 기기에 없을 수 있다.
// 증상(완전 실패 / 지연 / 간헐)이 미확인이라 추측으로 대응책을 쓰지 않기로 했고,
// 사진 프레임워크가 어떻게 실패하는지는 코드 없이 볼 수 없다.
//
// 방법은 두 단계다 —
//   A단계: 네트워크를 막고 전량 로드. 실패 수 = 원본이 기기에 없는 사진 수.
//   B단계: A단계 실패분만 네트워크를 열고 다시. 성공 여부와 걸린 시간이 대응책을 가른다.
//
// 곁다리로 같이 재는 것 — 앨범 식별 방법(무슨 이름·스마트 여부) · 원본 파일명 보존 여부 ·
// 열거 비용 · 바이트가 로컬 원본과 같은지(FNV-1a 대조).

import Foundation
import PhotoSource

/// 소스로 고정한 앨범. 출시 1은 소스를 코드에 고정한다.
/// 어느 이름이 게임 것인지는 App이 알고, 어댑터는 모른다 (ADR 0002 근거 1).
let 게임앨범이름 = "Mabinogi Mobile"

@MainActor
@Observable
final class R8Probe {
    enum Scope: String, CaseIterable, Identifiable {
        case sample = "표본 10장"
        case all = "전량"
        var id: String { rawValue }
        var limit: Int? { self == .sample ? 10 : nil }
    }

    private(set) var isRunning = false
    private(set) var progress = "대기"
    private(set) var report = ""
    private(set) var access = AlbumPhotoSource.currentAccess()

    private var task: Task<Void, Never>?

    func requestAccess() {
        task = Task {
            access = await AlbumPhotoSource.requestAccess()
        }
    }

    func cancel() {
        task?.cancel()
    }

    func run(scope: Scope) {
        guard !isRunning else { return }
        isRunning = true
        report = ""
        task = Task {
            let lines = await probe(scope: scope)
            report = lines.joined(separator: "\n")
            progress = Task.isCancelled ? "중단됨" : "완료"
            isRunning = false
        }
    }

    // MARK: - 본체

    private func probe(scope: Scope) async -> [String] {
        var out: [String] = ["== R8 프로브 ==", "범위: \(scope.rawValue)"]

        access = AlbumPhotoSource.currentAccess()
        if !access.canRead {
            access = await AlbumPhotoSource.requestAccess()
        }
        out.append("권한: \(access)")
        guard access.canRead else {
            out.append("→ 읽기 권한이 없어 여기서 멈춘다.")
            return out
        }

        // ── 앨범 식별 ──────────────────────────────────────────
        progress = "앨범 목록 읽는 중"
        let clock = ContinuousClock()
        var elapsed = clock.now
        let albums = AlbumPhotoSource.albums()
        let albumsSeconds = elapsed.duration(to: clock.now).seconds

        let userAlbums = albums.filter { !$0.isSmart }
        out.append("")
        out.append("-- 앨범 (사용자 \(userAlbums.count) · 스마트 \(albums.count - userAlbums.count) · \(fmt(albumsSeconds))s) --")
        for album in userAlbums.sorted(by: { $0.assetCount > $1.assetCount }) {
            out.append("  [사용자] \(album.title) — \(album.assetCount)")
        }
        for album in albums.filter({ $0.isSmart && $0.assetCount > 0 }).sorted(by: { $0.assetCount > $1.assetCount }).prefix(12) {
            out.append("  [스마트] \(album.title) — \(album.assetCount)")
        }

        // ── 자산 열거 ──────────────────────────────────────────
        progress = "자산 열거 중"
        let source = AlbumPhotoSource(albumTitle: 게임앨범이름)
        elapsed = clock.now
        let assets: [SourceAsset]
        do {
            assets = try source.assets()
        } catch {
            out.append("")
            out.append("자산 열거 실패: \(error)")
            return out
        }
        let enumerateSeconds = elapsed.duration(to: clock.now).seconds

        out.append("")
        out.append("-- 대상 앨범 \"\(게임앨범이름)\" --")
        out.append("  자산 \(assets.count)장 · 열거 \(fmt(enumerateSeconds))s (장당 \(fmt(enumerateSeconds / Double(max(assets.count, 1)) * 1000))ms)")
        out.append("  파일명 형태:")
        for (shape, count) in shapes(of: assets.map(\.filename)) {
            out.append("    \(shape) — \(count)")
        }
        if let first = assets.first, let last = assets.last {
            out.append("  최신: \(first.filename)")
            out.append("  최고(古): \(last.filename)")
        }

        let targets = scope.limit.map { Array(assets.prefix($0)) } ?? assets
        guard !targets.isEmpty else { return out }

        // ── A단계: 네트워크 차단 ────────────────────────────────
        var records = targets.map { Record(asset: $0) }
        elapsed = clock.now
        for index in records.indices {
            if Task.isCancelled { break }
            progress = "A단계 \(index + 1)/\(records.count)"
            await records[index].load(from: source, allowingNetwork: false)
        }
        let phaseASeconds = elapsed.duration(to: clock.now).seconds
        out.append("")
        out.append(contentsOf: summary(
            title: "A단계 — 네트워크 차단 (원본이 기기에 있는가)",
            records: records, keyPath: \.local, total: phaseASeconds
        ))

        // ── B단계: A단계 실패분만 네트워크 허용 ───────────────────
        let retryIndices = records.indices.filter { !records[$0].local.isSuccess }
        if retryIndices.isEmpty {
            out.append("")
            out.append("-- B단계 — 건너뜀 (A단계 실패 0) --")
        } else {
            elapsed = clock.now
            for (order, index) in retryIndices.enumerated() {
                if Task.isCancelled { break }
                progress = "B단계 \(order + 1)/\(retryIndices.count)"
                await records[index].load(from: source, allowingNetwork: true)
            }
            let phaseBSeconds = elapsed.duration(to: clock.now).seconds
            out.append("")
            out.append(contentsOf: summary(
                title: "B단계 — A단계 실패 \(retryIndices.count)장에 네트워크 허용",
                records: retryIndices.map { records[$0] }, keyPath: \.network, total: phaseBSeconds
            ))
        }

        // ── 전체 표 ───────────────────────────────────────────
        out.append("")
        out.append("-- CSV --")
        out.append("filename,bytes,a_ms,a_result,b_ms,b_result,fnv1a")
        out.append(contentsOf: records.map(\.csv))
        return out
    }

    // MARK: - 요약

    private func summary(
        title: String,
        records: [Record],
        keyPath: KeyPath<Record, Attempt>,
        total: Double
    ) -> [String] {
        let attempts = records.map { $0[keyPath: keyPath] }
        let done = attempts.filter { !$0.isPending }
        var out = ["-- \(title) --"]
        out.append("  총 \(fmt(total))s · 시도 \(done.count)/\(records.count)")

        var tally: [String: Int] = [:]
        for attempt in done { tally[attempt.label, default: 0] += 1 }
        for (label, count) in tally.sorted(by: { $0.value > $1.value }) {
            out.append("  \(label): \(count)")
        }

        let millis = done.compactMap(\.millis).sorted()
        if !millis.isEmpty {
            let median = millis[millis.count / 2]
            out.append("  장당 — 중앙 \(fmt(median))ms · 최소 \(fmt(millis[0]))ms · 최대 \(fmt(millis[millis.count - 1]))ms")
        }
        let sizes = done.compactMap(\.bytes)
        if !sizes.isEmpty {
            out.append("  크기 — 합 \(sizes.reduce(0, +) / 1_048_576)MB · 최대 \(sizes.max()! / 1024)KB")
        }
        for record in records where record[keyPath: keyPath].isFailure {
            out.append("  ✗ \(record.asset.filename) — \(record[keyPath: keyPath].label)")
        }
        return out
    }

    /// 파일명에서 숫자를 제거해 형태만 남긴다. 원본 이름이 보존됐는지, iOS가 갈아치웠는지를 본다.
    private func shapes(of filenames: [String]) -> [(String, Int)] {
        var tally: [String: Int] = [:]
        for name in filenames {
            let shape = String(name.map { $0.isNumber ? "#" : $0 })
                .replacingOccurrences(of: "#+", with: "#", options: .regularExpression)
            tally[shape, default: 0] += 1
        }
        return tally.sorted { $0.value > $1.value }
    }
}

// MARK: - 한 장의 기록

@MainActor
private struct Record {
    let asset: SourceAsset
    var local = Attempt.pending
    var network = Attempt.pending

    init(asset: SourceAsset) { self.asset = asset }

    mutating func load(from source: AlbumPhotoSource, allowingNetwork: Bool) async {
        let clock = ContinuousClock()
        let start = clock.now
        let attempt: Attempt
        do {
            let data = try await source.originalBytes(of: asset, allowingNetwork: allowingNetwork)
            let millis = start.duration(to: clock.now).seconds * 1000
            attempt = .loaded(millis: millis, bytes: data.count, hash: fnv1a(data))
        } catch let error as PhotoSourceError {
            let millis = start.duration(to: clock.now).seconds * 1000
            attempt = error == .originalNotOnDevice(assetID: asset.id)
                ? .notOnDevice(millis: millis)
                : .failed(millis: millis, reason: "\(error)")
        } catch {
            attempt = .failed(millis: start.duration(to: clock.now).seconds * 1000, reason: "\(error)")
        }
        if allowingNetwork { network = attempt } else { local = attempt }
    }

    var csv: String {
        let bytes = local.bytes ?? network.bytes
        let hash = local.hash ?? network.hash
        return [
            asset.filename,
            bytes.map(String.init) ?? "",
            local.millis.map { fmt($0) } ?? "",
            local.label,
            network.millis.map { fmt($0) } ?? "",
            network.isPending ? "" : network.label,
            hash.map { String($0, radix: 16) } ?? "",
        ].joined(separator: ",")
    }
}

private enum Attempt {
    case pending
    case loaded(millis: Double, bytes: Int, hash: UInt64)
    /// R8이 실제로 일어난 자리.
    case notOnDevice(millis: Double)
    case failed(millis: Double, reason: String)

    var isPending: Bool { if case .pending = self { true } else { false } }
    var isSuccess: Bool { if case .loaded = self { true } else { false } }
    var isFailure: Bool { !isPending && !isSuccess }

    var millis: Double? {
        switch self {
        case .pending: nil
        case .loaded(let millis, _, _), .notOnDevice(let millis), .failed(let millis, _): millis
        }
    }

    var bytes: Int? { if case .loaded(_, let bytes, _) = self { bytes } else { nil } }
    var hash: UInt64? { if case .loaded(_, _, let hash) = self { hash } else { nil } }

    var label: String {
        switch self {
        case .pending: "미시도"
        case .loaded: "ok"
        case .notOnDevice: "기기에없음(R8)"
        case .failed(_, let reason): "실패: \(reason)"
        }
    }
}

// MARK: - 잡동사니

/// 바이트가 로컬에 있는 원본과 같은지 대조하기 위한 값. 암호학적 성질은 필요 없다.
private func fnv1a(_ data: Data) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    data.withUnsafeBytes { raw in
        for byte in raw { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
    }
    return hash
}

private func fmt(_ value: Double) -> String {
    String(format: "%.1f", value)
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
