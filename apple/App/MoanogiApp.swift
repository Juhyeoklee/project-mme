import SwiftUI

// 화면(04·05·06)은 다음 세션 — 지금 서 있는 것은 R8 프로브뿐이고, 화면이 들어올 때 지운다.
@main
struct MoanogiApp: App {
    var body: some Scene {
        WindowGroup {
            R8ProbeView()
        }
    }
}
