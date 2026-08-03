// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PhotoSource",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "PhotoSource", targets: ["PhotoSource"]),
    ],
    dependencies: [
        .package(path: "../MomentKernel"),
    ],
    targets: [
        .target(
            name: "PhotoSource",
            dependencies: [.product(name: "MomentKernel", package: "MomentKernel")]
        ),
        .testTarget(name: "PhotoSourceTests", dependencies: ["PhotoSource"]),
    ]
)
