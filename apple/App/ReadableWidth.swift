// 넓은 지면에서 본문이 늘어나지 않게 잡는다.

import SwiftUI

extension View {
    /// 본문 폭을 상한까지만 쓰고 가운데 세운다. **배경은 이 밖에서 깔아야 화면 끝까지 간다.**
    func readableWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Layout.readableWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }

    /// iPad 2단의 지면 한 장. **분할선을 안 그린다** — 여백과 반경이 경계를 진다.
    func pane() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.pane)
            .clipShape(.rect(cornerRadius: Radius.pane))
    }
}
