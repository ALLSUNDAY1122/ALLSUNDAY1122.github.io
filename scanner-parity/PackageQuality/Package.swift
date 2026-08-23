// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityPackageQuality",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PackageQuality", targets: ["PackageQuality"])
    ],
    dependencies: [
        .package(name: "PackageValidationLocal", path: "../PackageValidation")
    ],
    targets: [
        .target(
            name: "PackageQuality",
            dependencies: [
                .product(name: "PackageValidation", package: "PackageValidationLocal")
            ]
        ),
        .testTarget(
            name: "PackageQualityTests",
            dependencies: ["PackageQuality", .product(name: "PackageValidation", package: "PackageValidationLocal")]
        )
    ]
)
