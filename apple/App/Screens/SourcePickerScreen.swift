// `02` 소스 지정 — 게임이 만든 앨범 하나를 소스로 정한다 (`SRC-01` `SRC-02` `SRC-04`).
//
// ⚠️ **화면이 아니라 시트다.** 앱 안이 먼저 뜨고 그 위에 올라온다.

import PhotoSource
import SwiftUI

struct SourcePickerScreen: View {
    /// 권한이 갈래를 정한다. ⚠️ **화면을 새로 만들지 않는다** — 같은 시트의 상태 셋이다.
    let access: ReadAccess
    let candidates: [SourceCandidate]
    /// 지금 쓰고 있는 소스. **설정에서 열면 그 후보에 이미 그어진 채로 뜬다** — 「지금 이것」을
    /// 말하는 표시를 따로 만들지 않는다.
    var current: String?
    /// 설정에서 왔는가. 나가는 낱말이 갈린다 — 온보딩은 무를 것이 없고 여기는 있다.
    var isChangingSource = false
    let onConfirm: (SourceCandidate) -> Void
    let onDismiss: () -> Void
    /// 부분 접근 — 시스템 피커를 다시 열어 허용 목록을 넓힌다.
    var onPickMore: () -> Void = {}
    /// 거부 — 정상 경로로 돌아가는 길.
    var onOpenSettings: () -> Void = {}
    /// 거부 — `SRC-05` 후퇴. **약해지는 쪽이라 보조로 놓는다.**
    var onImport: () -> Void = {}

    @State private var picked: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: title, height: Self.headerHeight) { leaveButton }
            if access == .denied || access == .restricted {
                hint(Wording.deniedHint)
                    .padding(.top, 4)
                Spacer(minLength: 24)
            } else {
                list
                    // ⚠️ **인셋을 목록에 건다** — 바깥에 걸면 스크롤이 그만큼을 모르고
                    // 마지막 후보가 버튼 뒤에 영영 남는다.
                    .safeAreaInset(edge: .bottom, spacing: 0) { buttons }
            }
        }
        .overlay(alignment: .bottom) {
            if access == .denied || access == .restricted { buttons }
        }
        .onAppear {
            // ⚠️ 지금 쓰는 소스가 후보에 없으면(사라진 앨범) **안 고른 것으로 시작한다.**
            picked = candidates.contains { $0.id == current } ? current : nil
        }
    }

    private var leaveButton: some View {
        Button(isChangingSource ? Wording.cancel : Wording.later, action: onDismiss)
            .buttonStyle(PlainActionStyle())
    }

    private var title: String {
        switch access {
        case .limited: Wording.pickPhotos
        case .denied, .restricted: Wording.bringPhotos
        case .authorized, .notDetermined: Wording.chooseAlbum
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Typography.subtitle)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Spacing.listLeading)
            .padding(.trailing, Spacing.screenMargin)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(access == .limited ? Wording.limitedHint : Wording.sourceHint)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.secondaryLabel)
                    .padding(.bottom, 14)
                VStack(alignment: .leading, spacing: Layout.sourceRowGap) {
                    ForEach(candidates) { candidate in
                        // ⚠️ **부분 접근에는 고를 것이 없다** — 후보가 하나뿐이라 탭이 뜻이 없다.
                        if access == .limited {
                            CandidateRow(candidate: candidate, isPicked: false)
                        } else {
                            Button { picked = candidate.id } label: {
                                CandidateRow(candidate: candidate, isPicked: picked == candidate.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Spacing.listLeading)
            .padding(.trailing, Spacing.screenMargin)
        }
    }

    /// ⚠️ **보조가 위, 주요가 아래다** — 엄지에 가까운 쪽이 주요다.
    private var buttons: some View {
        VStack(spacing: 10) {
            switch access {
            case .limited:
                Button(Wording.pickMorePhotos, action: onPickMore)
                    .buttonStyle(SecondaryActionStyle(fillsWidth: true))
                    .actionWidth()
                confirmButton
            case .denied, .restricted:
                Button(Wording.importDirectly, action: onImport)
                    .buttonStyle(PlainActionStyle())
                    .actionWidth()
                Button(Wording.openSettings, action: onOpenSettings)
                    .buttonStyle(PrimaryActionStyle(fillsWidth: true))
                    .actionWidth()
            case .authorized, .notDetermined:
                confirmButton
            }
        }
        .padding(.leading, Spacing.listLeading)
        .padding(.trailing, Spacing.screenMargin)
        .padding(.top, 14)
        .padding(.bottom, 24)
    }

    /// ⚠️ **아무것도 안 고르면 비활성이다** — 그래서 나가는 낱말이 머리에 늘 서 있어야 한다.
    /// 부분 접근에는 고를 것이 없으므로 늘 켜져 있다.
    private var confirmButton: some View {
        Button(Wording.confirm) {
            if access == .limited {
                onDismiss()
            } else if let chosen = candidates.first(where: { $0.id == picked }) {
                onConfirm(chosen)
            }
        }
        .buttonStyle(PrimaryActionStyle(fillsWidth: true))
        .disabled(access != .limited && picked == nil)
        .actionWidth()
    }

    private static let headerHeight: CGFloat = 52
}

// MARK: - 시트가 서는 모양

extension View {
    /// ⚠️ **iPhone은 바닥에 붙고 iPad는 창 가운데 뜬다** — pen이 둘을 다른 물건으로 그렸다.
    func sourceSheet(isPad: Bool, height: CGFloat) -> some View {
        modifier(SourceSheetShape(isPad: isPad, height: height))
    }
}

private struct SourceSheetShape: ViewModifier {
    let isPad: Bool
    let height: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPad {
            // ⚠️ 크기를 가장 바깥에 건다 — 안쪽이면 `.fitted`가 높이를 두 번 제안해 칸이 눌린다.
            shaped(content)
                .frame(width: Layout.sourcePadSheet.width,
                       height: Layout.sourcePadSheet.height)
                .presentationSizing(.fitted)
                .presentationDragIndicator(.hidden)
        } else {
            shaped(content)
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
        }
    }

    private func shaped(_ content: some View) -> some View {
        content.presentationBackground(Palette.cardSurface)
    }
}

// MARK: - `02-L` 후보 한 줄

/// `04`의 골격을 그대로 쓴다 — 요약 줄과 스트립. **새 어휘가 0이다.**
private struct CandidateRow: View {
    let candidate: SourceCandidate
    let isPicked: Bool

    /// ⚠️ **폭을 재서 칸 수와 변을 정한다** — 타일이 고정이고 칸 수가 폭을 따라간다.
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.cellGap) {
            nameLine
            strip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPicked ? [.isSelected] : [])
    }

    /// ⚠️ **획이 스트립이 아니라 이름 줄에 그어진다** — 형광펜은 낱말에 긋는 도구고,
    /// 사진 위에 긋는 자리는 어디에도 없다.
    private var nameLine: some View {
        HStack(spacing: 8) {
            Text(candidate.title)
                .font(Typography.time)
                .foregroundStyle(Palette.label)
            Text(Wording.images(candidate.count))
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .highlighterSweeps(isPicked)
    }

    private var strip: some View {
        let cells = Layout.sourceCells(inWidth: width)
        let side = max(1, (width - Spacing.cellGap * CGFloat(cells - 1)) / CGFloat(cells))
        let shown = candidate.preview.prefix(cells - 1)
        return HStack(spacing: Spacing.cellGap) {
            ForEach(shown, id: \.id) { asset in
                AssetImage(asset: asset, pixels: Layout.thumbnailPixels, fills: true,
                           cornerRadius: Radius.thumbnail)
                    .frame(width: side, height: side)
            }
            overflow(candidate.count - shown.count)
                .frame(width: side, height: side)
        }
        .frame(height: side)
    }

    /// ⚠️ **`면`이 아니라 `속면`이다** — 시트가 `카드면`이라 다크에서 값이 같아 사라진다.
    private func overflow(_ hidden: Int) -> some View {
        Text(Wording.moreInSource(max(0, hidden)))
            .font(Typography.time)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.innerSurface)
            .clipShape(.rect(cornerRadius: Radius.thumbnail))
    }
}
