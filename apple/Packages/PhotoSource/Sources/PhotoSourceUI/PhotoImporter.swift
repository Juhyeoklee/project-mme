// PhotoSourceUI — **사용자가 건네는 사진**. 시스템 피커를 여는 자리이고, 이 패키지 밖에서
// 사진 프레임워크를 import하지 않게 하는 것이 존재 이유다 (ADR `0012`).
//
// ⚠️ **소스를 넓히지 않는다** (`SRC-08`) — 앱이 라이브러리를 훑는 것이 아니라 사용자가 고른
// 것만 넘어온다. 그래서 여기에는 열거도 검색도 없고, 나가는 것은 바이트 한 덩어리뿐이다.

import PhotosUI
import SwiftUI

/// 사용자가 시스템 피커에서 지목한 사진 한 장.
///
/// **촬영 정보를 담지 않는다** — `REC-10`으로 들어온 사진의 시각과 청크는 기록에서 쓰이지
/// 않으므로, 여기서 읽어 넘기면 쓰는 곳 없는 값이 계약에 남는다.
public struct ImportedPhoto: Sendable, Hashable {
    public let data: Data
    /// 저장 파일 이름에 붙일 확장자. 피커가 말해준 형식에서 온다.
    public let fileExtension: String

    init(data: Data, fileExtension: String) {
        self.data = data
        self.fileExtension = fileExtension
    }
}

public extension View {
    /// 시스템 사진 피커를 띄운다. 고른 사진이 한 장씩 `onPick`으로 온다.
    func photoImporter(isPresented: Binding<Bool>,
                       onPick: @escaping @MainActor (ImportedPhoto) -> Void) -> some View {
        modifier(PhotoImporter(isPresented: isPresented, onPick: onPick))
    }
}

private struct PhotoImporter: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: @MainActor (ImportedPhoto) -> Void

    @State private var picked: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $picked, matching: .images)
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                Task { await deliver(items) }
            }
    }

    /// ⚠️ **읽지 못한 것은 조용히 건너뛴다.** 사용자가 고른 것 중 하나가 실패해도 나머지는
    /// 들어와야 하고, 무엇이 왜 안 왔는지는 이 층이 답할 수 없다.
    private func deliver(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            onPick(ImportedPhoto(data: data, fileExtension: Self.fileExtension(of: item)))
        }
        picked = []
    }

    private static func fileExtension(of item: PhotosPickerItem) -> String {
        item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
    }
}
