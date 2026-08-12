// 전체화면 뷰어의 뼈대. `06`과 `08` 넘겨보기가 나눠 쓴다.
//
// **넘길 목록을 스스로 정하지 않는다** — 부르는 화면이 보여준 것이 그대로 와야, 화면에 없던
// 장이 뷰어에서 튀어나와 순번의 분모가 어긋나는 일이 없다.

import CoreGraphics
import SwiftUI

/// 좌우로 넘기고, 확대하고, 아래로 끌어 닫는다. **순환하지 않는다.**
///
/// 크롬은 두 줄뿐이다 — 위 가운데 한 줄, 아래 한 줄. 어느 줄이 무엇을 말하는지는 부르는
/// 화면이 정한다(`06`은 시각과 순번, `08`은 순번과 날짜).
struct ImageViewer<Page: View>: View {
    let count: Int
    /// 위 가운데 줄. 지금 장의 첨자를 받는다.
    let topLine: (Int) -> String
    /// 아래 줄. 비면 그리지 않는다.
    let bottomLine: (Int) -> String
    @ViewBuilder let page: (Int) -> Page

    @Environment(\.dismiss) private var dismiss
    @State private var current: Int
    @State private var showsChrome = true
    @State private var zoom: CGFloat = 1
    @State private var closeDrag: CGFloat = 0

    init(count: Int, start: Int, topLine: @escaping (Int) -> String,
         bottomLine: @escaping (Int) -> String, @ViewBuilder page: @escaping (Int) -> Page) {
        self.count = count
        self.topLine = topLine
        self.bottomLine = bottomLine
        self.page = page
        _current = State(initialValue: max(0, min(start, count - 1)))
    }

    var body: some View {
        ZStack {
            Palette.viewerBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(0..<count, id: \.self) { position in
                    Zoomable(zoom: $zoom) { page(position) }
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .scaleEffect(closeScale)
            .offset(y: closeDrag)

            if showsChrome { chrome }
        }
        // ⚠️ 안 비우면 옅어지는 검정 뒤로 부른 화면이 아니라 시스템 배경(라이트에서 흰색)이 나온다.
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
                Text(topLine(current))
                    .font(Typography.time)
                HStack {
                    // ⚠️ **닫기만 유리를 진다** — 밝은 사진 위에서 흰 글리프가 사라진다
                    // (2026-08-13 실기기). 나머지 크롬은 글자라 이 층위에 안 얹는다.
                    Button { dismiss() } label: {
                        GlyphIcon(Glyph.close, size: 18)
                            .frame(width: Layout.hitTarget, height: Layout.hitTarget)
                    }
                    .accessibilityLabel(Wording.close)
                    .glassEffect(.regular, in: .circle)
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.screenMargin)

            Spacer()

            Text(bottomLine(current))
                .font(Typography.subtitle)
                .padding(.bottom, Spacing.screenMargin)
        }
        // 뷰어 크롬의 글자는 모드를 따르지 않는다 — 배경이 늘 검정이다.
        .foregroundStyle(Paper.step2)
        .padding(.top, Spacing.momentGap)
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
private struct Zoomable<Content: View>: View {
    @Binding var zoom: CGFloat
    @ViewBuilder let content: Content

    @State private var committed: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        content
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
