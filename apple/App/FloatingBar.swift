// 떠 있는 툴바. `09`와 `10`이 같은 것을 쓴다.

import SwiftUI

/// 편집 대상 위에 뜨는 액션 바.
///
/// ⚠️ **자기가 뜬 면보다 밝아야 한다** — 다크에서 `바탕`을 쓰면 크롬이 지면 아래로 가라앉는다.
/// 값은 `Chrome`이 들고 있고 여기서는 형태만 만든다.
///
/// **카드는 담을 것이 둘 이상일 때만 나온다** — 슬롯이 하나인 자리(`05`)는 이걸 쓰지 않고
/// 주요 버튼에 그림자만 건다.
struct FloatingBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .frame(height: Layout.floatingBarHeight)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Chrome.floating)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: Radius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card)
                            .strokeBorder(Chrome.floatingBorder, lineWidth: 1)
                    }
                    .shadow(color: Chrome.shadowColor, radius: Chrome.shadowRadius,
                            y: Chrome.shadowOffset)
            }
    }
}
