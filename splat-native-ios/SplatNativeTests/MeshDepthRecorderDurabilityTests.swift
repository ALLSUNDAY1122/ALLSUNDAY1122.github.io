import Foundation
import XCTest

@MainActor
final class MeshDepthRecorderDurabilityTests: XCTestCase {
    func testValidateCaptureDirectoryAcceptsExactPayloadAndMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-validate-good-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeCapture(at: root, payloadBytes: 16, file: "depth_00000.f32")

        XCTAssertNoThrow(try MeshDepthRecorder.validateCaptureDirectory(root))
    }

    func testValidateCaptureDirectoryRejectsTruncatedDepthPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-validate-truncated-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeCapture(at: root, payloadBytes: 12, file: "depth_00000.f32")

        XCTAssertThrowsError(try MeshDepthRecorder.validateCaptureDirectory(root))
    }

    func testValidateCaptureDirectoryRejectsPathTraversal() throws {
        let token = UUID().uuidString
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-validate-path-\(token)", isDirectory: true)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-outside-\(token).f32")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 16).write(to: outside, options: .atomic)
        try writeIndex(at: root, file: "../\(outside.lastPathComponent)")

        XCTAssertThrowsError(try MeshDepthRecorder.validateCaptureDirectory(root))
    }

    func testInstallCaptureDirectoryReplacesGenerationWithoutLeavingBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-install-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("new.depthcapture", isDirectory: true)
        let destination = root.appendingPathComponent("lidar-depth", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let previous = Data("previous-generation".utf8)
        let replacement = Data("replacement-generation".utf8)
        try previous.write(to: destination.appendingPathComponent("old.bin"), options: .atomic)
        try replacement.write(to: source.appendingPathComponent("new.bin"), options: .atomic)

        try MeshDepthRecorder.installCaptureDirectory(source, at: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("old.bin").path))
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("new.bin")), replacement)
        try assertNoBackup(in: root)
    }

    func testInstallCaptureDirectoryMovesFirstGenerationDirectly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-first-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("first.depthcapture", isDirectory: true)
        let destination = root.appendingPathComponent("lidar-depth", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bytes = Data("first-generation".utf8)
        try bytes.write(to: source.appendingPathComponent("depth.bin"), options: .atomic)

        try MeshDepthRecorder.installCaptureDirectory(source, at: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("depth.bin")), bytes)
    }

    func testInstallCaptureDirectoryRestoresPriorGenerationWhenReplacementMoveFails() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-depth-rollback-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("new.depthcapture", isDirectory: true)
        let destination = root.appendingPathComponent("lidar-depth", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let previous = Data("known-good-generation".utf8)
        let replacement = Data("new-generation".utf8)
        try previous.write(to: destination.appendingPathComponent("old.bin"), options: .atomic)
        try replacement.write(to: source.appendingPathComponent("new.bin"), options: .atomic)

        let fileManager = FailSecondMoveFileManager()
        XCTAssertThrowsError(
            try MeshDepthRecorder.installCaptureDirectory(source, at: destination, fileManager: fileManager)
        )

        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("old.bin")), previous)
        XCTAssertEqual(try Data(contentsOf: source.appendingPathComponent("new.bin")), replacement)
        try assertNoBackup(in: root)
    }

    private func makeCapture(at root: URL, payloadBytes: Int, file: String) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 0, count: payloadBytes).write(
            to: root.appendingPathComponent(file),
            options: .atomic
        )
        try writeIndex(at: root, file: file)
    }

    private func writeIndex(at root: URL, file: String) throws {
        let json = """
        {
          "schemaVersion": 2,
          "format": "test",
          "createdAt": "2026-09-11T00:00:00Z",
          "samples": [
            {
              "file": "\(file)",
              "timestamp": 1.0,
              "width": 2,
              "height": 2,
              "cameraWidth": 1920,
              "cameraHeight": 1440,
              "transform": [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]],
              "intrinsics": [[1,0,0],[0,1,0],[0,0,1]]
            }
          ]
        }
        """
        try Data(json.utf8).write(
            to: root.appendingPathComponent("depth-index.json"),
            options: .atomic
        )
    }

    private func assertNoBackup(in root: URL) throws {
        let siblings = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertFalse(siblings.contains { $0.lastPathComponent.contains("lidar-depth.previous-") })
    }
}

private final class FailSecondMoveFileManager: FileManager {
    private var moveCount = 0

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveCount += 1
        if moveCount == 2 {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
