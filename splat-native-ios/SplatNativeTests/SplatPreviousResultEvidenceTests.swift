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
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))

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
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))
    }

    func testSameSizeTamperedPreviousResultNeverRegainsTrust() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, manifest) = try store.createProject(title: "Tampered previous")
        try makeProcessableRaw(in: projectURL, store: store)

        let result = try commitResult(
            bytes: Data(repeating: 0x11, count: 64),
            projectURL: projectURL,
            store: store
        )
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .processing
        }

        let previous = projectURL.appendingPathComponent(ScanProjectStore.previousSplatFileName)
        try Data(repeating: 0x22, count: 64).write(to: previous, options: .atomic)
        _ = try store.loadProject(id: manifest.id)

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: result))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))
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

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: newResult), newResult)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))
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
