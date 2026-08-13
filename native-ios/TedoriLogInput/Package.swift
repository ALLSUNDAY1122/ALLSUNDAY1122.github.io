// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TedoriLogInput",
    platforms: [
        .iOS(.v16),   // Visionの日本語テキスト認識はiOS16以降
        .macOS(.v13)  // CIでの実Vision評価に使う
    ],
    products: [
        .library(name: "TedoriLogCore", targets: ["TedoriLogCore"]),
        .library(name: "TedoriLogVision", targets: ["TedoriLogVision"])
    ],
    targets: [
        // 解析エンジン（Apple製フレームワークに依存しない＝どこでもテストできる）
        .target(name: "TedoriLogCore"),
        // 入力経路（PDFKit / Vision）
        .target(name: "TedoriLogVision", dependencies: ["TedoriLogCore"]),
        // fixtureはリポジトリ内の Fixtures/holdout を実行時に参照する（重複コピーを避けるため）
        .testTarget(name: "TedoriLogCoreTests", dependencies: ["TedoriLogCore"]),
        .testTarget(name: "TedoriLogVisionTests", dependencies: ["TedoriLogVision", "TedoriLogCore"])
    ]
)
