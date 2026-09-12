import XCTest

final class SplatPreviousResultEvidenceTests: XCTestCase {
    func testInterruptedReprocessRestoresPreviousResultAsTrusted() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Previous trusted")
        try makeProcessableRaw(in: projectURL, store: store)

        let result = try commitResult(
            bytes: Data(repeating: 0x2A, count: 64),
            projectURL: projectURL,
            store: store
        )
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)

        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
        assertBackupExists(projectURL)

        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .processing
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.previousSplatFileName).path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))

        let repaired = try store.loadProject(id: manifest.id)
        XCTAssertEqual(repaired.manifest.stage, .finished)
        XCTAssertTrue(repaired.manifest.recoveredAfterInterruption)

        let verified = try SplatCompletionVerifier.verify(sourceURL: result)
        XCTAssertEqual(verified.standardizedFileURL, result.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))
        assertBackupMissing(projectURL)
    }

    func testRepeatedRetryCannotDeleteLastTrustedCompletedResult() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Repeated retry")
        try makeProcessableRaw(in: projectURL, store: store)

        let result = try commitResult(
            bytes: Data(repeating: 0x51, count: 64),
            projectURL: projectURL,
            store: store
        )
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        // First reprocess starts and fails before a new result is committed.
        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .processing }
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .failed
            value.lastError = "simulated first failure"
        }

        // Immediate retry from `.failed` is the legacy edge case: Store removes its own
        // `result.previous.splat` because the previous manifest is no longer `.finished`.
        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .processing }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.previousSplatFileName).path
        ))
        assertBackupExists(projectURL)

        // Simulate another interruption. Store can no longer recover from its swap file, but C2's
        // exact protected backup remains available.
        let repaired = try store.loadProject(id: manifest.id)
        XCTAssertNotEqual(repaired.manifest.stage, .finished)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))

        let verified = try SplatCompletionVerifier.verify(sourceURL: result)
        XCTAssertEqual(verified.standardizedFileURL, result.standardizedFileURL)
        let restored = try store.loadProject(id: manifest.id)
        XCTAssertEqual(restored.manifest.stage, .finished)
        XCTAssertTrue(restored.manifest.recoveredAfterInterruption)
        XCTAssertEqual(try Data(contentsOf: result), Data(repeating: 0x51, count: 64))
        assertBackupMissing(projectURL)
    }

    func testSameSizeTamperedProtectedBackupNeverRegainsTrust() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Tampered protected backup")
        try makeProcessableRaw(in: projectURL, store: store)

        let result = try commitResult(
            bytes: Data(repeating: 0x11, count: 64),
            projectURL: projectURL,
            store: store
        )
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .processing }

        let protectedAsset = projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        try Data(repeating: 0x22, count: 64).write(to: protectedAsset, options: .atomic)

        // Exhaust Store's ordinary previous swap so only the tampered protected copy remains.
        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .failed }
        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .processing }
        _ = try store.loadProject(id: manifest.id)

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: result))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))
        XCTAssertTrue(FileManager.default.fileExists(atPath: protectedAsset.path))
    }

    func testSuccessfulReprocessUsesNewEvidenceAndDiscardsOldBackupOnVerification() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Successful reprocess")
        try makeProcessableRaw(in: projectURL, store: store)

        let result = try commitResult(
            bytes: Data(repeating: 0x33, count: 64),
            projectURL: projectURL,
            store: store
        )
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .processing
        }

        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x44, count: 96).write(to: pending, options: .atomic)
        let newResult = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .finished
            value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        assertBackupExists(projectURL)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: newResult), newResult)
        XCTAssertEqual(try Data(contentsOf: newResult), Data(repeating: 0x44, count: 96))
        assertBackupMissing(projectURL)
    }

    private func assertBackupExists(_ projectURL: URL, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path),
            file: file,
            line: line
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path),
            file: file,
            line: line
        )
    }

    private func assertBackupMissing(_ projectURL: URL, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path),
            file: file,
            line: line
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path),
            file: file,
            line: line
        )
    }

    private func commitResult(
        bytes: Data,
        projectURL: URL,
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

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-previous-evidence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
