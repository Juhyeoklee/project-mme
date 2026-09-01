// `14` 약관 — 긴 글 한 판. **한 형태를 이용약관과 개인정보 처리방침이 나눠 쓴다.**

import SwiftUI

struct LegalScreen: View {
    let document: LegalDocument
    /// iPad 시트 안에서 뜨는가. **모양만 가른다.**
    var isInSheet = false

    var body: some View {
        if isInSheet {
            SettingsSheet(title: document.title) { SettingsBackButton() } content: { clauses }
        } else {
            SettingsPage(title: document.title) { clauses }
        }
    }

    /// ⚠️ **카드에 안 담는다** — 조 제목과 본문이 이미 층을 지므로 묶음이 하나 더 있으면
    /// 층이 셋이 된다.
    private var clauses: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Wording.effectiveDate)
                .font(Typography.note)
                .foregroundStyle(Palette.disabled)
            ForEach(document.clauses.indices, id: \.self) { index in
                Spacer().frame(height: 20)
                Text(document.clauses[index].heading)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Palette.label)
                Spacer().frame(height: 6)
                Text(document.clauses[index].body)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineSpacing(Self.lineGap)
            }
            Spacer().frame(height: 28)
            Text(Wording.provisionalNotice)
                .font(Typography.note)
                .foregroundStyle(Palette.disabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 줄간 1.6배 — 본문 14pt가 자기 몫으로 이미 갖는 만큼을 뺀 나머지.
    private static let lineGap: CGFloat = 14 * 0.6
}
