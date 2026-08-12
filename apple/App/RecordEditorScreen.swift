// `09` 기록 작성기 — 사진을 확정하고 설명을 쓴다. **모든 기록이 여기서 시작한다.**
//
// ⚠️ **시스템 네비 바를 쓰지 않는다** — iOS 26의 유리 바는 `UINavigationBarAppearance`를
// 무시하고, 타이틀이 흰색으로 뒤집혀 밝은 지면에서 사라진다(2026-08-11 실측).

import MomentKernel
import PhotoSource
import SwiftUI

struct RecordEditorScreen: View {
    let library: MomentLibrary
    /// ⚠️ **`@State`로 들지 않는다** — 초안의 수명은 `RootView`가 쥔다. 여기에 복사하면
    /// iPad 2단에서 편집 중에 `기록 만들기`를 다시 눌러도 뷰 신원이 같아 옛 초안이 남는다.
    let draft: RecordDraft
    /// 닫는 방법은 뜬 자리가 안다 — iPhone은 덮개를 내리고 iPad는 우측 지면을 되돌린다.
    let onClose: () -> Void

    @State private var isAddingPhotos: Bool

    @State private var isConfirmingCancel = false
    @State private var isEditingOccurredAt = false
    /// 격자가 놓일 실제 폭. **열 수를 이 값이 정한다.**
    @State private var contentWidth: CGFloat = 320
    /// 머리가 얼마나 줄었나. 0이면 펼침, 1이면 접힘.
    @State private var collapse: Double = 0
    @FocusState private var captionFocused: Bool

    /// 합성 데이터로 `10`을 바로 띄울 때만 켠다 — `RootView.initialEditing`과 같은 문이다.
    init(library: MomentLibrary, draft: RecordDraft,
         initialAddingPhotos: Bool = false, onClose: @escaping () -> Void) {
        self.library = library
        self.draft = draft
        self.onClose = onClose
        _isAddingPhotos = State(initialValue: initialAddingPhotos)
    }

    @Environment(\.recordStore) private var store
    @Environment(\.originalBytes) private var originalBytes
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: {
                contentWidth = max(1, min($0, Layout.readableWidth)
                    - leadingMargin - Spacing.screenMargin)
            }
    }

    private var content: some View {
        // ⚠️ **머리를 겹쳐 띄운다** — 나란히 쌓으면 콘텐츠가 머리 아래로 지나가지 못해
        // 유리가 비출 것이 없다. 첫 화면에서 가려지지 않는 것은 격자의 상단 여백이 맡는다.
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grid(width: contentWidth)
                    caption
                }
                // ⚠️ 밑줄이 툴바에 닿으면 「선」이 아니라 「경계」로 읽힌다 (2026-08-11 실기기).
                .padding(.bottom, 24)
                .readableWidth()
            }
            .contentMargins(.top, Layout.largeTitleHeaderHeight, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                collapse = min(max(offset / Layout.hitTarget, 0), 1)
            }
            header
        }
        .background(paneBackground)
        // ⚠️ **머리를 직접 그리므로 시스템 바를 숨긴다** — iPad 2단의 지면에서는 빈 바가
        // 위쪽 ~145pt를 그대로 먹어 화면이 그만큼 짧아진다(2026-08-11 시뮬레이터 실측).
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { binding }
        .safeAreaInset(edge: .bottom) { toolbar }
        .sheet(isPresented: $isAddingPhotos) {
            PhotoAddSheet(library: library, draft: draft)
        }
        .sheet(isPresented: $isEditingOccurredAt) {
            OccurredAtSheet(initial: draft.occurredAt) { draft.setOccurredAt($0) }
        }
        .confirmationDialog(Wording.discardTitle, isPresented: $isConfirmingCancel,
                            titleVisibility: .visible) {
            // ⚠️ 사진을 전부 뺐으면 초안도 못 만든다 — 내놓으면 눌러도 아무 일이 안 일어난다.
            if draft.canSave {
                Button(Wording.keepAsDraft) { Task { await save(status: .draft) } }
            }
            Button(Wording.discard, role: .destructive) { onClose() }
        }
        .alert(Wording.saveFailed, isPresented: saveFailed) {
            Button(Wording.acknowledge) { draft.clearFailure() }
        }
    }

    // MARK: - `09-N` 머리

    /// ⚠️ **iPad 2단에서는 `지면`이다** — `바탕`을 칠하면 다크에서 지면과 바깥이 같은 값이
    /// 되어 두 장의 종이가 통째로 안 보인다.
    private var paneBackground: Color {
        sizeClass == .regular ? Palette.pane : Palette.background
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ⚠️ **접힌 날짜가 두 버튼과 같은 줄에 선다** — 아래 줄에 두면 스크롤한 뒤에도
            // 두 줄이 남아 네비 바로 안 읽힌다. 큰 날짜는 그 아래 줄에 있다가 자리를 내준다.
            ZStack {
                collapsedTitle.collapsingInlineTitle(collapse)
                // 두 버튼이 각자 유리를 진다 — 하나로 묶으면 화면 폭을 가로지르는 알약이 된다.
                HStack(spacing: 0) {
                    Button(Wording.cancel) { isConfirmingCancel = true }
                        .buttonStyle(PlainActionStyle())
                        .glassEffect(.regular, in: .capsule)
                    Spacer(minLength: 0)
                    Menu {
                        Button(Wording.editOccurredAt) { isEditingOccurredAt = true }
                    } label: {
                        GlyphIcon(Glyph.more)
                            .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                            .foregroundStyle(Palette.accent)
                    }
                    .accessibilityLabel(Wording.moreActions)
                    .glassEffect(.regular, in: .circle)
                }
            }
            .frame(height: Layout.hitTarget)

            dateTitle(Typography.plexTitle(Typography.headerLarge))
                .collapsingLargeTitle(collapse)

            Text(subtitle)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.secondaryLabel)
                .collapsingSummary(collapse)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .readableWidth()
        .headerScrim()
    }

    private func dateTitle(_ font: Font) -> Text {
        Text(Wording.dateHeader(draft.occurredAt.calendarDay))
            .font(font)
            .foregroundStyle(Palette.label)
    }

    /// 접힌 자리 — 날짜와 부제를 함께 진다.
    private var collapsedTitle: some View {
        VStack(spacing: 0) {
            dateTitle(Typography.time)
            Text(subtitle)
                .font(Typography.note)
                .foregroundStyle(Palette.secondaryLabel)
        }
        .lineLimit(1)
        .glassCapsule()
    }

    /// `09-N3` — 뺀 것이 0이면 어포던스를, 하나라도 빼면 수를 말한다.
    private var subtitle: String {
        draft.removedCount == 0
            ? Wording.keptAll(draft.included.count)
            : Wording.kept(draft.included.count, removed: draft.removedCount)
    }

    // MARK: - `09-G` 격자

    /// 열 수는 폭이 정한다 — 근거는 `Layout.editorColumns(inWidth:)`에 있다.
    private func grid(width: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.cellGap),
                                 count: Layout.editorColumns(inWidth: width)),
                  spacing: Spacing.cellGap) {
            ForEach(draft.photos) { photo in
                RecordPhotoTile(isIncluded: photo.isIncluded) { image(of: photo) }
                    .aspectRatio(1, contentMode: .fit)
                    .contentShape(.rect)
                    .onTapGesture { draft.toggle(photo.id) }
            }
            addPhotosCell
        }
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .padding(.top, 10)
    }

    /// `09-G2` — 격자의 마지막 칸이다.
    private var addPhotosCell: some View {
        Button { isAddingPhotos = true } label: {
            VStack(spacing: Spacing.cellGap) {
                GlyphIcon(Glyph.add, size: 26)
                Text(Wording.addPhotos)
                    .font(Typography.subtitle)
            }
            .foregroundStyle(Palette.secondaryLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.surface)
            .clipShape(.rect(cornerRadius: Radius.thumbnail))
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func image(of photo: DraftPhoto) -> some View {
        if let asset = photo.asset {
            AssetImage(asset: asset, pixels: ImageStore.gridPixels, fills: true,
                       retryToken: library.generation)
        } else if let stored = photo.storedImage {
            // `ARC-06` — 고치는 중인 기록의 사진은 앨범이 아니라 그 기록의 디렉터리에서 온다.
            RecordImageView(url: store.imageURL(recordID: draft.id, image: stored),
                            pixels: ImageStore.gridPixels,
                            fit: .free(fills: true))
        } else {
            ImportedImage(data: draft.importedData(of: photo.id))
        }
    }

    // MARK: - `09-G3` 설명

    /// `09-G3` — 배경도 테두리도 없고 경계를 밑줄 하나가 진다.
    private var caption: some View {
        TextField(Wording.captionPlaceholder, text: captionText, axis: .vertical)
            .font(Typography.body)
            .foregroundStyle(Palette.label)
            .focused($captionFocused)
            .lineLimit(3...)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(captionFocused ? Palette.accent : Palette.inputUnderline)
                    .frame(height: 1)
            }
            .padding(.leading, leadingMargin)
            .padding(.trailing, Spacing.screenMargin)
            // 격자와의 간격. 8이면 `＋ 사진 더하기` 칸 바로 아래라 붙어 보인다.
            .padding(.top, 16)
    }

    // MARK: - `09-T` 툴바

    /// `09-T` — iPad·macOS는 슬롯이 둘이라 카드가 서고, iPhone은 저장 버튼 하나만 뜬다.
    @ViewBuilder
    private var toolbar: some View {
        Group {
            if sizeClass == .regular {
                FloatingBar {
                    // ⚠️ 동작은 캔버스 화면이 생길 때 붙는다.
                    Button(Wording.makeCanvas) {}
                        .buttonStyle(PlainActionStyle())
                    Spacer(minLength: 0)
                    saveButton(PrimaryActionStyle())
                }
            } else {
                saveButton(GlassActionStyle())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.leading, leadingMargin)
        .padding(.trailing, Spacing.screenMargin)
        .padding(.bottom, 12)
        .readableWidth(alignment: .center)
    }

    /// 재질은 자리가 정한다 — 카드 안이면 내용물이라 불투명, 홀로 뜨면 유리다.
    private func saveButton(_ style: some ButtonStyle) -> some View {
        Button(Wording.save) { Task { await save(status: .published) } }
            .buttonStyle(style)
            .disabled(!draft.canSave)
    }

    // MARK: - 제본

    /// 좌측 여백 **안쪽**에 흐른다 — 거터를 새로 만들지 않으므로 격자 상수가 안 움직인다.
    @ViewBuilder
    private var binding: some View {
        if sizeClass == .compact { ThreadBinding() }
    }

    // MARK: - 조각

    /// 좌우가 비대칭인 것은 제본이 왼쪽에만 있기 때문이다. 일기장에서도 안쪽 여백이 더 넓다.
    private var leadingMargin: CGFloat {
        sizeClass == .compact ? Spacing.bindingMargin : Spacing.screenMargin
    }

    private var captionText: Binding<String> {
        Binding(get: { draft.caption }, set: { draft.caption = $0 })
    }

    private var saveFailed: Binding<Bool> {
        Binding(get: { draft.saveState.isFailed }, set: { if !$0 { draft.clearFailure() } })
    }

    private func save(status: Record.Status) async {
        guard await draft.save(status: status, to: store, bytes: originalBytes) != nil else { return }
        onClose()
    }
}

/// `09-N4` — `REC-07`은 자주 쓰는 기능이 아니라 화면에 행을 두지 않고 더보기 안에 산다.
private struct OccurredAtSheet: View {
    let initial: WallClock
    let onPick: (WallClock) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(initial: WallClock, onPick: @escaping (WallClock) -> Void) {
        self.initial = initial
        self.onPick = onPick
        _date = State(initialValue: initial.localDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            // ⚠️ 그래픽 달력은 시트 하나를 다 쓴다 — `.medium`에 넣으면 열리자마자 잘려 있어
            // 스크롤해야 보인다(2026-08-11 실기기).
            ScrollView {
                DatePicker(Wording.editOccurredAt, selection: $date)
                    .datePickerStyle(.graphical)
                    .padding(Spacing.screenMargin)
            }
            .navigationTitle(Wording.editOccurredAt)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Wording.cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Wording.confirm) {
                            if let picked = WallClock(local: date) { onPick(picked) }
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// ⚠️ **벽시계를 로컬 달력으로 그대로 읽고 쓴다.** 시간대를 더하거나 빼지 않는다 —
/// 사용자가 고르며 보는 값이 곧 저장되는 값이어야 한다.
private extension WallClock {
    var localDate: Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day,
                                                   hour: hour, minute: minute, second: second))
    }

    init?(local date: Date) {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let hour = parts.hour, let minute = parts.minute, let second = parts.second
        else { return nil }
        self.init(year: year, month: month, day: day,
                  hour: hour, minute: minute, second: second, hundredth: 0)
    }
}
