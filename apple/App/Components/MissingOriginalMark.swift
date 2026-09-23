// 원본을 끝내 못 받은 사진을 말하는 두 표시 (`R8`). `05`와 `09`가 나눠 쓴다.
//
// ⚠️ **둘이 한 짝이다** — 실패는 사진 단위인데 결과는 화면 단위라, 어느 사진인지는 배지가
// 왜인지는 말풍선이 진다. 하나만 두면 나머지 물음이 갈 데가 없다.

import SwiftUI

/// `05-N4` · `09-N5` — 머리에 서는 표시. **누르면 설명이 뜬다.**
///
/// ⚠️ **설명은 화면마다 다르다** — `05`는 분류가 나빠지는 것을, `09`는 저장이 막히는 것을
/// 말한다. 그래서 문구를 밖에서 받는다.
struct MissingNote: View {
    let message: String

    @State private var isExplaining = false
    @Environment(\.accentSet) private var accentSet

    var body: some View {
        Button { isExplaining = true } label: {
            // ⚠️ 활자로 세운다 — lucide에 맞는 글리프가 없다. 생기면 갈아 끼운다.
            Text(verbatim: "!")
                .font(Typography.sectionLabel)
                .foregroundStyle(accentSet.accent)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(accentSet.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Wording.missingOriginalsLabel)
        .popover(isPresented: $isExplaining) {
            // ⚠️ **폭을 주고 세로로 자라게 해야 한다** — 안 주면 팝오버가 제 크기를 못 잡아
            // 두 줄째부터 잘린다.
            Text(message)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.onCallout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .presentationBackground(Palette.calloutSurface)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// `05-G5` · `09-G5` — 사진 위에 서는 표시. 연사 배지와 같은 문법이다.
///
/// ⚠️ **머리의 표시와 색이 다르다.** 여기는 사진 위라 흰 글자가 유일하게 안전하고, 머리는
/// 지면 위라 강조색이 「누를 수 있다」를 말한다. 바탕이 다르면 처방도 다르다.
struct MissingBadge: View {
    /// 이 칸이 대표하는 사진 중 못 받은 장수.
    ///
    /// ⚠️ **개수를 지는 것이 계약이다** — `05`의 연사 셀 하나가 여러 장을 대표하므로, 안 지면
    /// 머리가 말한 장수와 화면의 배지 수가 안 맞는다. `09`의 격자는 한 칸이 한 장이라 늘 1이다.
    let count: Int

    var body: some View {
        Text(verbatim: count > 1 ? "!\(count)" : "!")
            .font(Typography.note)
            .foregroundStyle(Palette.onPhotoBadge)
            .frame(minWidth: 18)
            .frame(height: 18)
            .padding(.horizontal, count > 1 ? 5 : 0)
            .background(Palette.photoBadge, in: .capsule)
    }
}
