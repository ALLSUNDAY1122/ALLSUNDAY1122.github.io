// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ToruTangoOnDeviceAI",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "ToruTangoOnDeviceAI", targets: ["ToruTangoOnDeviceAI"])
  ],
  targets: [
    .target(
      name: "ToruTangoOnDeviceAI",
      path: "ios",
      exclude: ["ToruTangoOnDeviceAIModule.swift"]
    ),
    .testTarget(
      name: "ToruTangoOnDeviceAITests",
      dependencies: ["ToruTangoOnDeviceAI"],
      path: "Tests"
    )
  ]
)
