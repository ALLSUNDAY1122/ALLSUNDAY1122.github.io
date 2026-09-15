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
}
