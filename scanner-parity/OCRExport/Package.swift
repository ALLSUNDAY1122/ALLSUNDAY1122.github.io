// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityOCRExport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "OCRExport", targets: ["OCRExport"])
    ],
    targets: [
        .target(name: "OCRExport"),
        .testTarget(name: "OCRExportTests", dependencies: ["OCRExport"])
    ]
)
