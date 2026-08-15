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
