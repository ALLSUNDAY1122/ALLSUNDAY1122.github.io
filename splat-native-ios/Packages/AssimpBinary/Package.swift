// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScanLabAssimp",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "AssimpBinary", targets: ["AssimpBinary"]),
    ],
    targets: [
        .binaryTarget(
            name: "AssimpBinary",
            url: "https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/releases/download/scanlab-assimp-v6.0.5-1/Assimp-6.0.5-iOS.xcframework.zip",
            checksum: "4ba91ff505d8703f24542a89de5ca9a5031ff70cb38fc87558bee8a3d4f1f1f0"
        ),
    ]
)
