// 사진 라이브러리 없이 확인할 수 있는 것만 여기 있다.
// 앨범 찾기·자산 열거·원본 로드는 실기기의 라이브러리가 있어야 답이 나오고, 그 판정은 R8 프로브가 한다.

import Foundation
import Photos
import Testing
@testable import PhotoSource

@Test func 권한이_없으면_자산을_열거하지_않는다() {
    for access in [ReadAccess.notDetermined, .restricted, .denied] {
        #expect(access.canRead == false)
    }
    for access in [ReadAccess.authorized, .limited] {
        #expect(access.canRead == true)
    }
}

@Test func 권한_상태가_빠짐없이_옮겨진다() {
    #expect(ReadAccess(PHAuthorizationStatus.notDetermined) == .notDetermined)
    #expect(ReadAccess(PHAuthorizationStatus.restricted) == .restricted)
    #expect(ReadAccess(PHAuthorizationStatus.denied) == .denied)
    #expect(ReadAccess(PHAuthorizationStatus.authorized) == .authorized)
    #expect(ReadAccess(PHAuthorizationStatus.limited) == .limited)
}

@Test func 원본이_기기에_없는_실패는_R8로_갈린다() {
    let networkRequired = NSError(
        domain: PHPhotosError.errorDomain,
        code: PHPhotosError.Code.networkAccessRequired.rawValue
    )
    #expect(AlbumPhotoSource.mapped(networkRequired, assetID: "A") == .originalNotOnDevice(assetID: "A"))
}

@Test func 그_밖의_실패는_원문을_들고_온다() {
    let other = NSError(domain: "com.example", code: 42, userInfo: [NSLocalizedDescriptionKey: "무언가"])
    let mapped = AlbumPhotoSource.mapped(other, assetID: "B")
    guard case .loadFailed(let assetID, let reason) = mapped else {
        Issue.record("loadFailed가 아니다: \(mapped)")
        return
    }
    #expect(assetID == "B")
    #expect(reason.contains("com.example"))
    #expect(reason.contains("42"))
    #expect(reason.contains("무언가"))
}

@Test func 조각으로_도착한_바이트가_순서대로_모인다() {
    let sink = ByteSink()
    sink.append(Data([0x89, 0x50]))
    sink.append(Data([0x4E, 0x47]))
    #expect(sink.take() == Data([0x89, 0x50, 0x4E, 0x47]))
    // 한 번 꺼내면 비어야 한다 — 다음 사진의 바이트에 앞 사진이 섞이면 안 된다.
    #expect(sink.take() == Data())
}
