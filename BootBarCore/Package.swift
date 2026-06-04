// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BootBarCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BootBarCore", targets: ["BootBarCore"])
    ],
    targets: [
        .target(name: "BootBarCore"),
        .testTarget(name: "BootBarCoreTests", dependencies: ["BootBarCore"])
    ]
)
