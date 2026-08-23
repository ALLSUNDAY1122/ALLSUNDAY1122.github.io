// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityPackageValidation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PackageValidation", targets: ["PackageValidation"])
    ],
    targets: [
        .target(name: "PackageValidation"),
        .testTarget(name: "PackageValidationTests", dependencies: ["PackageValidation"])
    ]
)
