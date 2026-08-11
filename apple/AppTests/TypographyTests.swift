// 서체 — 등록이 실패하면 시스템 서체로 조용히 대체된다. 그 상태를 여기서 잡는다.

import SwiftUI
import Testing
@testable import Moanogi

@Suite("서체")
struct TypographyTests {

    // MARK: - 계약

    @Test func 번들_서체_여섯이_모두_이름으로_열린다() {
        Typography.register()

        for name in Typography.faceNames {
            #expect(UIFont(name: name, size: 16) != nil, "\(name)")
        }
    }

    @Test func 등록은_여러_번_불러도_안전하다() {
        Typography.register()
        Typography.register()

        #expect(UIFont(name: "IBMPlexSansKR-Regular", size: 16) != nil)
    }
}
