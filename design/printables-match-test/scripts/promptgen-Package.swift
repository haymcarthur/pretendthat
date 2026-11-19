// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "promptgen", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "/Users/haymcarthur/PretendThat/NutmegCore")],
  targets: [.executableTarget(name: "promptgen", dependencies: [.product(name: "NutmegCore", package: "NutmegCore")])])
