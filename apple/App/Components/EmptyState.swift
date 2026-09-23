// 「통째로 성립 안 함」이 서는 판 — `04` `07` `10`이 나눠 쓴다.

import SwiftUI

/// 빈 상태 한 판. **문구와 그 아래 길만 화면이 정한다.**
///
/// ⚠️ **세로 가운데는 이 조각이 안 진다** — 빈 자리가 지면 전체인지 목록의 첫 자리인지는
/// 부른 화면만 알고, 잘못 잡으면 덩어리가 처진다.
struct EmptyState<Below: View>: View {
    let message: String
    /// 읽기 실패처럼 한 줄에 안 끝나는 갈래는 본문 활자로 내려온다.
    var font: Font = Typography.emptyState
    /// 빠져나갈 길. 없으면 문구만 선다.
    @ViewBuilder let below: Below

    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .font(font)
                .foregroundStyle(Palette.secondaryLabel)
                .multilineTextAlignment(.center)
            below
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

extension EmptyState where Below == EmptyView {
    init(_ message: String, font: Font = Typography.emptyState) {
        self.init(message: message, font: font) { EmptyView() }
    }
}
