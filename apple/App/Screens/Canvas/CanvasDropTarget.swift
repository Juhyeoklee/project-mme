// `CAN-03` 캔버스가 이미지를 받는 두 길 — 끌어다 놓기와 붙여넣기.
//
// ⚠️ **스티커 버튼을 만들지 않는다.** `CAN-03`은 자체 세트가 아니라 **받는 면**이다 —
// 시스템 스티커도 다른 앱의 사진도 이 두 길로 들어온다.

import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// 이미지를 받는 면으로 만든다. 좌표는 이 뷰의 것이라 캔버스 문서 좌표로 그대로 들어온다.
    func receivesImages(dropped: @escaping (Data, String, CGPoint) -> Void,
                        pasted: @escaping (Data, String) -> Void,
                        menuAt: Binding<CGPoint?>) -> some View {
        self.onDrop(of: [.image], isTargeted: nil) { providers, location in
            var received = false
            for provider in providers where provider.hasImage {
                received = true
                provider.loadImage { data, fileExtension in
                    dropped(data, fileExtension, location)
                }
            }
            return received
        }
        .background { PasteReceiver(onPaste: pasted, menuAt: menuAt) }
    }
}

private extension NSItemProvider {
    var hasImage: Bool { imageType != nil }

    /// 이미지로 읽을 수 있는 타입. **가장 앞에 오는 것을 쓴다** — 제공자가 선호도 순으로 준다.
    var imageType: UTType? {
        registeredTypeIdentifiers.lazy
            .compactMap(UTType.init)
            .first { $0.conforms(to: .image) }
    }

    /// 바이트와 확장자를 주 액터로 넘긴다.
    func loadImage(_ handle: @escaping @MainActor (Data, String) -> Void) {
        guard let type = imageType else { return }
        loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            guard let data else { return }
            let fileExtension = type.preferredFilenameExtension ?? "png"
            Task { @MainActor in handle(data, fileExtension) }
        }
    }
}

/// 붙여넣기를 받는 자리 — `⌘V`와 **길게 눌러 뜨는 편집 메뉴** 둘 다.
///
/// ⚠️ **응답자 사슬로 받는다.** `UIPasteboard`를 직접 읽으면 iOS가 「붙여넣기를 허용할까요」를
/// 띄우는데, 시스템이 부른 `paste(_:)` 안에서는 그 확인이 이미 끝나 있다.
///
/// ⚠️ **길게 누르기가 없으면 손가락만 쓰는 기기에 붙여넣을 길이 없다** — `⌘V`는 외장
/// 키보드를 전제한다.
///
/// ⚠️ **글을 받는 동안에는 응답자를 안 뺏는다** — 그때 `⌘V`는 글자를 붙여넣는 일이라
/// 입력 상자의 것이다.
private struct PasteReceiver: UIViewRepresentable {
    let onPaste: (Data, String) -> Void
    /// 길게 누른 자리. 값이 들어오면 그 자리에 편집 메뉴를 띄우고 비운다.
    @Binding var menuAt: CGPoint?

    func makeUIView(context: Context) -> PasteReceiverView {
        let view = PasteReceiverView()
        view.onPaste = onPaste
        return view
    }

    func updateUIView(_ view: PasteReceiverView, context: Context) {
        view.onPaste = onPaste
        guard let point = menuAt else { return }
        view.showMenu(at: point)
        Task { @MainActor in menuAt = nil }
    }
}

private final class PasteReceiverView: UIView {
    var onPaste: ((Data, String) -> Void)?

    private lazy var menu = UIEditMenuInteraction(delegate: nil)

    override var canBecomeFirstResponder: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(menu)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("사용하지 않는다") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        becomeFirstResponder()
    }

    /// 길게 누른 자리에 시스템 편집 메뉴를 띄운다. **항목은 `canPerformAction`이 정한다.**
    func showMenu(at point: CGPoint) {
        guard UIPasteboard.general.hasImages else { return }
        becomeFirstResponder()
        menu.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
    }

    /// ⚠️ **`hasImages`는 경고를 안 띄운다** — 내용이 아니라 있고 없음만 묻는다.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) { return UIPasteboard.general.hasImages }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        for provider in UIPasteboard.general.itemProviders where provider.hasImage {
            provider.loadImage { [weak self] data, fileExtension in
                self?.onPaste?(data, fileExtension)
            }
            return
        }
    }
}
