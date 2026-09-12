import Foundation
import XCTest

final class SplatViewerSidecarWriteSafetyTests: XCTestCase {
    func testBackupRecoveryDoesNotWriteThroughUnsafePrimaryAlias() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("SplatViewerSidecarWriteSafetyTests-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SplatViewerSidecarWriteSafetyExternal-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let expected = SplatEditSettings(exposureEV: 0.65, contrast: 1.2).normalized()
        try JSONEncoder().encode(expected).write(
            to: SplatViewerEditStore.backupURL(for: source),
            options: .atomic
        )

        let externalPrimary = externalRoot.appendingPathComponent("external-viewer.json")
        let externalBytes = Data("do-not-touch".utf8)
        try externalBytes.write(to: externalPrimary, options: .atomic)
        let primary = SplatViewerEditStore.primaryURL(for: source)
        try fileManager.createSymbolicLink(at: primary, withDestinationURL: externalPrimary)

        let recovered = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(recovered.recoveredFromBackup)
        XCTAssertEqual(recovered.settings, expected)
        XCTAssertEqual(try Data(contentsOf: externalPrimary), externalBytes)
        XCTAssertEqual(
            try primary.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
            true
        )

        XCTAssertThrowsError(try SplatViewerEditStore.save(.default, sourceURL: source)) { error in
            XCTAssertEqual(error as? SplatViewerEditStoreError, .unsafeWriteTarget)
        }
        XCTAssertEqual(try Data(contentsOf: externalPrimary), externalBytes)
    }

    func testSaveRejectsUnsafeBackupAliasBeforePrimaryChanges() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("SplatViewerSidecarWriteSafetyTests-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SplatViewerSidecarWriteSafetyExternal-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let original = SplatEditSettings(exposureEV: 0.2, contrast: 1.1)
        try SplatViewerEditStore.save(original, sourceURL: source)
        let primary = SplatViewerEditStore.primaryURL(for: source)
        let primaryBefore = try Data(contentsOf: primary)

        let backup = SplatViewerEditStore.backupURL(for: source)
        try fileManager.removeItem(at: backup)
        let externalBackup = externalRoot.appendingPathComponent("external-backup.json")
        let externalBytes = Data("external-backup".utf8)
        try externalBytes.write(to: externalBackup, options: .atomic)
        try fileManager.createSymbolicLink(at: backup, withDestinationURL: externalBackup)

        XCTAssertThrowsError(
            try SplatViewerEditStore.save(
                SplatEditSettings(exposureEV: 1.0, contrast: 1.4),
                sourceURL: source
            )
        ) { error in
            XCTAssertEqual(error as? SplatViewerEditStoreError, .unsafeWriteTarget)
        }
        XCTAssertEqual(try Data(contentsOf: primary), primaryBefore)
        XCTAssertEqual(try Data(contentsOf: externalBackup), externalBytes)
    }
}
