// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDuoBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacDuoBar", targets: ["MacDuoBar"])],
    targets: [
        .executableTarget(name: "MacDuoBar"),
        .testTarget(name: "MacDuoBarTests", dependencies: ["MacDuoBar"])
    ]
)
