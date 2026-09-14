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
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: resultURL), resultURL)

        // Corrupt the new result without changing its byte count, then preserve its mtime so the
        // strong hash seal rather than the legacy size/mtime guard is what detects the damage.
        let attributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let modificationDate = try XCTUnwrap(attributes[.modificationDate] as? Date)
        try Data(repeating: 0x71, count: 64).write(to: resultURL, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: resultURL.path)

        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: resultURL), resultURL)
        XCTAssertEqual(try Data(contentsOf: resultURL), trustedBytes)
        let recovered = try store.loadManifest(projectURL: projectURL)
        XCTAssertTrue(recovered.recoveredAfterInterruption)
        XCTAssertTrue(recovered.lastError?.contains("復元") == true)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path
        ))
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
