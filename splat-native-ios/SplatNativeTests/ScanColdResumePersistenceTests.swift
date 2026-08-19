import Foundation
import XCTest

final class ScanColdResumePersistenceTests: XCTestCase {
    func testCheckpointV2RoundTripPreservesDepthAndCoverageState() throws {
        let frame = StoredCapturedFrame(
            id: 3,
            filePath: "images/frame_00003.jpg",
            transformMatrix: [
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0.2, 0.1, -0.4, 1]
            ],
            flX: 900,
            flY: 901,
            cx: 640,
            cy: 360,
            w: 1280,
            h: 720,
            depthFilePath: "depth/depth_00003.f32",
            depthWidth: 256,
            depthHeight: 192,
            depthBytesPerRow: 1024
        )
        let checkpoint = ScanCaptureCheckpoint(
            frames: [frame],
            featurePoints: [StoredFeaturePoint(id: 7, x: 0.1, y: 0.2, z: -0.7)],
            coverageSectors: [1, 4, 7],
            estimatedTargetCenter: StoredVector3(x: 0, y: 0.1, z: -0.8),
            lastAcceptedTransform: frame.transformMatrix,
            lastAcceptedTimestamp: 42.5,
            elevationBands: [0, 1],
            viewDirectionSectors: [2, 5],
            spatialCells: [StoredGridCell(x: 1, z: -2), StoredGridCell(x: 2, z: -2)],
            estimatedSubjectDistance: 0.9,
            previousCoveragePosition: StoredVector3(x: 0.2, y: 0.1, z: -0.4),
            pathLengthMeters: 1.25,
            accumulatedCaptureSeconds: 63.0,
            ignoreLiDAR: false
        )

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(checkpoint)
        let decoded = try PropertyListDecoder().decode(ScanCaptureCheckpoint.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.frames.first?.depthFilePath, "depth/depth_00003.f32")
        XCTAssertEqual(decoded.frames.first?.depthBytesPerRow, 1024)
        XCTAssertEqual(decoded.elevationBands, [0, 1])
        XCTAssertEqual(decoded.viewDirectionSectors, [2, 5])
        XCTAssertEqual(decoded.spatialCells, [StoredGridCell(x: 1, z: -2), StoredGridCell(x: 2, z: -2)])
        XCTAssertEqual(decoded.pathLengthMeters, 1.25)
        XCTAssertEqual(decoded.accumulatedCaptureSeconds, 63.0)
        XCTAssertEqual(decoded.ignoreLiDAR, false)
    }

    func testCheckpointV2DefaultsRemainBackwardFriendly() {
        let checkpoint = ScanCaptureCheckpoint(
            frames: [],
            featurePoints: [],
            coverageSectors: [],
            estimatedTargetCenter: nil,
            lastAcceptedTransform: nil,
            lastAcceptedTimestamp: 0
        )

        XCTAssertEqual(checkpoint.schemaVersion, 2)
        XCTAssertNil(checkpoint.elevationBands)
        XCTAssertNil(checkpoint.viewDirectionSectors)
        XCTAssertNil(checkpoint.spatialCells)
        XCTAssertNil(checkpoint.accumulatedCaptureSeconds)
        XCTAssertNil(checkpoint.ignoreLiDAR)
    }

    func testLegacyCheckpointWithoutV2FieldsStillDecodes() throws {
        let legacy: [String: Any] = [
            "schemaVersion": 1,
            "savedAt": Date(timeIntervalSince1970: 1_700_000_000),
            "frames": [],
            "featurePoints": [],
            "coverageSectors": [1, 2],
            "lastAcceptedTimestamp": 12.0
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: legacy,
            format: .binary,
            options: 0
        )
        let decoded = try PropertyListDecoder().decode(ScanCaptureCheckpoint.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertNil(decoded.elevationBands)
        XCTAssertNil(decoded.spatialCells)
        XCTAssertNil(decoded.accumulatedCaptureSeconds)
        XCTAssertNil(decoded.ignoreLiDAR)
    }

    func testWorldMapPresenceUsesProjectScopedDurableFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Resume", targetFrames: 24)
        XCTAssertFalse(store.hasWorldMap(projectURL: projectURL))

        try Data([0x01, 0x02, 0x03]).write(
            to: store.worldMapURL(projectURL: projectURL),
            options: .atomic
        )
        XCTAssertTrue(store.hasWorldMap(projectURL: projectURL))
    }

    func testWorldMapArchiveStoreAtomicallyReplacesExistingArchive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("worldmap.arexperience")
        try Data([0x01]).write(to: target, options: .atomic)

        let replacement = Data([0x10, 0x20, 0x30, 0x40])
        try ScanWorldMapArchiveStore.write(replacement, to: target)

        XCTAssertEqual(try Data(contentsOf: target), replacement)
    }

    func testWorldMapArchiveStoreRejectsEmptyArchiveWithoutReplacingExistingData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("worldmap.arexperience")
        let existing = Data([0xAA, 0xBB])
        try existing.write(to: target, options: .atomic)

        XCTAssertThrowsError(try ScanWorldMapArchiveStore.write(Data(), to: target))
        XCTAssertEqual(try Data(contentsOf: target), existing)
    }

}
