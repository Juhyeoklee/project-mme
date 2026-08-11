// `10` 사진 더하기 — 자동 묶임이 놓친 사진을 더한다(**순간 편집의 대체물**).
//
// ⚠️ **두 출처가 섞이지 않는다.** 소스 안 사진은 본문 격자에 앱이 시간순으로 놓고, 소스 밖
// 사진(`REC-10`)은 툴바 버튼 → 시스템 피커로만 들어온다. 물리적으로 다른 층에 있어
// 섞으려야 섞일 수 없고, 그래야 앱이 소스 밖을 훑어 제시하는 것이 안 된다 (`SRC-08`).

import MomentKernel
import PhotoSource
import PhotoSourceUI
import SwiftUI

struct PhotoAddSheet: View {
    let library: MomentLibrary
    let draft: RecordDraft

    @State private var groups: [MomentGroup] = []
    @State private var included: Set<String>
    @State private var imported: [ImportedDraft] = []
    @State private var isImporting = false
    /// 격자가 놓일 실제 폭. **열 수를 이 값이 정한다.**
    @State private var contentWidth: CGFloat = 320

    @Environment(\.dismiss) private var dismiss

    init(library: MomentLibrary, draft: RecordDraft) {
        self.library = library
        self.draft = draft
        _included = State(initialValue: draft.includedAssetIDs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.cellGap) {
                    ForEach(groups) { group in
                        header(group)
                        grid(group)
                    }
                    importedGrid
                }
                .padding(.horizontal, Spacing.screenMargin)
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) { toolbar }
            .navigationTitle(Wording.addPhotos)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Wording.cancel) { dismiss() }
                        .font(Typography.body)
                }
            }
        }
        .presentationCornerRadius(Radius.card)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { contentWidth = max(1, $0 - Spacing.screenMargin * 2) }
        // ⚠️ **가져오는 즉시 기록에 넣지 않는다** — 시트는 확정해야 반영되고 취소하면 버려진다.
        // 소스 안 사진과 같은 규칙이라, 여기서만 다르면 취소가 반쪽이 된다.
        .photoImporter(isPresented: $isImporting) { photo in
            imported.append(ImportedDraft(photo: photo))
        }
        // 신원이 매번 새로 만들어지면 격자가 갱신마다 흔들린다 — 한 번만 세운다.
        .task { if groups.isEmpty { groups = makeGroups() } }
    }

    // MARK: - `10-B` 시각 구분

    /// **꼬리를 다는 것은 「이 순간」 하나뿐이다.** 나머지는 시각만 쓴다 — 「앞 순간」·「뒤 순간」은
    /// 순간이 셋일 때만 성립하는 말이라 하루 전체에서는 안 선다.
    private func header(_ group: MomentGroup) -> some View {
        Text(Wording.momentBreak(group.start, isOrigin: group.isOrigin))
            .font(Typography.label)
            .foregroundStyle(Palette.secondaryLabel)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    // MARK: - `10-G` 격자

    /// 열 수는 폭이 정한다 — 근거는 `Layout.pickerColumns(inWidth:)`에 있다.
    private func grid(_ group: MomentGroup) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.cellGap),
                                 count: Layout.pickerColumns(inWidth: contentWidth)),
                  spacing: Spacing.cellGap) {
            ForEach(group.photos) { photo in
                let assetID = photo.asset?.id ?? ""
                RecordPhotoTile(isIncluded: included.contains(assetID)) {
                    AssetImage(asset: photo.asset, pixels: ImageStore.thumbnailPixels,
                               fills: true, retryToken: library.generation)
                }
                .aspectRatio(1, contentMode: .fit)
                .contentShape(.rect)
                .onTapGesture { toggle(assetID) }
            }
        }
    }

    /// `REC-10`으로 가져온 것. **목록 끝에 붙고 시각 구분 헤더가 없다.**
    ///
    /// ★ **헤더가 없다는 것 자체가 「시간축 밖」을 말한다** — 촬영 정보를 안 읽으므로 시간순으로
    /// 꽂을 수 없고, 새 문구를 만들지 않고도 두 풀이 안 섞인다.
    @ViewBuilder
    private var importedGrid: some View {
        if !imported.isEmpty {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.cellGap),
                                     count: Layout.pickerColumns(inWidth: contentWidth)),
                      spacing: Spacing.cellGap) {
                ForEach($imported) { $item in
                    RecordPhotoTile(isIncluded: item.isIncluded) {
                        ImportedImage(data: item.photo.data)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .contentShape(.rect)
                    .onTapGesture { item.isIncluded.toggle() }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - `10-T` 툴바

    private var toolbar: some View {
        FloatingBar {
            Button(Wording.importDirectly) { isImporting = true }
                .buttonStyle(PlainActionStyle())
            Spacer(minLength: 0)
            Button(Wording.confirm) { confirm() }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, 12)
    }

    // MARK: - 조각

    /// `REC-05` 후보 — **같은 날의 소스 안 사진 전체 · 시간 오름차순.**
    private func makeGroups() -> [MomentGroup] {
        guard let day = library.days.first(where: { $0.date == draft.day }) else { return [] }
        return day.moments.reversed().enumerated().map { offset, moment in
            MomentGroup(id: offset,
                        start: moment.start,
                        isOrigin: draft.startsFromMoment && moment.start == draft.start,
                        photos: RecordDraft.photos(at: moment.photoIndices, library: library))
        }
    }

    private func toggle(_ assetID: String) {
        guard !assetID.isEmpty else { return }
        if included.contains(assetID) {
            included.remove(assetID)
        } else {
            included.insert(assetID)
        }
    }

    private func confirm() {
        draft.apply(includedAssets: included, candidates: groups.flatMap(\.photos))
        for item in imported where item.isIncluded {
            draft.addImported(item.photo.data, fileExtension: item.photo.fileExtension)
        }
        dismiss()
    }
}

/// 시트가 닫힐 때까지만 사는 가져온 사진. 확정해야 기록으로 넘어간다.
private struct ImportedDraft: Identifiable {
    let id = UUID()
    let photo: ImportedPhoto
    var isIncluded = true
}

/// 한 순간의 후보들. 시각 구분 헤더가 이 단위로 선다.
private struct MomentGroup: Identifiable {
    let id: Int
    let start: WallClock
    /// 기록이 시작된 그 순간인가.
    let isOrigin: Bool
    let photos: [DraftPhoto]
}
