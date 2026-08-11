// 넓은 지면에서 본문이 늘어나지 않게 잡는다.

import SwiftUI

extension View {
    /// 본문 폭을 상한까지만 쓰고 가운데 세운다. **배경은 이 밖에서 깔아야 화면 끝까지 간다.**
    func readableWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Layout.readableWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }
}
