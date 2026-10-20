import XCTest

final class SplatCompletionVerifierTests: XCTestCase {
    func testRejectsAlignedFinishedResultWithoutAtomicCompletionEvidence() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Uncommitted")
        let resultURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try Data(repeating: 0, count: 64).write(to: resultURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: resultURL))
        XCTAssertThrowsError(try SplatExportAdmission.preflight(sourceURL: resultURL, kind: .spz)) { error in
            guard case SplatExportAdmission.AdmissionError.untrustedSource = error else {
                return XCTFail("Expected untrustedSource, got \(error)")
            }
        }
    }

    func testAcceptsResultAfterAtomicCommitEvidenceAndFinishedManifest() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Committed")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0, count: 64).write(to: pendingURL)
        let resultURL = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let verified = try SplatCompletionVerifier.verify(sourceURL: resultURL)
        XCTAssertEqual(verified.standardizedFileURL, resultURL.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatStrongCompletionEvidence.fileName).path
        ))
    }

    func testRejectsResultWhoseByteCountNoLongerMatchesCommitEvidence() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Tampered")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0, count: 64).write(to: pendingURL)
        let resultURL = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let handle = try FileHandle(forWritingTo: resultURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(repeating: 0, count: 32))
        try handle.close()

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: resultURL))
    }

    func testRejectsSameSizeReplacementBeforeFirstStrongSeal() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Same-size pre-seal tamper")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x11, count: 64).write(to: pendingURL, options: .atomic)
        let resultURL = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        try Data(repeating: 0x22, count: 64).write(to: resultURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)],
            ofItemAtPath: resultURL.path
        )

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: resultURL))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatStrongCompletionEvidence.fileName).path
        ))
    }

    func testRejectsSameSizeReplacementAfterStrongSealEvenWhenMtimeIsRestored() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Same-size post-seal tamper")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x33, count: 64).write(to: pendingURL, options: .atomic)
        let resultURL = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: resultURL), resultURL)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let originalModificationDate = try XCTUnwrap(originalAttributes[.modificationDate] as? Date)

        try Data(repeating: 0x44, count: 64).write(to: resultURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: originalModificationDate],
            ofItemAtPath: resultURL.path
        )

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: resultURL))
    }

    func testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Strong integrity recovery")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        let resultURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)

        let trustedBytes = Data(repeating: 0x51, count: 64)
        try trustedBytes.write(to: pendingURL, options: .atomic)
        _ = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: resultURL), resultURL)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: resultURL)

        let newBytes = Data(repeating: 0x61, count: 64)
        try newBytes.write(to: pendingURL, options: .atomic)
        _ = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        // Seal the new result without going through the full verifier: a normal successful verifier
        // intentionally discards the trusted previous backup, while this regression needs to model a
        // failure that happens before that final cleanup point.
        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        let newEvidence = try JSONDecoder().decode(SplatCommitEvidence.self, from: Data(contentsOf: evidenceURL))
        _ = try SplatStrongCompletionEvidence.verifyOrSeal(sourceURL: resultURL, evidence: newEvidence)

        // Corrupt the new result without changing its byte count, then preserve its mtime so the
        // strong hash seal rather than the legacy size/mtime guard is what detects the damage.
        let attributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let modificationDate = try XCTUnwrap(attributes[.modificationDate] as? Date)
        try Data(repeating: 0x71, count: 64).write(to: resultURL, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: resultURL.path)

        // HQ2 STEP29: metadata-only witnesses; no scene bytes or hashes are emitted.
        let snapshotURL = projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName)
        let backupURL = projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        let snapshot = try JSONDecoder().decode(
            SplatPreviousResultEvidence.Snapshot.self, from: Data(contentsOf: snapshotURL)
        )
        let failedEvidence = try JSONDecoder().decode(
            SplatCommitEvidence.self, from: Data(contentsOf: evidenceURL)
        )
        let backupAttributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        let resultAttributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let backupLength = (backupAttributes[.size] as? NSNumber)?.int64Value ?? -1
        let resultLength = (resultAttributes[.size] as? NSNumber)?.int64Value ?? -1
        let timestampPredicate = snapshot.originalEvidence.completedAt <= failedEvidence.completedAt
            && snapshot.preservedAt <= failedEvidence.completedAt
        print("SCANLAB_RECOVERY_WITNESS",
              "schemaOK=\(snapshot.schemaVersion == SplatPreviousResultEvidence.Snapshot.currentSchemaVersion)",
              "sameSize=\(snapshot.originalEvidence.byteCount == failedEvidence.byteCount)",
              "timestampPredicate=\(timestampPredicate)",
              "backupBytesMatch=\(backupLength == snapshot.originalEvidence.byteCount)",
              "resultBytesMatch=\(resultLength == failedEvidence.byteCount)",
              "previousAt=\(snapshot.originalEvidence.completedAt.timeIntervalSince1970)",
              "preservedAt=\(snapshot.preservedAt.timeIntervalSince1970)",
              "currentAt=\(failedEvidence.completedAt.timeIntervalSince1970)")
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: resultURL), resultURL)
        XCTAssertEqual(try Data(contentsOf: resultURL), trustedBytes)
        let recovered = try store.loadManifest(projectURL: projectURL)
        XCTAssertTrue(recovered.recoveredAfterInterruption)
        XCTAssertTrue(recovered.lastError?.contains("復元") == true)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path
        ))
    }

    func testIntegrityRecoveryRejectsCorruptBackupWithoutDeletingEitherResult() throws {
        let fixture = try makeTwoGenerationRecoveryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let backup = fixture.project.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        let mutatedBackup = Data(repeating: 0x7B, count: 64)
        try mutatedBackup.write(to: backup, options: .atomic)
        let damagedCurrent = try Data(contentsOf: fixture.result)

        XCTAssertFalse(try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
            projectURL: fixture.project, evidence: fixture.evidence
        ))
        XCTAssertEqual(try Data(contentsOf: fixture.result), damagedCurrent)
        XCTAssertEqual(try Data(contentsOf: backup), mutatedBackup)
        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: fixture.result))
        XCTAssertEqual(try Data(contentsOf: backup), mutatedBackup)
        XCTAssertEqual(try Data(contentsOf: fixture.result), damagedCurrent)
    }

    func testIntegrityRecoveryRejectsUnprovenFuturePreservationTimestamp() throws {
        let fixture = try makeTwoGenerationRecoveryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let snapshotURL = fixture.project.appendingPathComponent(SplatPreviousResultEvidence.fileName)
        let backupURL = fixture.project.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        let original = try JSONDecoder().decode(
            SplatPreviousResultEvidence.Snapshot.self, from: Data(contentsOf: snapshotURL)
        )
        let future = SplatPreviousResultEvidence.Snapshot(
            originalEvidence: original.originalEvidence,
            sha256: original.sha256,
            preservedAt: fixture.evidence.completedAt.addingTimeInterval(60)
        )
        let backupBefore = try Data(contentsOf: backupURL)
        let currentBefore = try Data(contentsOf: fixture.result)
        try JSONEncoder().encode(future).write(to: snapshotURL, options: .atomic)

        XCTAssertFalse(try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
            projectURL: fixture.project, evidence: fixture.evidence
        ))
        XCTAssertEqual(try Data(contentsOf: backupURL), backupBefore)
        XCTAssertEqual(try Data(contentsOf: fixture.result), currentBefore)
    }

    private func makeTwoGenerationRecoveryFixture() throws -> (
        root: URL, project: URL, result: URL, evidence: SplatCommitEvidence
    ) {
        let root = try makeRoot()
        do {
            let store = ScanProjectStore(rootURL: root)
            let (project, _) = try store.createProject(title: "Recovery fault fixture")
            let pending = project.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
            let result = project.appendingPathComponent(ScanProjectStore.splatResultFileName)
            try Data(repeating: 0x51, count: 64).write(to: pending, options: .atomic)
            _ = try store.commitPendingSplat(projectURL: project)
            _ = try store.updateManifest(projectURL: project) { manifest in
                manifest.stage = .finished
                manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
            }
            _ = try SplatCompletionVerifier.verify(sourceURL: result)
            try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
            try Data(repeating: 0x61, count: 64).write(to: pending, options: .atomic)
            _ = try store.commitPendingSplat(projectURL: project)
            _ = try store.updateManifest(projectURL: project) { manifest in
                manifest.stage = .finished
                manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
            }
            let evidenceURL = project.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
            let evidence = try JSONDecoder().decode(
                SplatCommitEvidence.self, from: Data(contentsOf: evidenceURL)
            )
            _ = try SplatStrongCompletionEvidence.verifyOrSeal(sourceURL: result, evidence: evidence)
            let modified = try FileManager.default.attributesOfItem(atPath: result.path)
            let mtime = try XCTUnwrap(modified[.modificationDate] as? Date)
            try Data(repeating: 0x71, count: 64).write(to: result, options: .atomic)
            try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: result.path)
            return (root, project, result, evidence)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    func testRecoveryRejectsChangedCommitEvidenceAndPreservesBackup() throws {
        let fixture = try makeTwoGenerationRecoveryFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let backup = fixture.project.appendingPathComponent(SplatPreviousResultEvidence.assetFileName)
        let evidenceURL = fixture.project.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        let changed = SplatCommitEvidence(
            fileName: ScanProjectStore.splatResultFileName,
            byteCount: fixture.evidence.byteCount,
            completedAt: fixture.evidence.completedAt.addingTimeInterval(30)
        )
        try JSONEncoder().encode(changed).write(to: evidenceURL, options: .atomic)
        let existingResult = try Data(contentsOf: fixture.result)
        let existingBackup = try Data(contentsOf: backup)

        XCTAssertFalse(try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
            projectURL: fixture.project, evidence: fixture.evidence
        ))
        XCTAssertEqual(try Data(contentsOf: fixture.result), existingResult)
        XCTAssertEqual(try Data(contentsOf: backup), existingBackup)
        XCTAssertEqual(
            try JSONDecoder().decode(SplatCommitEvidence.self, from: Data(contentsOf: evidenceURL)),
            changed
        )
    }

    func testRejectsSiblingSplatEvenWhenProjectHasCommittedResult() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Sibling")
        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0, count: 64).write(to: pendingURL)
        _ = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let sibling = projectURL.appendingPathComponent("copied.splat")
        try Data(repeating: 0, count: 64).write(to: sibling)
        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: sibling))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-completion-verifier-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
