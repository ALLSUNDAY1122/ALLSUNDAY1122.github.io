// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KanteishiCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "KanteishiCore", targets: ["KanteishiCore"])
    ],
    targets: [
        .target(name: "KanteishiCore"),
        .testTarget(name: "KanteishiCoreTests", dependencies: ["KanteishiCore"])
    ]
)
