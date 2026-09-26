// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GK2Core",
    defaultLocalization: "es",
    // macOS solo para poder ejecutar `swift test` en el Mac; la app es solo iOS
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GK2Core", targets: ["GK2Core"])],
    targets: [
        // no se llama «Resources»: en iOS codesign rechaza un bundle con esa carpeta en la raíz
        .target(name: "GK2Core", resources: [.copy("Data")]),
        .testTarget(name: "GK2CoreTests", dependencies: ["GK2Core"]),
    ]
)
