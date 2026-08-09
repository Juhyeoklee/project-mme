// swift-tools-version: 6.2
import PackageDescription

// `MomentKernel` 의존을 지웠다 (2026-08-03).
// 간선의 원래 근거는 ADR `0001` 결정 2의 "계약 타입의 주인은 커널" 이었는데,
// ADR `0002`가 커널 입력을 (파일명, 바이트)로 바꿔 어댑터가 커널에서 가져올 타입이 남지 않았다.
// 이유 없는 간선은 결정 1이 반대하는 것이다. 지우면 컴파일러가 그 방향을 다시 막는다.
let package = Package(
    name: "PhotoSource",
    // macOS는 CI가 `swift test`를 macOS로 돌기 때문에 선언한다 — 제품 지원 선언은 `M3`에서 다시 본다.
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PhotoSource", targets: ["PhotoSource"]),
    ],
    targets: [
        .target(name: "PhotoSource"),
        .testTarget(name: "PhotoSourceTests", dependencies: ["PhotoSource"]),
    ]
)
