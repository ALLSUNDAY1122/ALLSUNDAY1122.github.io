import XCTest

final class SplatTransientExportWorkspaceOwnershipTests: XCTestCase {
    func testCopiedOwnershipMarkerDoesNotAuthorizeAnotherDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-ownership-root-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let owned = try SplatTransientExportWorkspace.create(
            rootDirectory: root,
            fileManager: fileManager
        )
        let copied = root.appendingPathComponent(
            "scanlab-export-copied-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: copied, withIntermediateDirectories: true)
        try fileManager.copyItem(
            at: owned.appendingPathComponent(".scanlab-transient-export"),
            to: copied.appendingPathComponent(".scanlab-transient-export")
        )
        let sentinel = copied.appendingPathComponent("keep.dat")
        try Data([0x5A]).write(to: sentinel)

        SplatTransientExportWorkspace.remove(copied, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: copied.path))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }

    func testLegacyEmptyMarkerDirectTemporaryChildCanStillBeRemoved() throws {
        let fileManager = FileManager.default
        let legacy = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-legacy-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data().write(to: legacy.appendingPathComponent(".scanlab-transient-export"))
        defer { try? fileManager.removeItem(at: legacy) }

        SplatTransientExportWorkspace.remove(legacy, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: legacy.path))
    }

    func testLegacyEmptyMarkerOutsideDirectTemporaryRootIsRefused() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-export-legacy-root-\(UUID().uuidString)", isDirectory: true)
        let nested = root.appendingPathComponent(
            "scanlab-export-legacy-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent(".scanlab-transient-export"))
        let sentinel = nested.appendingPathComponent("keep.dat")
        try Data([0x33]).write(to: sentinel)
        defer { try? fileManager.removeItem(at: root) }

        SplatTransientExportWorkspace.remove(nested, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: nested.path))
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }
}
