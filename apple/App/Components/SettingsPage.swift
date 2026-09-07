// 설정 계열 셋(`13` `13-A` `14`)이 나눠 쓰는 틀 — iPhone 지면 한 장과 iPad 시트.
//
// ⚠️ **골격을 화면마다 복사하면 하나를 고칠 때 나머지가 조용히 낡는다.**

import SwiftUI

/// 뒤로 갈 수 있는 지면 한 장. 타이틀만 화면이 정한다.
struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentSet) private var accentSet

    var body: some View {
        ScrollView {
            content
                .padding(.top, 132)
                .padding(.leading, Spacing.bindingMargin)
                .padding(.trailing, Spacing.screenMargin)
        }
        .paneBackground()
        .threadBinding(.detail)
        .overlay(alignment: .top) { header }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// ⚠️ **뒤로는 유리 원판이다** — 네비 바를 숨기고 `05-N1`과 같은 문법으로 세운다.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button { dismiss() } label: {
                    GlyphIcon(Glyph.back)
                        .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                        .foregroundStyle(accentSet.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Wording.back)
                .glassEffect(.regular, in: .circle)
                Spacer()
            }
            .frame(height: Layout.hitTarget)
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Palette.label)
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
        .padding(.leading, Spacing.bindingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .headerScrim()
    }
}

/// iPad 시트 한 장. 왼쪽 슬롯만 화면이 정한다.
struct SettingsSheet<Leading: View, Content: View>: View {
    let title: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .padding(.horizontal, Self.inset)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        SheetHeader(title: title) { leading }
    }

    private static var inset: CGFloat { 24 }
}

/// 시트 안에서 `13`으로 되돌아가는 버튼.
///
/// ⚠️ **셰브런과 낱말이 한 버튼이다** — 시트 안에는 유리 원판이 설 자리가 없다.
struct SettingsBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentSet) private var accentSet

    var body: some View {
        Button { dismiss() } label: {
            HStack(spacing: 2) {
                GlyphIcon(Glyph.back, size: 18)
                Text(Wording.settingsTitle).font(Typography.label)
            }
            .foregroundStyle(accentSet.accent)
        }
        .buttonStyle(.plain)
    }
}
