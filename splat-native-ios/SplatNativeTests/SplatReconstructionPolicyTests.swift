import XCTest
import Msplat
import UIKit
import simd

final class SplatReconstructionPolicyTests: XCTestCase {
    func testStandardProfileKeepsFullSHAndProgressiveRefinement() {
        let config = SplatReconstructionPolicy.makeConfig(
            iterations: SplatReconstructionPolicy.standardIterations
        )
        XCTAssertEqual(config.iterations, 7_000)
        XCTAssertEqual(config.shDegree, 3)
        XCTAssertEqual(config.shDegreeInterval, 1_000)
        XCTAssertEqual(config.numDownscales, 1)
        XCTAssertEqual(config.resolutionSchedule, 2_000)
        XCTAssertEqual(config.warmupLength, 500)
        XCTAssertEqual(config.resetAlphaEvery, 30)
        XCTAssertEqual(config.stopScreenSizeAt, 4_000)
        XCTAssertEqual(config.ssimWeight, 0.2, accuracy: 0.0001)
    }

    func testSeedProjectionUsesARKitMinusZForwardAndImageTopLeftCoordinates() {
        let frame = SplatSeedFrame(
            filePath: "unused.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )

        let center = SplatSeedColorizer.project(point: SIMD3<Float>(0, 0, -1), frame: frame)
        XCTAssertEqual(center?.x ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(center?.y ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(center?.z ?? -1, 1, accuracy: 0.001)

        let upper = SplatSeedColorizer.project(point: SIMD3<Float>(0, 0.5, -1), frame: frame)
        XCTAssertEqual(upper?.y ?? -1, 5, accuracy: 0.001)
    }

    func testSeedColorizerSamplesProjectedPixelsFromCapturedFrame() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-color-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 10, width: 20, height: 10))
        }
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: root.appendingPathComponent("frame.png"))

        let frame = SplatSeedFrame(
            filePath: "frame.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )
        let colors = SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0.5, -1), SIMD3<Float>(0, -0.5, -1)],
            frames: [frame],
            projectURL: root
        )

        XCTAssertEqual(colors.count, 2)
        XCTAssertGreaterThan(colors[0].red, 220)
        XCTAssertLessThan(colors[0].blue, 40)
        XCTAssertGreaterThan(colors[1].blue, 220)
        XCTAssertLessThan(colors[1].red, 40)
    }

    private var identityRows: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]
    }
}
