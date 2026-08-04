// `06` 사진 전체화면 — 사진 한 장을 원본 비율로 크게 본다.
//
// **여기서는 발명하지 않는다** (설계서 §4.4). 제스처가 낯설면 *"분류가 별로"* 인지
// *"조작이 불편"* 인지 섞여서 `M1`의 검증이 오염된다. iOS 사진 뷰어 관례를 그대로 따른다.
//
// 순번은 **장수 기준이다** (`3 / 12`). `05`에서 접힌 대표 컷으로 들어와도 좌우로 넘기면 연사 컷이
// 전부 나온다 — **전체화면은 접기가 없는 층위다.** 여기서까지 접으면 펼치기가 두 곳에 생긴다.
//
// **순환하지 않는다.** 순환하면 어디가 끝인지 모르게 되어 *"다 봤다"* 는 종료감이 사라진다.
// 다음 순간으로 넘어가는 것도 없다 — 순간 경계가 흐려진다.

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
            // `06-G2` 배경. 모드를 따르지 않는 고정 검정 — 아래로 끌수록 옅어진다.
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
        // 표현 배경을 비운다. 아래로 끌 때 옅어지는 검정 뒤로 **`05`가 실제로 드러나야**
        // *"끌수록 축소되고 배경이 옅어진다"* 가 성립한다. 비우지 않으면 시스템 배경(라이트에서 흰색)이 나온다.
        .presentationBackground(.clear)
        .statusBarHidden(!showsChrome)
        .contentShape(.rect)
        .onTapGesture { showsChrome.toggle() }
        .gesture(closeGesture)
        // **확대 상태에서 크롬은 자동으로 숨는다** (설계서 §4.3). 사진이 화면을 넘어간 순간
        // 크롬은 사진 위에 떠 있는 것이 되어 방해가 된다.
        .onChange(of: zoom) { _, value in
            if value > 1 { showsChrome = false }
        }
        // 장을 넘기면 확대가 풀린다. 안 풀면 다음 장이 이유 없이 확대된 채로 열린다.
        .onChange(of: current) { zoom = 1 }
    }

    // MARK: - 크롬

    /// `06-N1`~`06-N3`은 **한 덩어리로 같이 사라진다.**
    private var chrome: some View {
        VStack {
            ZStack {
                Text(Wording.time(timeOfCurrent))
                    .font(Typography.time)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(Typography.time)
                            .frame(width: 44, height: 44)
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

    /// 순번이 가리키는 사진의 촬영 시각. 순간이 시간 오름차순이므로 장면을 이어 붙인 순서와 같다.
    private var timeOfCurrent: WallClock {
        // 커널은 사진별 시각을 순간 단위로 내주지 않는다 — 순간의 시작·끝만 있다.
        // 표시에 필요한 것은 "이 장이 언제인가"인데 `M1`에서 그 값을 얻는 통로가 없어
        // 순간의 시작 시각을 쓴다. **`05`의 타이틀과 같은 값이라 어긋나 보이지 않는다.**
        moment.start
    }

    // MARK: - 아래로 끌어 닫기

    private var backgroundOpacity: Double {
        max(0.2, 1 - Double(closeDrag) / 400)
    }

    private var closeScale: CGFloat {
        max(0.85, 1 - closeDrag / 1200)
    }

    /// **확대 상태에서 아래로 끄는 것은 팬이지 닫기가 아니다** (설계서 §4.4).
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
                   // 사진 밖은 `06-G2`다. 모드를 따르지 않는다 — 라이트에서 흰 여백이 깔리면
                   // 그 위의 흰 크롬이 사라진다 (2026-08-04 실기기).
                   matteColor: Palette.viewerBackground,
                   // 사용자가 **이 한 장을 지목했다.** 목록에서와 달리 여기서는 값을 치른다.
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
