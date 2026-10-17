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
            url: "https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/releases/download/scanlab-assimp-v6.0.5-2/Assimp-6.0.5-iOS.xcframework.zip",
            checksum: "323f517dd4200fc04886d1e979577abcadb3852a7de78028d0e54288e2671417"
        ),
    ]
)
