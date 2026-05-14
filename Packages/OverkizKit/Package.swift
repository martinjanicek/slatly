// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OverkizKit",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "OverkizKit", targets: ["OverkizKit"]),
    ],
    targets: [
        .target(name: "OverkizKit"),
        .testTarget(name: "OverkizKitTests", dependencies: ["OverkizKit"]),
    ],
    swiftLanguageModes: [.v6]
)
