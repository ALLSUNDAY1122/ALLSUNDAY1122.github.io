// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HomeCourtCVCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HomeCourtCVCore", targets: ["HomeCourtCVCore"])
    ],
    targets: [
        .target(
            name: "HomeCourtCVCore",
            path: ".",
            exclude: ["Tests"]
        ),
        .testTarget(
            name: "HomeCourtCVCoreTests",
            dependencies: ["HomeCourtCVCore"],
            path: "Tests/HomeCourtCVCoreTests"
        )
    ]
)
