// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ScannerRuntime", targets: ["ScannerRuntime"])
    ],
    targets: [
        .target(
            name: "ScannerRuntime",
            path: ".",
            sources: [
                "FrameExtraction",
                "ImageCorrection",
                "PageAudit",
                "PipelineCore",
                "OCRExport/Sources/OCRExport",
                "PipelineOCR",
                "PackageValidation/Sources/PackageValidation"
            ]
        )
    ]
)
