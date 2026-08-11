// 실 제본 — 바탕 문법. 지면을 가진 화면이 전부 쓴다.

import SwiftUI

/// 좌측 여백 **안쪽**에 흐르는 실 제본.
///
/// 거터를 새로 만들지 않고 기존 여백 안에 살기 때문에 **격자 상수가 안 움직인다.**
/// `06` 전체화면과 `11` 캔버스에는 없다 — 지면이 아니라 몰입 층위다.
struct ThreadBinding: View {
    /// 땀 하나의 길이이자 땀 사이 간격.
    private static let stitch: CGFloat = 9
    private static let thickness: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: Self.stitch) {
                ForEach(0..<stitchCount(in: geometry.size.height), id: \.self) { _ in
                    Rectangle()
                        .fill(Palette.binding)
                        .frame(width: Self.thickness, height: Self.stitch)
                }
            }
        }
        .frame(width: Self.thickness)
        .padding(.leading, 8)
        .padding(.top, 12)
        .allowsHitTesting(false)
    }

    private func stitchCount(in height: CGFloat) -> Int {
        max(1, Int(ceil(height / (Self.stitch * 2))))
    }
}
