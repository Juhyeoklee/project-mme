// `06` 사진 전체화면. 순간의 사진 전부를 좌우로 넘긴다 — **연사도 펴서 넘기고, 순환하지 않고,
// 다음 순간으로도 안 넘어간다.**

import MomentKernel
import PhotoSource
import SwiftUI

struct PhotoViewerScreen: View {
    let library: MomentLibrary
    let moment: Moment
    let start: Int

    @Environment(\.dismiss) private var dismiss
    @State private var current: Int
    @State private var showsChrome = true
    @State private var zoom: CGFloat = 1
    @State private var closeDrag: CGFloat = 0

    private let photos: [Int]

    init(library: MomentLibrary, moment: Moment, start: Int) {
        self.library = library
        self.moment = moment
        self.start = start
        self.photos = moment.photoIndices
        _current = State(initialValue: max(0, moment.photoIndices.firstIndex(of: start) ?? 0))
    }

    var body: some View {
        ZStack {
            Palette.viewerBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(Array(photos.enumerated()), id: \.offset) { position, photoIndex in
                    ZoomablePhoto(asset: library.asset(at: photoIndex),
                                  retryToken: library.generation,
                                  zoom: $zoom)
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .scaleEffect(closeScale)
            .offset(y: closeDrag)

            if showsChrome { chrome }
        }
        // ⚠️ 안 비우면 옅어지는 검정 뒤로 `05`가 아니라 시스템 배경(라이트에서 흰색)이 나온다.
        .presentationBackground(.clear)
        .statusBarHidden(!showsChrome)
        .contentShape(.rect)
        .onTapGesture { showsChrome.toggle() }
        .gesture(closeGesture)
        .onChange(of: zoom) { _, value in
            if value > 1 { showsChrome = false }
        }
        // 장을 넘기면 확대가 풀린다. 안 풀면 다음 장이 이유 없이 확대된 채로 열린다.
        .onChange(of: current) { zoom = 1 }
    }

    // MARK: - 크롬

    private var chrome: some View {
        VStack {
            ZStack {
                Text(Wording.time(timeOfCurrent))
                    .font(Typography.time)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(Typography.time)
                            .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.screenMargin)

            Spacer()

            Text(Wording.position(current, of: photos.count))
                .font(Typography.caption)
                .padding(.bottom, Spacing.screenMargin)
        }
        .foregroundStyle(.white)
        .padding(.top, Spacing.momentGap)
    }

    /// **지금 보고 있는 그 사진의 시각이다** — 옆의 `06-N3`이 사진 단위라 짝이 맞고,
    /// 순간의 시각은 바로 앞 화면이 이미 말했다.
    private var timeOfCurrent: WallClock {
        guard photos.indices.contains(current),
              let at = library.capturedAt(at: photos[current]) else { return moment.start }
        return at
    }

    // MARK: - 아래로 끌어 닫기

    private var backgroundOpacity: Double {
        max(0.2, 1 - Double(closeDrag) / 400)
    }

    private var closeScale: CGFloat {
        max(0.85, 1 - closeDrag / 1200)
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard zoom <= 1, value.translation.height > 0 else { return }
                closeDrag = value.translation.height
            }
            .onEnded { value in
                guard zoom <= 1 else { return }
                if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.snappy) { closeDrag = 0 }
                }
            }
    }
}

/// 한 장. 핀치 확대 · 더블탭 fit↔2배 · 확대 상태에서 팬.
private struct ZoomablePhoto: View {
    let asset: SourceAsset?
    let retryToken: Int
    @Binding var zoom: CGFloat

    @State private var committed: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        AssetImage(asset: asset,
                   pixels: ImageStore.fullPixels,
                   fills: false,
                   emptyColor: Palette.viewerBackground,
                   // ⚠️ 여백도 검정이어야 한다 — 라이트에서 흰 여백이 깔리면
                   // 그 위의 흰 크롬이 사라진다 (2026-08-04 실기기).
                   matteColor: Palette.viewerBackground,
                   // 여기서만 네트워크를 연다 — 사용자가 이 한 장을 지목했다.
                   allowingNetwork: true,
                   retryToken: retryToken)
            .scaleEffect(zoom)
            .offset(offset)
            .gesture(magnify)
            // **확대 상태에서 팬이 우선이다** — 경계를 넘겨야 다음 장으로 넘어간다.
            .gesture(zoom > 1 ? pan : nil)
            .onTapGesture(count: 2) { toggleZoom() }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { zoom = max(1, committed * $0.magnification) }
            .onEnded { _ in
                committed = zoom
                if zoom <= 1 { reset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged {
                offset = CGSize(width: committedOffset.width + $0.translation.width,
                                height: committedOffset.height + $0.translation.height)
            }
            .onEnded { _ in committedOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.snappy) {
            if zoom > 1 {
                reset()
            } else {
                zoom = 2
                committed = 2
            }
        }
    }

    private func reset() {
        zoom = 1
        committed = 1
        offset = .zero
        committedOffset = .zero
    }
}

#if DEBUG
#Preview("06 전체화면") {
    PhotoViewerScreen(library: Fixture.library,
                      moment: Fixture.momentWithBurst,
                      start: Fixture.momentWithBurst.photoIndices[0])
        .environment(Fixture.store)
}
#endif
