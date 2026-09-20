// 소스가 바뀐 것을 알아채는 자리 (`SRC-03`). 사진 라이브러리의 변경 통지를 받는 유일한 곳이다.
//
// 라이브러리는 **무엇이 바뀌었는지 안 가리고** 통지한다 — 다른 앨범, 편집, 삭제 전부다.
// 무엇이 우리 것인지 가리는 일은 부르는 쪽이 식별자 대조로 한다.

import Foundation
import Photos

/// 라이브러리가 바뀔 때마다 알려주는 파수꾼.
///
/// **통지는 신호일 뿐 내용이 아니다** — 무엇이 바뀌었는지는 안 싣는다. 우리 소스가 정말
/// 바뀌었는지는 부르는 쪽이 `assetIDs()`로 대조해 판정한다. 그 층을 여기 두지 않는 것은
/// 이 타입이 앨범을 모르기 때문이다 — 소스가 무엇인지는 `AlbumPhotoSource`가 안다.
///
/// ⚠️ **통지가 오는 큐는 보장이 없다.** `onChange`는 아무 스레드에서나 불린다.
///
/// ⚠️ **권한이 없으면 걸리지 않는다** — `start()`가 조용히 아무 일도 안 한다. 나중에 권한을
/// 얻고 돌아오는 경로에서 다시 불러야 한다.
public final class SourceWatch: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let onChange: @Sendable () -> Void
    private let lock = NSLock()
    /// 지금 등록돼 있는가. **패키지 안에서 볼 수 있어야 한다** — 「권한이 없으면 안 걸린다」를
    /// 이 값 말고 밖에서 확인할 길이 없다.
    private(set) var isWatching = false

    public init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    deinit {
        // 등록된 채로 사라지면 라이브러리가 죽은 객체를 부른다.
        if isWatching { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    }

    /// 통지를 받기 시작한다. **여러 번 불러도 한 번만 건다.**
    public func start() {
        guard AlbumPhotoSource.currentAccess().canRead else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !isWatching else { return }
        PHPhotoLibrary.shared().register(self)
        isWatching = true
    }

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
