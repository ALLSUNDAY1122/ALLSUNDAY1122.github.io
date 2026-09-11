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

        let siblings = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertFalse(siblings.contains { $0.lastPathComponent.contains("lidar-depth.previous-") })
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
}