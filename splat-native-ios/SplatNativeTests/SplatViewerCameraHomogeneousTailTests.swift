import Foundation
import XCTest

extension SplatViewerCameraDatasetLoaderTests {
    func testInvalidHomogeneousTailDoesNotAffectFollowingValidCamera() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplatViewerCameraHomogeneousTailTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let json = #"{"frames":[{"transform_matrix":[[1,0,0,1000],[0,1,0,1000],[0,0,1,1000],[1,0,0,1]]},{"transform_matrix":[[1,0,0,4],[0,1,0,5],[0,0,1,6],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 4, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 5, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 6, accuracy: 0.0001)
    }

    func testHomogeneousTailAllowsSmallSerializationNoise() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplatViewerCameraHomogeneousTailNoiseTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let json = #"{"frames":[{"transform_matrix":[[1,0,0,7],[0,1,0,8],[0,0,1,9],[0.00001,-0.00001,0.00001,0.99999]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 7, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 8, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 9, accuracy: 0.0001)
    }
}
