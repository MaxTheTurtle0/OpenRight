// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenRight",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenRight", targets: ["OpenRight"]),
               .library(name: "OpenRightCore", targets: ["OpenRightCore"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .target(name: "OpenRightCore"),
        .executableTarget(name: "OpenRight", dependencies: ["OpenRightCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "OpenRightCoreTests", dependencies: ["OpenRightCore"]),
        .testTarget(name: "OpenRightTests", dependencies: ["OpenRight", "OpenRightCore"])
    ]
)
