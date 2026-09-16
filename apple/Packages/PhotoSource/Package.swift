// swift-tools-version: 6.2
import PackageDescription

// `MomentKernel`에 의존하지 않는다 — 커널 입력이 (파일명, 바이트)라 어댑터가 커널에서
// 가져올 타입이 없다. 이유 없는 간선을 안 두어야 컴파일러가 그 방향을 막는다.
let package = Package(
    name: "PhotoSource",
    // macOS는 제품 플랫폼이다 — `swift test`가 호스트(macOS)로 도는 것과는 별개로,
    // 앱의 macOS 하한과 같은 값을 든다.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PhotoSource", targets: ["PhotoSource"]),
        .library(name: "PhotoSourceUI", targets: ["PhotoSourceUI"]),
    ],
    targets: [
        .target(name: "PhotoSource"),
        // 사용자가 건네는 사진(`REC-10`). **`PhotoSource`에 의존하지 않는다** —
        // 소스를 넓히지 않고 바이트만 넘기므로 가져올 타입이 없다.
        .target(name: "PhotoSourceUI"),
        .testTarget(name: "PhotoSourceTests", dependencies: ["PhotoSource"]),
    ]
)
