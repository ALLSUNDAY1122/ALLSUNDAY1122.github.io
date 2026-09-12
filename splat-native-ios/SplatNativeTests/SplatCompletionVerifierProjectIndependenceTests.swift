import XCTest

final class SplatCompletionVerifierProjectIndependenceTests: XCTestCase {
    func testCompletionVerifierRejectsExternalCommitEvidenceAlias() throws {
        let fileManager = FileManager.default
        let root = try makeRoot("commit-evidence-alias")
        let externalRoot = try makeRoot("commit-evidence-external")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "External evidence must not verify")
        try makeProcessableRaw(in: projectURL, store: store)

        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x52, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .finished
            value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        let externalEvidence = externalRoot.appendingPathComponent("commit.json")
        try fileManager.moveItem(at: evidenceURL, to: externalEvidence)
        try fileManager.createSymbolicLink(at: evidenceURL, withDestinationURL: externalEvidence)

        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: result)) { error in
            guard case SplatCompletionVerifier.VerificationError.completionEvidenceMissing = error else {
                return XCTFail("Expected completionEvidenceMissing for aliased evidence, got \(error)")
            }
        }
        XCTAssertFalse(fileManager.fileExists(
            atPath: projectURL.appendingPathComponent(SplatStrongCompletionEvidence.fileName).path
        ))
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
