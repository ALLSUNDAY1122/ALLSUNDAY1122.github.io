import Foundation
import XCTest

final class SplatViewerCameraStreamingDecodeTests: XCTestCase {
    func testIgnoresUnusedWideMatrixColumnsWithoutMaterializingWholeRows() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)

        let extra = Array(repeating: "0", count: 2_000).joined(separator: ",")
        let json = "{\"frames\":[{\"transform_matrix\":[[1,0,0,1.25,\(extra)],[0,1,0,-2.5,\(extra)],[0,0,1,3.75,\(extra)],[0,0,0,1]]}]}"
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 1.25, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, -2.5, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 3.75, accuracy: 0.0001)
    }

    func testMalformedUnusedTrailingMatrixValueDoesNotDiscardValidTranslation() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)

        let json = #"{"frames":[{"transform_matrix":[[1,0,0,4,"unused"],[0,1,0,5,"unused"],[0,0,1,6,"unused"],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 4, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 5, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 6, accuracy: 0.0001)
    }

    func testRejectsTransformsWhenSceneRootIsSymlinked() throws {
        let targetRoot = try makeRoot()
        let aliasParent = try makeRoot()
        defer {
            try? FileManager.default.removeItem(at: aliasParent)
            try? FileManager.default.removeItem(at: targetRoot)
        }

        try Data([0x50]).write(to: targetRoot.appendingPathComponent("result.ply"))
        let json = #"{"frames":[{"transform_matrix":[[1,0,0,7],[0,1,0,8],[0,0,1,9],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: targetRoot.appendingPathComponent("transforms.json"))

        let aliasRoot = aliasParent.appendingPathComponent("aliased-scene", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: aliasRoot, withDestinationURL: targetRoot)
        let renderViaAlias = aliasRoot.appendingPathComponent("result.ply")

        XCTAssertTrue(SplatViewerCameraDatasetLoader.cameraPositions(for: renderViaAlias).isEmpty)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplatViewerCameraStreamingDecodeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
