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

    func testRemoveRefusesUnrelatedDirectory() throws {
        let fileManager = FileManager.default
        let unrelated = fileManager.temporaryDirectory
            .appendingPathComponent("scan-project-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: unrelated, withIntermediateDirectories: true)
        let sentinel = unrelated.appendingPathComponent("result.splat")
        try Data(repeating: 0x42, count: 64).write(to: sentinel)
        defer { try? fileManager.removeItem(at: unrelated) }

        SplatTransientExportWorkspace.remove(unrelated, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: unrelated.path))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }

    func testRemoveRefusesUnownedPrefixedDirectory() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-unowned-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinel = directory.appendingPathComponent("result.splat")
        try Data(repeating: 0x52, count: 64).write(to: sentinel)
        defer { try? fileManager.removeItem(at: directory) }

        SplatTransientExportWorkspace.remove(directory, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: directory.path))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }

    func testRemoveRefusesNamespacedRegularFile() throws {
        let fileManager = FileManager.default
        let file = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-sentinel-\(UUID().uuidString).dat")
        try Data(repeating: 0x24, count: 64).write(to: file)
        defer { try? fileManager.removeItem(at: file) }

        SplatTransientExportWorkspace.remove(file, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: file.path))
    }

    func testRemoveRefusesSymlinkedWorkspaceEvenWithMarkerAtDestination() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-alias-root-\(UUID().uuidString)", isDirectory: true)
        let external = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-alias-target-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: external, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: external)
        }
        try Data().write(to: external.appendingPathComponent(".scanlab-transient-export"))
        let sentinel = external.appendingPathComponent("keep.dat")
        try Data([0x7A]).write(to: sentinel)

        let alias = root.appendingPathComponent("scanlab-export-aliased", isDirectory: true)
        try fileManager.createSymbolicLink(at: alias, withDestinationURL: external)
        SplatTransientExportWorkspace.remove(alias, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: alias.path))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }

    func testRemoveRefusesSymlinkedOwnershipMarker() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-marker-alias-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let externalMarker = fileManager.temporaryDirectory
            .appendingPathComponent("marker-\(UUID().uuidString)")
        try Data().write(to: externalMarker)
        defer { try? fileManager.removeItem(at: externalMarker) }
        try fileManager.createSymbolicLink(
            at: directory.appendingPathComponent(".scanlab-transient-export"),
            withDestinationURL: externalMarker
        )

        SplatTransientExportWorkspace.remove(directory, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: directory.path))
    }

    func testCleanupRemovesOnlyStaleOwnedExportDirectories() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("scanlab-export-cleanup-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let stale = try SplatTransientExportWorkspace.create(rootDirectory: root, fileManager: fileManager)
        let recent = try SplatTransientExportWorkspace.create(rootDirectory: root, fileManager: fileManager)
        let unrelated = root.appendingPathComponent("other-export-stale", isDirectory: true)
        let unownedPrefixed = root.appendingPathComponent("scanlab-export-unowned", isDirectory: true)
        try fileManager.createDirectory(at: unrelated, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unownedPrefixed, withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 2_000_000)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: stale.path)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-2 * 60 * 60)], ofItemAtPath: recent.path)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: unrelated.path)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: unownedPrefixed.path)

        SplatTransientExportWorkspace.cleanupStaleExports(
            in: root,
            olderThan: 24 * 60 * 60,
            now: now,
            fileManager: fileManager
        )

        XCTAssertFalse(fileManager.fileExists(atPath: stale.path))
        XCTAssertTrue(fileManager.fileExists(atPath: recent.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelated.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unownedPrefixed.path))
    }

    func testCreatePrunesStaleOwnedWorkspaceAndCreatesFreshDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("scanlab-export-create-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let stale = try SplatTransientExportWorkspace.create(rootDirectory: root, fileManager: fileManager)
        try fileManager.setAttributes([.modificationDate: Date().addingTimeInterval(-48 * 60 * 60)], ofItemAtPath: stale.path)

        let created = try SplatTransientExportWorkspace.create(rootDirectory: root, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: stale.path))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: created.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(created.lastPathComponent.hasPrefix("scanlab-export-"))
        XCTAssertTrue(fileManager.fileExists(atPath: created.appendingPathComponent(".scanlab-transient-export").path))
    }
}
