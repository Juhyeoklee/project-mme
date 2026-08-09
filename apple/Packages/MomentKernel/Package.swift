// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MomentKernel",
    // iOS 26 — 검증 기기(iPhone iOS 26.5.2 · iPad 최신 추정)가 도는 최신 메이저.
    // `M1`은 배포가 없어 하한을 넓게 지킬 이유가 없다 (2026-08-03).
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "MomentKernel", targets: ["MomentKernel"]),
    ],
    targets: [
        .target(name: "MomentKernel"),
        .testTarget(name: "MomentKernelTests", dependencies: ["MomentKernel"]),
    ]
)
