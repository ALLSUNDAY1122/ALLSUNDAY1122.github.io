import Foundation
import XCTest
import simd

final class SplatDepthSeedCacheIntegrityTests: XCTestCase {
    func testCompletePLYIsAccepted() throws {
        let url = try makePLY(declared: 64, actual: 64)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertTrue(SplatDepthSeedBuilder.cachedPLYIsComplete(at: url, expectedPointCount: 64))
    }

    func testTruncatedPLYIsRejected() throws {
        let url = try makePLY(declared: 64, actual: 63)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertFalse(SplatDepthSeedBuilder.cachedPLYIsComplete(at: url, expectedPointCount: 64))
    }

    func testMetadataCountMismatchIsRejected() throws {
        let url = try makePLY(declared: 64, actual: 64)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertFalse(SplatDepthSeedBuilder.cachedPLYIsComplete(at: url, expectedPointCount: 65))
    }

    func testAppendedVertexIsRejected() throws {
        let url = try makePLY(declared: 64, actual: 65)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertFalse(SplatDepthSeedBuilder.cachedPLYIsComplete(at: url, expectedPointCount: 64))
    }

    func testChangedReconstructionInputsForceFreshSeedAndTrainer() throws {
        let projectURL = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: projectURL) }
        let points = fallbackPoints()

        let first = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: projectURL,
            depthFrames: [],
            fallbackPoints: points,
            colorFrames: []
        )
        XCTAssertTrue(first.requiresFreshTrainer)

        let unchanged = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: projectURL,
            depthFrames: [],
            fallbackPoints: points,
            colorFrames: []
        )
        XCTAssertFalse(unchanged.requiresFreshTrainer)

        var changedPoints = points
        changedPoints[0] = SIMD3<Float>(999, 1, 1)
        let changed = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: projectURL,
            depthFrames: [],
            fallbackPoints: changedPoints,
            colorFrames: []
        )
        XCTAssertTrue(changed.requiresFreshTrainer)
    }

    func testFallbackPointOrderingDoesNotInvalidateSameCaptureCache() throws {
        let projectURL = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: projectURL) }
        let points = fallbackPoints()

        _ = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: projectURL,
            depthFrames: [],
            fallbackPoints: points,
            colorFrames: []
        )
        let reordered = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: projectURL,
            depthFrames: [],
            fallbackPoints: points.reversed(),
            colorFrames: []
        )
        XCTAssertFalse(reordered.requiresFreshTrainer)
    }

    private func makePLY(declared: Int, actual: Int) throws -> URL {
        let directory = try makeProjectDirectory()
        let url = directory.appendingPathComponent("points3D.ply")
        var text = "ply\nformat ascii 1.0\nelement vertex \(declared)\n"
        text += "property float x\nproperty float y\nproperty float z\n"
        text += "property uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
        for index in 0..<actual {
            text += "\(index) 0 0 255 255 255\n"
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeProjectDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fallbackPoints() -> [SIMD3<Float>] {
        (0..<64).map { index in
            SIMD3<Float>(Float(index), Float(index % 7), Float(index % 11))
        }
    }
}
