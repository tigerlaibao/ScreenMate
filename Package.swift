// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenMate",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ScreenMate", targets: ["ScreenMate"])],
    targets: [
        .target(name: "LayoutCore"),
        .target(name: "Localization", resources: [.process("Resources")]),
        .executableTarget(name: "ScreenMate", dependencies: ["LayoutCore", "Localization"]),
        .testTarget(name: "LayoutCoreTests", dependencies: ["LayoutCore"]),
        .testTarget(name: "LocalizationTests", dependencies: ["Localization"])
    ]
)
