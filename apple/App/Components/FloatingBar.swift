// 떠 있는 툴바. `09`와 `10`이 같은 것을 쓴다.

import SwiftUI

/// 편집 대상 위에 뜨는 액션 바.
///
/// **카드는 담을 것이 둘 이상일 때만 나온다** — 슬롯이 하나인 자리(`05`·`09` iPhone)는
/// 이걸 쓰지 않고 버튼이 직접 유리를 진다.
///
/// ⚠️ **유리를 지는 것은 카드다** — 안의 버튼은 내용물이라 불투명하다. 둘 다 유리면
/// 카드가 묶는 일을 하는지가 안 보인다.
///
/// ⚠️ **폭 상한을 바가 직접 진다** — 부르는 쪽에 맡겼더니 `09`·`10`이 안 걸어 넓은 지면에서
/// `08`보다 62pt 넓게 섰다(2026-08-13 시뮬레이터 실측). 셋은 한 어휘라 나란히 선 자리에서
/// 그 차이가 그대로 보인다.
struct FloatingBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .frame(height: Layout.floatingBarHeight)
            .padding(.horizontal, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
            .blocksNearbyTaps()
            .frame(maxWidth: Layout.floatingBarMaxWidth)
    }
}
