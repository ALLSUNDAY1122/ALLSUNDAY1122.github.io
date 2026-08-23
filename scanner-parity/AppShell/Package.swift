// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [.package(path: "../ProductFlow")],
    targets: [.target(name: "AppShell", dependencies: ["ProductFlow"])]
)
