// 넓은 지면에서 본문이 늘어나지 않게 잡는다.

import SwiftUI

extension View {
    /// 본문 폭을 상한까지만 쓰고 가운데 세운다. **배경은 이 밖에서 깔아야 화면 끝까지 간다.**
    func readableWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Layout.readableWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }

    /// iPad 2단의 지면 한 장 — 배경과 반경만 진다.
    /// ⚠️ **폭을 건드리지 않는다** — `maxWidth`를 걸면 부르는 쪽이 정한 폭이 도로 늘어난다.
    func pane() -> some View {
        frame(maxHeight: .infinity)
            .background(Palette.pane)
            .clipShape(.rect(cornerRadius: Radius.pane))
    }
}
