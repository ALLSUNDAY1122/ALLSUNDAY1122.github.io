import ImageIO
import XCTest
import UIKit
import simd

final class SplatSeedColorizerMultiViewTests: XCTestCase {
    func testThreeViewConsensusRejectsSingleColorOutlier() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-consensus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidImage(color: UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 1), name: "a.png", root: root)
        try writeSolidImage(color: UIColor(red: 0.12, green: 0.58, blue: 0.22, alpha: 1), name: "b.png", root: root)
        try writeSolidImage(color: UIColor(red: 0.95, green: 0.05, blue: 0.05, alpha: 1), name: "outlier.png", root: root)

        let frames = ["a.png", "b.png", "outlier.png"].map { name in
            SplatSeedFrame(filePath: name, transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        }

        let color = try XCTUnwrap(SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0, -1)], frames: frames, projectURL: root
        ).first)
        XCTAssertLessThan(color.red, 60)
        XCTAssertGreaterThan(color.green, 120)
        XCTAssertLessThan(color.blue, 80)
    }

    func testThreeViewConsensusNeverSynthesizesBlackFromPrimaryColorViews() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-observed-medoid")
        defer { try? FileManager.default.removeItem(at: root) }
        try writeSolidImage(color: .red, name: "red.png", root: root)
        try writeSolidImage(color: .green, name: "green.png", root: root)
        try writeSolidImage(color: .blue, name: "blue.png", root: root)
        let frames = ["red.png", "green.png", "blue.png"].map {
            SplatSeedFrame(filePath: $0, transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        }
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: frames, projectURL: root).first)
        let channels = [color.red, color.green, color.blue].sorted()
        XCTAssertLessThan(channels[1], 40)
        XCTAssertGreaterThan(channels[2], 220)
    }

    func testConsensusFallsBackToSingleVisibleView() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-single")
        defer { try? FileManager.default.removeItem(at: root) }
        try writeSolidImage(color: .blue, name: "near.png", root: root)
        try writeSolidImage(color: .red, name: "behind.png", root: root)
        let near = SplatSeedFrame(filePath: "near.png", transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        var behindRows = identityRows
        behindRows[2][3] = -2
        let behind = SplatSeedFrame(filePath: "behind.png", transformMatrix: behindRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: [near, behind], projectURL: root).first)
        XCTAssertGreaterThan(color.blue, 220)
        XCTAssertLessThan(color.red, 40)
    }

    func testMissingBestRankedFramePromotesNextUsableViewIntoConsensus() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-missing-view-promotion")
        defer { try? FileManager.default.removeItem(at: root) }
        try writeSolidImage(color: .red, name: "red.png", root: root)
        try writeSolidImage(color: .blue, name: "blue.png", root: root)
        try writeSolidImage(color: .green, name: "green.png", root: root)
        let frames = ["missing.png", "red.png", "blue.png", "green.png"].map {
            SplatSeedFrame(filePath: $0, transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        }
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: frames, projectURL: root).first)
        XCTAssertLessThan(color.red, 40)
        XCTAssertLessThan(color.green, 40)
        XCTAssertGreaterThan(color.blue, 220)
    }

    func testChainedThumbnailDecodeFailuresPromoteLaterHealthyView() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-chained-decode-recovery")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidImage(color: .red, name: "red.png", root: root)
        try writeSolidImage(color: .blue, name: "blue.png", root: root)
        try writeHeaderOnlyPNG(name: "broken-a.png", root: root)
        try writeHeaderOnlyPNG(name: "broken-b.png", root: root)
        try writeSolidImage(color: .green, name: "green.png", root: root)

        let frames = ["red.png", "blue.png", "broken-a.png", "broken-b.png", "green.png"].map {
            SplatSeedFrame(filePath: $0, transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        }
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0, -1)], frames: frames, projectURL: root
        ).first)

        // Initial top-3 = red/blue/broken-a. Wave 1 promotes broken-b, which also cannot decode.
        // Wave 2 must then promote green. A one-wave repair stops at red+blue and becomes purple;
        // full chained recovery restores the deterministic red/blue/green medoid (blue).
        XCTAssertLessThan(color.red, 40)
        XCTAssertLessThan(color.green, 40)
        XCTAssertGreaterThan(color.blue, 220)
    }

    func testSeedColorizerRejectsImagePathEscapingProject() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("splat-seed-containment-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        try writeSolidImage(color: .red, name: "outside.png", root: parent)
        let frame = SplatSeedFrame(filePath: "../outside.png", transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: [frame], projectURL: root).first)
        XCTAssertEqual(color.red, SplatSeedColorizer.fallback.red)
        XCTAssertEqual(color.green, SplatSeedColorizer.fallback.green)
        XCTAssertEqual(color.blue, SplatSeedColorizer.fallback.blue)
    }

    func testLargeSourceFrameStillSamplesCorrectColorThroughBoundedRasterDecode() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-large-raster")
        defer { try? FileManager.default.removeItem(at: root) }
        let size = CGSize(width: 4096, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.20, green: 0.70, blue: 0.30, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        try XCTUnwrap(image.pngData()).write(to: root.appendingPathComponent("wide.png"))
        let frame = SplatSeedFrame(filePath: "wide.png", transformMatrix: identityRows, flX: 1000, flY: 1000, cx: 2048, cy: 32, w: 4096, h: 64)
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: [frame], projectURL: root).first)
        XCTAssertGreaterThan(color.green, 150)
        XCTAssertLessThan(color.red, 80)
        XCTAssertLessThan(color.blue, 110)
        XCTAssertEqual(SplatSeedColorizer.maximumRasterDimension, 2_048)
    }

    func testEqualScoreFramesKeepStableFirstThreeConsensusAfterTopKOptimization() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-topk")
        defer { try? FileManager.default.removeItem(at: root) }
        let colors: [UIColor] = [
            UIColor(red: 0.08, green: 0.65, blue: 0.12, alpha: 1),
            UIColor(red: 0.10, green: 0.68, blue: 0.14, alpha: 1),
            UIColor(red: 0.12, green: 0.70, blue: 0.16, alpha: 1), .red, .red,
        ]
        let names = (0..<colors.count).map { "view-\($0).png" }
        for (name, color) in zip(names, colors) { try writeSolidImage(color: color, name: name, root: root) }
        let frames = names.map { SplatSeedFrame(filePath: $0, transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20) }
        let result = try XCTUnwrap(SplatSeedColorizer.colorize(points: [SIMD3<Float>(0, 0, -1)], frames: frames, projectURL: root).first)
        XCTAssertLessThan(result.red, 50)
        XCTAssertGreaterThan(result.green, 150)
        XCTAssertLessThan(result.blue, 60)
    }

    func testProjectionPreparationInvertsEachUsableFrameOncePerColorizationPass() {
        let frames = (0..<100).map { index in
            SplatSeedFrame(filePath: "\(index).png", transformMatrix: identityRows, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        }
        let prepared = SplatSeedColorizer.prepareProjections(frames: frames)
        XCTAssertEqual(prepared.count, 100)
        XCTAssertEqual(Set(prepared.map(\.frameIndex)), Set(0..<100))
    }

    func testProjectionPreparationRejectsSingularTransformBeforePointLoop() {
        var singular = identityRows
        singular[2] = [0, 0, 0, 0]
        let frame = SplatSeedFrame(filePath: "bad.png", transformMatrix: singular, flX: 10, flY: 10, cx: 10, cy: 10, w: 20, h: 20)
        XCTAssertTrue(SplatSeedColorizer.prepareProjections(frames: [frame]).isEmpty)
        XCTAssertNil(SplatSeedColorizer.project(point: SIMD3<Float>(0, 0, -1), frame: frame))
    }

    func testSeedCacheRejectsTruncatedPLY() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-truncated")
        defer { try? FileManager.default.removeItem(at: root) }
        let ply = root.appendingPathComponent("points3D.ply")
        var text = "ply\nformat ascii 1.0\nelement vertex 64\n"
        text += "property float x\nproperty float y\nproperty float z\n"
        text += "property uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
        for index in 0..<63 { text += "\(index) 0 0 255 255 255\n" }
        try text.write(to: ply, atomically: true, encoding: .utf8)
        XCTAssertFalse(SplatDepthSeedBuilder.cachedPLYIsComplete(at: ply, expectedPointCount: 64))
    }

    func testAppendedCaptureInputForcesFreshSeedAndTrainer() throws {
        let root = try makeProjectDirectory(prefix: "splat-seed-fingerprint")
        defer { try? FileManager.default.removeItem(at: root) }
        let points = (0..<64).map { SIMD3<Float>(Float($0), Float($0 % 7), Float($0 % 11)) }
        _ = try SplatDepthSeedBuilder.preparePointCloudPLY(projectURL: root, depthFrames: [], fallbackPoints: points, colorFrames: [])
        let unchanged = try SplatDepthSeedBuilder.preparePointCloudPLY(projectURL: root, depthFrames: [], fallbackPoints: Array(points.reversed()), colorFrames: [])
        XCTAssertFalse(unchanged.requiresFreshTrainer)
        let appended = SplatDepthSeedFrame(depthFilePath: nil, depthWidth: nil, depthHeight: nil, depthBytesPerRow: nil, transformMatrix: identityRows, flX: 500, flY: 500, cx: 320, cy: 240, w: 640, h: 480)
        let changed = try SplatDepthSeedBuilder.preparePointCloudPLY(projectURL: root, depthFrames: [appended], fallbackPoints: points, colorFrames: [])
        XCTAssertTrue(changed.requiresFreshTrainer)
    }

    private func writeSolidImage(color: UIColor, name: String, root: URL) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        try XCTUnwrap(image.pngData()).write(to: root.appendingPathComponent(name))
    }

    private func writeHeaderOnlyPNG(name: String, root: URL) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            UIColor.magenta.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let fullData = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(fullData.count, 33)
        let truncated = Data(fullData.prefix(33))
        let url = root.appendingPathComponent(name)
        try truncated.write(to: url)

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, options))
        XCTAssertGreaterThan(CGImageSourceGetCount(source), 0)
        XCTAssertNotNil(CGImageSourceCopyPropertiesAtIndex(source, 0, nil))
        XCTAssertNil(CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: false,
                kCGImageSourceThumbnailMaxPixelSize: SplatSeedColorizer.maximumRasterDimension,
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary
        ))
    }

    private func makeProjectDirectory(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private var identityRows: [[Float]] {
        [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    }
}
