import Foundation
import XCTest

final class MeshRawProjectBridgeArchiveTests: XCTestCase {
    func testArchivedMeshRawRemainsDiscoverableAfterWorkingProjectIsRemoved() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MeshRawArchive-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let working = root.appendingPathComponent("scan-archive").appendingPathExtension("meshproject")
        let images = working.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: images.appendingPathComponent("mesh_00000.jpg"))
        let result = working.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: result)

        let store = MeshProjectStore(appRootURL: root, fileManager: fileManager)
        let archived = try store.archiveFinishedProject(resultURL: result)
        try fileManager.removeItem(at: working)

        let discovered = MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager)
        let raw = try XCTUnwrap(discovered.first { $0.id == "mesh:scan-archive" })
        XCTAssertEqual(raw.sourceKind, .meshProject)
        XCTAssertEqual(raw.sourceProjectURL.standardizedFileURL, archived.projectURL.standardizedFileURL)
        XCTAssertEqual(raw.imageCount, 1)
        XCTAssertTrue(fileManager.fileExists(atPath: raw.imagesURL.appendingPathComponent("mesh_00000.jpg").path))
    }

    func testWorkingMeshTakesPrecedenceOverArchivedDuplicate() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MeshRawWorking-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let working = root.appendingPathComponent("scan-duplicate").appendingPathExtension("meshproject")
        let images = working.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: images.appendingPathComponent("mesh_00000.jpg"))
        let result = working.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: result)

        let store = MeshProjectStore(appRootURL: root, fileManager: fileManager)
        _ = try store.archiveFinishedProject(resultURL: result)

        let discovered = MeshRawProjectBridge.discover(appRootURL: root, fileManager: fileManager)
            .filter { $0.id == "mesh:scan-duplicate" }
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered.first?.sourceProjectURL.standardizedFileURL, working.standardizedFileURL)
    }
}
