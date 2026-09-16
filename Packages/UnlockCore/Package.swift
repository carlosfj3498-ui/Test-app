// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnlockCore",
    defaultLocalization: "es",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "UnlockCore", targets: ["UnlockCore"])
    ],
    targets: [
        .target(name: "UnlockCore"),
        .testTarget(name: "UnlockCoreTests", dependencies: ["UnlockCore"])
    ]
)
