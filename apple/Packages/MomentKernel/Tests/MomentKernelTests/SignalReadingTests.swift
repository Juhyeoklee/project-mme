import Testing
@testable import MomentKernel

@Suite("바이트 읽기")
struct SignalReadingTests {

    private func read(_ bytes: [UInt8]?, name: String = "x_2026080210211445.png") -> PhotoReading {
        SignalReader.read(PhotoInput(filename: name, bytes: bytes))
    }

    @Test func 정상_촬영본에서_신호_넷을_꺼낸다() {
        let reading = read(PNGFixture.capture(
            width: 1600, height: 738, zone: "티르코네일",
            cameraPosition: (-40.77181, 50.41731, -40.99361),
            cameraRotation: (21.54319, 45.90538, 0),
            fieldOfView: 62.97325))
        #expect(reading.signalStatus == .ok)
        let signals = try! #require(reading.signals)
        #expect(signals.zoneName == "티르코네일")
        #expect(signals.cameraPosition == Vector3(x: -40.77181, y: 50.41731, z: -40.99361))
        #expect(signals.cameraRotation == Vector3(x: 21.54319, y: 45.90538, z: 0))
        #expect(signals.fieldOfView == 62.97325)
        #expect(signals.pixelWidth == 1600)
        #expect(signals.pixelHeight == 738)
    }

    @Test func 쓰지_않는_필드가_섞여_있어도_읽는다() {
        // 게임은 10개를 써넣는다. 커널이 쓰는 것은 4개고 나머지는 지나친다.
        let reading = read(PNGFixture.capture(extraText: [
            ("Author", "이모모쨩"),
            ("Erinn Time", "16 : 59"),
            ("Real Time", "2026-08-02 10:21:14"),
            ("Character Location", "<-36.61901, 47.02017, -36.97002>"),
            ("Character Direction", "219.9782"),
            ("Build Version", "3.1.50011.399"),
        ]))
        #expect(reading.signalStatus == .ok)
    }

    @Test func iTXt가_IDAT_뒤에_있어도_찾는다() {
        let bytes = PNGFixture.png(width: 100, height: 50, text: [
            ("Location Display Name", "던바튼"),
            ("Camera Position", "<1, 2, 3>"),
            ("Camera Rotation", "<0, 0, 0>"),
            ("Camera Fov Degree", "62.9"),
        ], textAfterIDAT: true)
        #expect(read(bytes).signalStatus == .ok)
    }

    @Test func 실물이_쓰는_종료_NUL을_떼어낸다() {
        // 규격상 `iTXt` 텍스트는 청크 끝까지고 종료자가 없다. 그런데 게임은 NUL을 하나 더
        // 쓴다(표본 211/211). 안 떼면 값 끝이 `>` 가 아니라 좌표 파싱이 통째로 실패한다.
        // **합성 픽스처만으로는 못 잡았던 자리다** — 실물 대조로 잡혔다 (2026-08-03).
        let bytes = PNGFixture.png(width: 100, height: 50, text: [
            ("Location Display Name", "반호르"),
            ("Camera Position", "<-7.285239, 12.22528, -87.03957>"),
            ("Camera Rotation", "<0, 0, 0>"),
            ("Camera Fov Degree", "62.9"),
        ], gameStyle: true)
        let reading = read(bytes)
        #expect(reading.signalStatus == .ok)
        #expect(reading.signals?.zoneName == "반호르")   // 값에 NUL이 남으면 안 된다
        #expect(reading.signals?.cameraPosition
                == Vector3(x: -7.285239, y: 12.22528, z: -87.03957))
    }

    @Test func 규격_그대로인_iTXt도_읽는다() {
        // 종료 NUL이 없고 번역된 키워드가 비어 있는 형태.
        let bytes = PNGFixture.png(width: 100, height: 50, text: [
            ("Location Display Name", "던바튼"),
            ("Camera Position", "<1, 2, 3>"),
            ("Camera Rotation", "<0, 0, 0>"),
            ("Camera Fov Degree", "62.9"),
        ], gameStyle: false)
        let reading = read(bytes)
        #expect(reading.signalStatus == .ok)
        #expect(reading.signals?.zoneName == "던바튼")
    }

    @Test func 바이트를_안_넘기면_실패가_아니라_아직이다() {
        let reading = read(nil)
        #expect(reading.signalStatus == .bytesNotProvided)
        #expect(reading.signals == nil)
        #expect(reading.capturedAt != nil)   // 시각은 파일명에서 온다 — 독립이다
    }

    @Test func PNG가_아니면_notPNG() {
        #expect(read(Array("이건 PNG가 아니다".utf8)).signalStatus == .notPNG)
        #expect(read([]).signalStatus == .notPNG)
    }

    @Test func 잘린_파일은_malformedPNG() {
        let full = PNGFixture.capture()
        #expect(read(Array(full[0..<(full.count / 2)])).signalStatus == .malformedPNG)
        #expect(read(Array(full[0..<9])).signalStatus == .malformedPNG)
    }

    @Test func 길이_필드가_거짓이어도_죽지_않는다() {
        var bytes = PNGFixture.capture()
        // IHDR 청크의 길이를 터무니없이 크게 바꾼다.
        bytes[8] = 0x7F; bytes[9] = 0xFF; bytes[10] = 0xFF; bytes[11] = 0xFF
        #expect(read(bytes).signalStatus == .malformedPNG)
    }

    @Test func iTXt가_하나도_없으면_textChunkMissing() {
        let bytes = PNGFixture.png(width: 10, height: 10, text: [])
        #expect(read(bytes).signalStatus == .textChunkMissing)
    }

    @Test func 압축된_iTXt는_풀지_않고_상태로_보고한다() {
        // ADR 0002 대가 2 — zlib은 import 0을 깬다. 만나면 새 결정이 필요하다.
        let bytes = PNGFixture.capture(compressedKeys: ["Location Display Name",
                                                        "Camera Position",
                                                        "Camera Rotation",
                                                        "Camera Fov Degree"])
        #expect(read(bytes).signalStatus == .textChunkCompressed)
    }

    @Test func 필요한_값_하나만_압축돼_있어도_textChunkCompressed() {
        let bytes = PNGFixture.capture(compressedKeys: ["Camera Position"])
        #expect(read(bytes).signalStatus == .textChunkCompressed)
    }

    @Test func 필드가_빠지면_어떤_필드인지_말한다() {
        let bytes = PNGFixture.capture(omitting: ["Camera Rotation"])
        #expect(read(bytes).signalStatus == .fieldMissing("Camera Rotation"))
    }

    @Test(arguments: ["<1, 2>", "<1, 2, 3, 4>", "1, 2, 3", "<1, 2, x>", "<>", ""])
    func 벡터가_깨지면_fieldUnparsable(_ broken: String) {
        let bytes = PNGFixture.capture(extraText: [("Camera Position", broken)],
                                       omitting: ["Camera Position"])
        #expect(read(bytes).signalStatus == .fieldUnparsable("Camera Position"))
    }

    @Test func 화각이_숫자가_아니면_fieldUnparsable() {
        let bytes = PNGFixture.capture(extraText: [("Camera Fov Degree", "넓음")],
                                       omitting: ["Camera Fov Degree"])
        #expect(read(bytes).signalStatus == .fieldUnparsable("Camera Fov Degree"))
    }

    @Test func 시각과_신호는_서로를_막지_않는다() {
        // 이름은 못 읽는데 바이트는 멀쩡한 경우.
        let reading = read(PNGFixture.capture(), name: "이름이없다.png")
        #expect(reading.capturedAt == nil)
        #expect(reading.signalStatus == .ok)
        #expect(reading.signals != nil)
    }

    @Test func 벡터_공백을_가리지_않는다() {
        #expect(Vector3.parse("<1,2,3>") == Vector3(x: 1, y: 2, z: 3))
        #expect(Vector3.parse("  < 1 ,  2 , 3 >  ") == Vector3(x: 1, y: 2, z: 3))
        #expect(Vector3.parse("<-0.5, 1e2, +3>") == Vector3(x: -0.5, y: 100, z: 3))
    }

    @Test func 각도_거리가_360도를_접는다() {
        let a = Vector3(x: 0, y: 359, z: 0)
        let b = Vector3(x: 0, y: 1, z: 0)
        #expect(a.angularDistance(to: b) == 2)
        #expect(b.angularDistance(to: a) == 2)
        #expect(Vector3(x: 0, y: 0, z: 0).angularDistance(to: Vector3(x: 0, y: 180, z: 0)) == 180)
        // 접지 않으면 358이 나오는 자리다.
        #expect(a.distance(to: b) == 358)
    }

    @Test func 종횡비_비교가_정수로_정확하다() {
        func signals(_ w: Int, _ h: Int) -> CaptureSignals {
            CaptureSignals(zoneName: "z", cameraPosition: Vector3(x: 0, y: 0, z: 0),
                           cameraRotation: Vector3(x: 0, y: 0, z: 0), fieldOfView: 60,
                           pixelWidth: w, pixelHeight: h)
        }
        #expect(signals(1600, 738).hasSameAspectRatio(as: signals(3200, 1476)))
        #expect(!signals(1600, 738).hasSameAspectRatio(as: signals(738, 1600)))
    }
}
