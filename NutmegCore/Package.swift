// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NutmegCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NutmegCore", targets: ["NutmegCore"])],
    targets: [
        .target(name: "NutmegCore", dependencies: ["SignalsmithShift"], resources: [.process("Resources")]),
        // Nutmeg's +2 semitone pitch raise (decisions/2026-11-17-voice-pitch-build.md): Signalsmith Stretch 1.4.0 and
        // Signalsmith Linear 0.6.6 (both MIT, vendored unmodified with their LICENSE files: upstream has no
        // Package.swift) behind a small C API. Always optimized (Debug at -O0 is ~10x slower); no -ffast-math (the
        // Stretch README: Apple Clang 16.0.0 miscompiles it).
        .target(
            name: "SignalsmithShift",
            exclude: [
                "vendor/PINNED.txt",
                "vendor/signalsmith-stretch/LICENSE.txt", "vendor/signalsmith-stretch/README.md",
                "vendor/signalsmith-linear/LICENSE.txt", "vendor/signalsmith-linear/README.md",
            ],
            cxxSettings: [
                .headerSearchPath("vendor/signalsmith-linear/include"),
                .define("SIGNALSMITH_USE_ACCELERATE"),
                .unsafeFlags(["-O3"]),
            ],
            linkerSettings: [.linkedFramework("Accelerate")]
        ),
        .testTarget(name: "NutmegCoreTests", dependencies: ["NutmegCore"])
    ],
    cxxLanguageStandard: .cxx17
)
