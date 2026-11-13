// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NutmegCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NutmegCore", targets: ["NutmegCore"])],
    targets: [
        .target(name: "NutmegCore", resources: [.process("Resources")]),
        .testTarget(name: "NutmegCoreTests", dependencies: ["NutmegCore"])
    ]
)
