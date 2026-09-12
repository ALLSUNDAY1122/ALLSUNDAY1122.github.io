import XCTest
import UIKit
import simd

final class SplatSkySeederDedupTests: XCTestCase {
    func testRepeatedIdenticalViewDoesNotMultiplySkySeeds() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-sky-dedup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidSkyImage(name: "sky.png", root: root)
        let frame = makeFrame(filePath: "sky.png", rows: identityRows)

        let single = SplatSkySeeder.makeSeeds(
            frames: [frame],
            geometryPoints: [],
            projectURL: root
        )
        let repeated = SplatSkySeeder.makeSeeds(
            frames: Array(repeating: frame, count: 20),
            geometryPoints: [],
            projectURL: root
        )

        XCTAssertFalse(single.isEmpty)
        XCTAssertEqual(repeated.count, single.count)
        XCTAssertLessThanOrEqual(repeated.count, SplatSkySeeder.maxSeedsPerFrame)
        XCTAssertLessThanOrEqual(repeated.count, SplatSkySeeder.maxTotalSeeds)
    }

    func testDirectionBinsIgnoreDistanceAlongSameRay() throws {
        let near = try XCTUnwrap(SplatSkySeeder.directionKey(
            worldDirection: SIMD3<Float>(0.25, 0.35, -1.0)
        ))
        let far = try XCTUnwrap(SplatSkySeeder.directionKey(
            worldDirection: SIMD3<Float>(2.5, 3.5, -10.0)
        ))
        XCTAssertEqual(near, far)
    }

    func testDirectionBinsSeparateDistinctSkyDirections() throws {
        let left = try XCTUnwrap(SplatSkySeeder.directionKey(
            worldDirection: SIMD3<Float>(-0.8, 0.4, -1.0)
        ))
        let right = try XCTUnwrap(SplatSkySeeder.directionKey(
            worldDirection: SIMD3<Float>(0.8, 0.4, -1.0)
        ))
        XCTAssertNotEqual(left, right)
    }

    func testSkyColorConsensusRejectsSingleExposureOutlier() {
        let color = SplatSkySeeder.robustColor([
            SplatSeedSample(red: 70, green: 145, blue: 235),
            SplatSeedSample(red: 72, green: 148, blue: 238),
            SplatSeedSample(red: 180, green: 220, blue: 255),
        ])
        XCTAssertEqual(color.red, 72)
        XCTAssertEqual(color.green, 148)
        XCTAssertEqual(color.blue, 238)
    }

    private func makeFrame(filePath: String, rows: [[Float]]) -> SplatSeedFrame {
        SplatSeedFrame(
            filePath: filePath,
            transformMatrix: rows,
            flX: 50,
            flY: 50,
            cx: 32,
            cy: 32,
            w: 64,
            h: 64
        )
    }

    private func writeSolidSkyImage(name: String, root: URL) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor(red: 0.20, green: 0.58, blue: 0.95, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        try XCTUnwrap(image.pngData()).write(to: root.appendingPathComponent(name))
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
