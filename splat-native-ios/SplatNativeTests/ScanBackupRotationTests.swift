import Foundation
import XCTest

final class ScanBackupRotationTests: XCTestCase {
    private var rootURL: URL!
    private var store: ScanProjectStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanBackupRotationTests-\(UUID().uuidString)", isDirectory: true)
        store = ScanProjectStore(rootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        store = nil
        rootURL = nil
    }

    func testManifestSaveDoesNotRotateCorruptPrimaryOverKnownGoodBackup() throws {
        let created = try store.createProject(title: "manifest backup")
        let projectURL = created.0
        let primary = projectURL.appendingPathComponent(ScanProjectStore.manifestFileName)
        let backup = projectURL.appendingPathComponent(ScanProjectStore.manifestBackupFileName)
        let knownGood = try Data(contentsOf: primary)
        try knownGood.write(to: backup, options: .atomic)
        try Data("not-json".utf8).write(to: primary, options: .atomic)

        var replacement = created.1
        replacement.title = "replacement"
        try store.writeManifest(replacement, to: projectURL)

        XCTAssertEqual(try Data(contentsOf: backup), knownGood)
        XCTAssertEqual(try store.loadManifest(projectURL: projectURL).title, "replacement")
    }

    func testCheckpointSaveDoesNotRotateCorruptPrimaryOverKnownGoodBackup() throws {
        let created = try store.createProject(title: "checkpoint backup")
        let projectURL = created.0
        let original = ScanCaptureCheckpoint(
            frames: [],
            featurePoints: [],
            coverageSectors: [1, 2],
            estimatedTargetCenter: nil,
            lastAcceptedTransform: nil,
            lastAcceptedTimestamp: 1
        )
        try store.saveCheckpoint(original, projectURL: projectURL)

        let primary = projectURL.appendingPathComponent(ScanProjectStore.checkpointFileName)
        let backup = projectURL.appendingPathComponent(ScanProjectStore.checkpointBackupFileName)
        let knownGood = try Data(contentsOf: primary)
        try knownGood.write(to: backup, options: .atomic)
        try Data("broken-plist".utf8).write(to: primary, options: .atomic)

        let replacement = ScanCaptureCheckpoint(
            frames: [],
            featurePoints: [],
            coverageSectors: [3, 4, 5],
            estimatedTargetCenter: nil,
            lastAcceptedTransform: nil,
            lastAcceptedTimestamp: 2
        )
        try store.saveCheckpoint(replacement, projectURL: projectURL)

        XCTAssertEqual(try Data(contentsOf: backup), knownGood)
        XCTAssertEqual(try store.loadCheckpoint(projectURL: projectURL), replacement)
    }
}
