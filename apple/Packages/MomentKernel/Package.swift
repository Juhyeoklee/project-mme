// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MomentKernel",
    // iOS 26 — 검증 기기(iPhone iOS 26.5.2 · iPad 최신 추정)가 도는 최신 메이저.
    // `M1`은 배포가 없어 하한을 넓게 지킬 이유가 없다 (2026-08-03).
    // macOS 26은 제품 지원 선언이다 — 앱의 macOS 하한과 같은 값을 든다 (2026-08-24).
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MomentKernel", targets: ["MomentKernel"]),
    ],
    targets: [
        .target(name: "MomentKernel"),
        .testTarget(name: "MomentKernelTests", dependencies: ["MomentKernel"]),
    ]
)
