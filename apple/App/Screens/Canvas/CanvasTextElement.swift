// `11-C4` 캔버스에 쓴 글 — 그리는 법과 재는 법, 그리고 쓰는 동안의 자리.

import SwiftUI

/// 지금 글을 받고 있는 상자.
///
/// ⚠️ **문서에 아직 안 앉은 글자가 여기 산다.** 저장하거나 다른 것을 집기 전에 반드시
/// 앉혀야 한다 — 안 그러면 방금 친 글이 소리 없이 사라진다. 한 번에 앉히는 이유는
/// 되돌리기다: 글자마다 앉히면 `11-N2` 한 번에 한 글자씩 지워진다.
struct CanvasTextEditing: Equatable {
    let id: UUID
    var string: String

    /// 받고 있던 글을 문서에 앉힌다.
    @MainActor
    func commit(to session: CanvasSession) {
        session.setText(id, string: string)
    }
}

/// 캔버스에 놓인 글 한 덩이.
///
/// ⚠️ **잰 높이와 그린 높이가 같아야 한다.** 상자는 `measure(_:width:)`가 정하는데 그리는
/// 것은 여기라, 줄 간격이나 정렬을 한쪽만 고치면 마지막 줄이 상자 밖으로 나간다.
struct CanvasTextView: View {
    let text: CanvasText

    var body: some View {
        Text(text.string)
            .font(.custom(Typography.canvasFace(text.face, bold: text.isBold), size: text.size))
            .foregroundStyle(text.ink.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension CanvasText {
    /// 처음 놓일 때의 폭. 종이 오른쪽 끝까지 남은 자리를 넘지 않는다.
    static func initialWidth(from x: CGFloat) -> CGFloat {
        min(420, max(160, Layout.canvasSize.width - Spacing.screenMargin - x))
    }

    /// 이 글이 그 폭에서 차지하는 높이. ⚠️ **빈 글도 한 줄만큼 높다** — 0이면 방금 만든
    /// 상자를 못 집는다.
    func measure(width: CGFloat) -> CGFloat {
        let font = UIFont(name: Typography.canvasFace(face, bold: isBold), size: size)
            ?? .systemFont(ofSize: size)
        let measured = (string.isEmpty ? " " : string as String).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        return measured.height.rounded(.up) + 2
    }

    /// 이 글을 담을 상자. 폭은 주어지고 높이는 글이 정한다.
    func box(at origin: CGPoint, width: CGFloat) -> CGRect {
        CGRect(origin: origin, size: CGSize(width: width, height: measure(width: width)))
    }
}
