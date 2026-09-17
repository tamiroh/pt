// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pt",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "pt", targets: ["Pt"])],
    targets: [
        .executableTarget(name: "Pt"),
        .testTarget(name: "PtTests", dependencies: ["Pt"]),
    ]
)
