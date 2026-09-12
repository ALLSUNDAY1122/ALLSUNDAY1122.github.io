import Foundation
import XCTest

final class SplatViewerCameraDatasetLoaderTests: XCTestCase {
    func testLoadsFiniteContainedCameraPositions() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let json = #"{"frames":[{"transform_matrix":[[1,0,0,1.25],[0,1,0,-2.5],[0,0,1,3.75],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 1.25, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, -2.5, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 3.75, accuracy: 0.0001)
    }

    func testMalformedFrameDoesNotDiscardFollowingValidCamera() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let json = #"{"frames":[{"transform_matrix":[[1,0],[0,1]]},{"transform_matrix":[[1,0,0,4],[0,1,0,5],[0,0,1,6],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 4, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 5, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 6, accuracy: 0.0001)
    }

    func testWrongTransformTypeDoesNotDiscardFollowingValidCamera() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let json = #"{"frames":[{"transform_matrix":"corrupt"},{"transform_matrix":[[1,0,0,7],[0,1,0,8],[0,0,1,9],[0,0,0,1]]}]}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].x, 7, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 8, accuracy: 0.0001)
        XCTAssertEqual(positions[0].z, 9, accuracy: 0.0001)
    }

    func testRejectsSymlinkedTransformsMetadata() throws {
        let root = try makeRoot()
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        try Data(#"{"frames":[]}"#.utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("transforms.json"),
            withDestinationURL: outside
        )

        XCTAssertTrue(SplatViewerCameraDatasetLoader.cameraPositions(for: render).isEmpty)
    }

    func testRejectsOversizedTransformsBeforeReadingPayload() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)
        let transforms = root.appendingPathComponent("transforms.json")
        FileManager.default.createFile(atPath: transforms.path, contents: Data("{}".utf8))
        let handle = try FileHandle(forWritingTo: transforms)
        try handle.truncate(atOffset: UInt64(SplatViewerCameraDatasetLoader.maximumTransformsBytes + 1))
        try handle.close()

        XCTAssertTrue(SplatViewerCameraDatasetLoader.cameraPositions(for: render).isEmpty)
    }

    func testLongTrajectoryIsEvenlySampledAndKeepsEndpoints() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)

        let frameCount = SplatViewerCameraDatasetLoader.maximumReturnedPositions + 904
        var frames: [String] = []
        frames.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            frames.append(validFrame(x: index))
        }
        let json = "{\"frames\":[" + frames.joined(separator: ",") + "]}"
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, SplatViewerCameraDatasetLoader.maximumReturnedPositions)
        XCTAssertEqual(positions.first?.x, 0)
        XCTAssertEqual(positions.last?.x, Float(frameCount - 1))
        XCTAssertTrue(zip(positions, positions.dropFirst()).allSatisfy { pair in
            pair.0.x <= pair.1.x
        })
    }

    func testLongTrajectorySamplesValidFramesDespiteMalformedInterleaving() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let render = root.appendingPathComponent("result.ply")
        try Data([0x50]).write(to: render)

        let validFrameCount = SplatViewerCameraDatasetLoader.maximumReturnedPositions + 904
        var frames: [String] = []
        frames.reserveCapacity(validFrameCount + 500)
        for index in 0..<validFrameCount {
            if index % 10 == 5 {
                frames.append(#"{"transform_matrix":[[1,0],[0,1]]}"#)
            }
            frames.append(validFrame(x: index))
        }
        let json = "{\"frames\":[" + frames.joined(separator: ",") + "]}"
        try Data(json.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: render)
        XCTAssertEqual(positions.count, SplatViewerCameraDatasetLoader.maximumReturnedPositions)
        XCTAssertEqual(positions.first?.x, 0)
        XCTAssertEqual(positions.last?.x, Float(validFrameCount - 1))
        XCTAssertTrue(zip(positions, positions.dropFirst()).allSatisfy { pair in
            pair.0.x <= pair.1.x
        })
    }

    private func validFrame(x: Int) -> String {
        "{\"transform_matrix\":[[1,0,0,\(x)],[0,1,0,0],[0,0,1,0],[0,0,0,1]]}"
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplatViewerCameraDatasetLoaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
