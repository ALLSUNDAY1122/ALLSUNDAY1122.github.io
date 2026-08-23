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
            exclude: [
                "AppShell",
                "AppleValidation",
                "GoldenEvaluation",
                "LongRun",
                "PackageQuality",
                "PrivacyAudit",
                "ProductFlow",
                "Recovery",
                "ReviewCore",
                "SecurityHardening",
                "Tests",
                "iOSApp"
            ],
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
