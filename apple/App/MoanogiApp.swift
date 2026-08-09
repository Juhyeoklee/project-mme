// 앱 진입점과 기기 분기. 화면 셋을 iPhone 푸시 / iPad 2단 중 하나에 앉힌다.
//
// **표현 분기가 사는 유일한 곳이다** (ADR `0001` 결정 5) — 커널은 분기가 금지돼 있고
// 어댑터는 조건문이 아니라 구현체 교체로 간다.

import MomentKernel
import PhotoSource
import SwiftUI

/// 출시 1은 소스를 코드에 고정한다. **어느 이름이 게임 것인지는 `App`만 안다** (ADR `0002`).
private let gameAlbumTitle = "Mabinogi Mobile"

@main
struct MoanogiApp: App {
    @State private var library = MomentLibrary(albumTitle: gameAlbumTitle)
    @State private var store = ImageStore(source: AlbumPhotoSource(albumTitle: gameAlbumTitle))

    // ⚠️ `SwiftUI.Scene`으로 한정한다 — 커널에도 `Scene`(연사 묶음)이 있다.
    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView(library: library)
                .environment(store)
                .task { library.start() }
        }
    }
}

/// 화면 셋은 자기가 어느 레이아웃 안에 있는지 모른다.
struct RootView: View {
    let library: MomentLibrary

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected: Moment?

    var body: some View {
        if sizeClass == .regular {
            splitLayout
        } else {
            NavigationStack {
                MomentListScreen(library: library, selection: nil)
                    .navigationDestination(for: Moment.self) { moment in
                        // 뒤로 버튼은 시스템이 붙여준다. iPad는 pane 교체라 안 붙어 분기가 없다.
                        MomentDetailScreen(library: library, moment: moment)
                    }
            }
        }
    }

    /// iPad 2단. 목록 pane 34%는 **iPhone과 같은 3장/행**이 나오는 값이라 어림수가 아니다.
    private var splitLayout: some View {
        GeometryReader { geometry in
            NavigationSplitView {
                MomentListScreen(library: library, selection: $selected)
                    .navigationSplitViewColumnWidth(geometry.size.width * Layout.listPaneFraction)
            } detail: {
                if let moment = selected ?? library.days.first?.moments.first {
                    MomentDetailScreen(library: library, moment: moment)
                } else {
                    Color.clear
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
    }
}
