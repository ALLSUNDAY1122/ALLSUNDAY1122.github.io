import Foundation
import XCTest

final class SplatViewerCameraDatasetLoaderMemoryTests: XCTestCase {
    func testLargeTrajectoryIsBoundedAndKeepsBothEndpoints() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewer-camera-large-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let finalIndex = 9_000
        var json = "{\"frames\":["
        for index in 0...finalIndex {
            if index > 0 { json += "," }
            json += "{\"transform_matrix\":[[1,0,0,\(index)],[0,1,0,0],[0,0,1,0],[0,0,0,1]]}"
        }
        json += "]}"
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(
            for: root.appendingPathComponent("result.splat")
        )

        XCTAssertEqual(positions.count, SplatViewerCameraDatasetLoader.maximumReturnedPositions)
        XCTAssertEqual(positions.first?.x, 0)
        XCTAssertEqual(positions.last?.x, Float(finalIndex))
        XCTAssertTrue(zip(positions, positions.dropFirst()).allSatisfy { $0.x <= $1.x })
    }

    func testSmallTrajectoryIsReturnedWithoutResampling() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewer-camera-small-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let json = "{\"frames\":[{\"transform_matrix\":[[1,0,0,1],[0,1,0,2],[0,0,1,3],[0,0,0,1]]},{\"transform_matrix\":[[1,0,0,4],[0,1,0,5],[0,0,1,6],[0,0,0,1]]}]}"
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(
            for: root.appendingPathComponent("result.splat")
        )

        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions[0], SIMD3<Float>(1, 2, 3))
        XCTAssertEqual(positions[1], SIMD3<Float>(4, 5, 6))
    }
}
