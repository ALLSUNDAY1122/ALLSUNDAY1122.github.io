import Foundation
import XCTest

@MainActor
final class MeshDepthRecorderDurabilityTests: XCTestCase {
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