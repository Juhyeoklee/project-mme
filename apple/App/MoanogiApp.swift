import MomentKernel
import PhotoSource
import SwiftUI

/// 소스로 고정한 앨범. **출시 1은 소스를 코드에 고정한다.**
/// 어느 이름이 게임 것인지는 `App`이 알고 어댑터는 모른다 (ADR 0002 근거 1).
private let gameAlbumTitle = "Mabinogi Mobile"

@main
struct MoanogiApp: App {
    @State private var library = MomentLibrary(albumTitle: gameAlbumTitle)
    @State private var store = ImageStore(source: AlbumPhotoSource(albumTitle: gameAlbumTitle))

    // `Scene`을 한정하는 이유 — 커널에도 `Scene`이 있다(연사 묶음). 이름이 겹치는 곳은 여기 한 곳뿐이고,
    // 커널 쪽 이름은 `MOM-04`가 정한 도메인 어휘라 바꾸지 않는다.
    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView(library: library)
                .environment(store)
                .task { library.start() }
        }
    }
}

/// 기기 분기가 사는 유일한 자리. 화면 셋은 자기가 어느 레이아웃 안에 있는지 모른다.
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
                        // `05-N1` 뒤로 `‹`는 여기서 코드로 만들지 않는다 — push된 화면에
                        // 시스템이 붙여준다. iPad에서는 push가 아니라 pane 교체라 안 붙는다.
                        // 설계서 §3.6의 "iPhone만 있음"이 분기 없이 성립하는 자리다.
                        MomentDetailScreen(library: library, moment: moment)
                    }
            }
        }
    }

    /// iPad 2단. 목록 pane 34% — 그 값이 iPhone과 **같은 3장/행**을 만든다 (설계서 §1.2).
    private var splitLayout: some View {
        GeometryReader { geometry in
            NavigationSplitView {
                MomentListScreen(library: library, selection: $selected)
                    .navigationSplitViewColumnWidth(geometry.size.width * Layout.listPaneFraction)
            } detail: {
                if let moment = selected ?? library.days.first?.moments.first {
                    // iPad에서 `05`는 "들어가는 화면"이 아니라 **항상 떠 있는 화면**이다.
                    // 그래서 뒤로가 없다 (설계서 §3.6).
                    MomentDetailScreen(library: library, moment: moment)
                } else {
                    Color.clear
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
    }
}
