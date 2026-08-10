// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LearningSprintCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LearningSprintCore", targets: ["LearningSprintCore"])
    ],
    targets: [
        .target(name: "LearningSprintCore"),
        .testTarget(name: "LearningSprintCoreTests", dependencies: ["LearningSprintCore"])
    ]
)
