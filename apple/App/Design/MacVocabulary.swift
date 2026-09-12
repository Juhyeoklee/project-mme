// macOS에 없는 iOS 어휘를 메운다. **분기가 여기서 끝나고 밖으로 안 샌다.**
// ⚠️ 자격은 하나 — **사용자가 보는 것이 같은가.** 다르면 쓰는 파일이 가른다.
// 자격 없는 자리를 목록으로 적지 않는다 — 열거하는 자는 샌다.

#if os(macOS)
import SwiftUI

/// ⚠️ **위 자격을 알고 넘은 유일한 자리다** — 창을 늘 넓은 판으로 쳐서 iPad 판이 그대로 뜬다.
/// 무엇으로 가를지는 macOS 화면설계가 정한다.
enum UserInterfaceSizeClass: Hashable {
    case compact
    case regular
}

extension EnvironmentValues {
    var horizontalSizeClass: UserInterfaceSizeClass? { .regular }
}

extension ToolbarPlacement {
    /// 시스템 바를 숨기려는 것이라 macOS에서는 창 툴바가 그 자리다.
    static var navigationBar: ToolbarPlacement { .windowToolbar }
}

typealias UIColor = NSColor
#endif
