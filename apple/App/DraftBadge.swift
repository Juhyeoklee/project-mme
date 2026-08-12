// 초안 배지. 목록과 상세가 나눠 쓴다 — 목록에서 본 것이 상세에도 같은 형태로 있다.

import SwiftUI

/// 설명이 아직 없는 기록의 표시 (`ARC-08`).
///
/// ⚠️ **색이 없다** (원칙 `P4`). 초안은 덜 된 것이지 나쁜 것이 아니라, 배지에 색을 주는
/// 순간 목록이 「아직 안 한 일」의 알림판이 된다.
struct DraftBadge: View {
    var body: some View {
        Text(Wording.draft)
            .font(Typography.note)
            .foregroundStyle(Palette.secondaryLabel)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Palette.surface, in: .rect(cornerRadius: Radius.badge))
    }
}
