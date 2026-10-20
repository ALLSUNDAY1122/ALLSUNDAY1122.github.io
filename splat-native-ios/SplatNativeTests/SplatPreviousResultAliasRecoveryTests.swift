import XCTest

final class SplatPreviousResultAliasRecoveryTests: XCTestCase {
    func testProjectRecoveryRefusesExternalProtectedBackupAliasAndPreservesCurrentBytes() throws {
        let fileManager = FileManager.default
        let root = try makeRoot("alias-recovery")
        let externalRoot = try makeRoot("alias-recovery-external")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Alias recovery safety")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x35, count: 64)
        let result = try commitResult(trustedBytes, in: projectURL, store: store)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        let protectedBackup = projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        let externalBackup = externalRoot.appendingPathComponent("external.splat")
        try trustedBytes.write(to: externalBackup, options: .atomic)
        try fileManager.removeItem(at: protectedBackup)
        try fileManager.createSymbolicLink(at: protectedBackup, withDestinationURL: externalBackup)

        let corruptedBytes = Data(repeating: 0x71, count: 96)
        try corruptedBytes.write(to: result, options: .atomic)
        try? fileManager.removeItem(
            at: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        )

        let recovered = SplatPreviousResultEvidence.recoverTrustedPreviousIfNeeded(
            projectURL: projectURL,
            manifest: manifest,
            fileManager: fileManager
        )

        XCTAssertEqual(recovered.stage, manifest.stage)
        XCTAssertEqual(try Data(contentsOf: result), corruptedBytes)
        XCTAssertEqual(try Data(contentsOf: externalBackup), trustedBytes)
    }

    func testProjectRecoveryRefusesExternalSnapshotAliasAndPreservesCurrentBytes() throws {
        let fileManager = FileManager.default
        let root = try makeRoot("snapshot-alias-recovery")
        let externalRoot = try makeRoot("snapshot-alias-external")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Snapshot alias safety")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x49, count: 64)
        let result = try commitResult(trustedBytes, in: projectURL, store: store)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        let snapshot = projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName)
        let externalSnapshot = externalRoot.appendingPathComponent("snapshot.json")
        try fileManager.moveItem(at: snapshot, to: externalSnapshot)
        try fileManager.createSymbolicLink(at: snapshot, withDestinationURL: externalSnapshot)

        let corruptedBytes = Data(repeating: 0x72, count: 96)
        try corruptedBytes.write(to: result, options: .atomic)
        try? fileManager.removeItem(
            at: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        )

        let recovered = SplatPreviousResultEvidence.recoverTrustedPreviousIfNeeded(
            projectURL: projectURL,
            manifest: manifest,
            fileManager: fileManager
        )

        XCTAssertEqual(recovered.stage, manifest.stage)
        XCTAssertEqual(try Data(contentsOf: result), corruptedBytes)
        XCTAssertTrue(fileManager.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path
        ))
        XCTAssertTrue(fileManager.fileExists(atPath: externalSnapshot.path))
    }

    private func commitResult(
        _ bytes: Data,
        in projectURL: URL,
        store: ScanProjectStore
    ) throws -> URL {
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try bytes.write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .finished
            value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }
        return result
    }

    private func makeProcessableRaw(in projectURL: URL, store: ScanProjectStore) throws {
        let images = projectURL.appendingPathComponent("images", isDirectory: true)
        try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: images.appendingPathComponent("frame_00000.jpg"))
        try Data("{}".utf8).write(to: projectURL.appendingPathComponent("transforms.json"))
        try Data("ply\n".utf8).write(to: projectURL.appendingPathComponent("points3D.ply"))
        let checkpoint = ScanCaptureCheckpoint(
            frames: [],
            featurePoints: [],
            coverageSectors: [],
            estimatedTargetCenter: nil,
            lastAcceptedTransform: nil,
            lastAcceptedTimestamp: 0
        )
        try store.saveCheckpoint(checkpoint, projectURL: projectURL)
    }

    private func makeRoot(_ suffix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-\(suffix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
