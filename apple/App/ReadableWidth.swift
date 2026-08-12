// 넓은 지면에서 본문이 늘어나지 않게 잡는다.

import SwiftUI

extension View {
    /// 본문 폭을 상한까지만 쓰고 가운데 세운다. **배경은 이 밖에서 깔아야 화면 끝까지 간다.**
    func readableWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Layout.readableWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }

    /// iPad 2단의 지면 한 장. **분할선을 안 그린다** — 여백과 반경이 경계를 진다.
    ///
    /// ⚠️ **폭을 건드리지 않는다.** 여기서 `maxWidth: .infinity`를 걸면 부르는 쪽이 정한
    /// 폭을 도로 늘려, 지면만 넓어지고 내용은 가운데로 몰린다(2026-08-12 실측).
    func pane() -> some View {
        frame(maxHeight: .infinity)
            .background(Palette.pane)
            .clipShape(.rect(cornerRadius: Radius.pane))
    }
}
