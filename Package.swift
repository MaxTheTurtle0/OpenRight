// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenRight",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenRight", targets: ["OpenRight"]),
               .library(name: "OpenRightCore", targets: ["OpenRightCore"])],
    targets: [
        .target(name: "OpenRightCore"),
        .executableTarget(name: "OpenRight", dependencies: ["OpenRightCore"]),
        .testTarget(name: "OpenRightCoreTests", dependencies: ["OpenRightCore"]),
        .testTarget(name: "OpenRightTests", dependencies: ["OpenRight", "OpenRightCore"])
    ]
)
