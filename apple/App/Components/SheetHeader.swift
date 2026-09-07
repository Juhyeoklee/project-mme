// 시트 머리 — 타이틀은 창 가운데, 왼쪽 슬롯만 화면이 정한다. `02`와 `13` 계열이 나눠 쓴다.

import SwiftUI

/// ⚠️ **타이틀과 왼쪽 슬롯을 나란히 두지 않는다** — 낱말 길이가 타이틀을 밀어 화면마다
/// 가운데가 달라진다.
struct SheetHeader<Leading: View>: View {
    let title: String
    var height: CGFloat = 64
    @ViewBuilder let leading: Leading

    var body: some View {
        ZStack {
            Text(title)
                .font(Typography.time)
                .foregroundStyle(Palette.label)
            HStack(spacing: 0) {
                leading
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .frame(height: height)
    }
}
