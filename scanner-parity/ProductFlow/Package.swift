// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProductFlow",
    platforms: [.iOS(.v17)],
    products: [.library(name: "ProductFlow", targets: ["ProductFlow"])],
    targets: [.target(name: "ProductFlow")]
)
