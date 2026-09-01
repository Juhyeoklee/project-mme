// 설정 행 계열 — `13`과 `13-A`가 나눠 쓴다. **관례를 따르는 자리라 발명이 0이다.**

import SwiftUI

/// 그림자 없이 **면 색 자신이 경계를 지는** 묶음.
///
/// ⚠️ **행을 배열로 받는다** — 사이에 선을 끼워야 하는데 `@ViewBuilder`로는 낱개를 못 센다.
struct SettingsGroup: View {
    let rows: [SettingsRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 { divider }
                rows[index]
            }
        }
        .background(Palette.listSurface)
        .clipShape(.rect(cornerRadius: Radius.card))
    }

    /// ⚠️ **`placeholder`가 아니라 `active`다** — 다크에서 `listSurface`와 값이 같아 사라진다.
    private var divider: some View {
        Rectangle()
            .fill(Palette.active)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

/// 설정 행 하나. **관례를 따른다** — 라벨 좌, 값과 표시 우.
struct SettingsRow: View {
    let label: String
    var value: String?
    var showsAccentDot = false
    /// 고른 행. **체크는 현재 강조색이라 판정이 자기를 증명한다.**
    var isChecked = false
    /// 갈 곳이 있는 행.
    var showsChevron = false
    var isEnabled = true
    var action: (() -> Void)?

    @Environment(\.accentSet) private var accentSet

    var body: some View {
        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(isEnabled ? Palette.label : Palette.disabled)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                if let value {
                    Text(value)
                        .font(Typography.body)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                if showsAccentDot {
                    Circle().fill(accentSet.accent).frame(width: 14, height: 14)
                }
                if isChecked {
                    GlyphIcon(Glyph.selected)
                        .foregroundStyle(accentSet.accent)
                }
                if showsChevron {
                    // ⚠️ **`chevron-right` 자산이 없어 좌향을 뒤집는다** — lucide의 우향
                    // 셰브런은 좌향의 정확한 거울이라 새 자산을 안 늘린다.
                    GlyphIcon(Glyph.back, size: 18)
                        .scaleEffect(x: -1)
                        .foregroundStyle(Palette.disabled)
                }
            }
            .frame(minHeight: Layout.glyph)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }
}
