// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GK2Core",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GK2Core", targets: ["GK2Core"])],
    targets: [
        .target(name: "GK2Core", resources: [.copy("Resources")]),
        .testTarget(name: "GK2CoreTests", dependencies: ["GK2Core"]),
    ]
)
