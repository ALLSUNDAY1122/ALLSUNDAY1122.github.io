import XCTest

final class SplatTransientExportWorkspaceTests: XCTestCase {
    func testWorkspaceCanBeRemovedWithAllSharedArtifacts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-export-workspace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workspace = try SplatTransientExportWorkspace.create(rootDirectory: root)
        let exportedFile = workspace.appendingPathComponent("result.ply")
        try Data(repeating: 0x31, count: 1_024).write(to: exportedFile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedFile.path))

        SplatTransientExportWorkspace.remove(workspace)

        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportedFile.path))
    }

    func testRemovingMissingWorkspaceIsIdempotent() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-missing-workspace-\(UUID().uuidString)", isDirectory: true)
        SplatTransientExportWorkspace.remove(missing)
        SplatTransientExportWorkspace.remove(missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testCleanupRemovesOnlyStaleScanLabExportDirectories() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("scanlab-export-cleanup-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let stale = root.appendingPathComponent("scanlab-export-stale", isDirectory: true)
        let recent = root.appendingPathComponent("scanlab-export-recent", isDirectory: true)
        let unrelated = root.appendingPathComponent("other-export-stale", isDirectory: true)
        for directory in [stale, recent, unrelated] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let now = Date(timeIntervalSince1970: 2_000_000)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: stale.path)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-2 * 60 * 60)], ofItemAtPath: recent.path)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: unrelated.path)

        SplatTransientExportWorkspace.cleanupStaleExports(
            in: root,
            olderThan: 24 * 60 * 60,
            now: now,
            fileManager: fileManager
        )

        XCTAssertFalse(fileManager.fileExists(atPath: stale.path))
        XCTAssertTrue(fileManager.fileExists(atPath: recent.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelated.path))
    }

    func testCreatePrunesStaleWorkspaceAndCreatesFreshDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("scanlab-export-create-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let stale = root.appendingPathComponent("scanlab-export-abandoned", isDirectory: true)
        try fileManager.createDirectory(at: stale, withIntermediateDirectories: true)
        try fileManager.setAttributes([.modificationDate: Date().addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: stale.path)

        let created = try SplatTransientExportWorkspace.create(rootDirectory: root, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: stale.path))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: created.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(created.lastPathComponent.hasPrefix("scanlab-export-"))
    }
}
