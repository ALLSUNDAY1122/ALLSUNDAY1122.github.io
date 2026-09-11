import Foundation
import XCTest
@testable import SplatNative

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

    private func makePLY(declared: Int, actual: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
}
