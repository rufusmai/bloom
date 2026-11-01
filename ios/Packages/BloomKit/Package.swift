// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BloomKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BloomKit", targets: ["BloomKit"]),
    ],
    targets: [
        .target(name: "BloomKit"),
        .testTarget(name: "BloomKitTests", dependencies: ["BloomKit"]),
    ]
)
