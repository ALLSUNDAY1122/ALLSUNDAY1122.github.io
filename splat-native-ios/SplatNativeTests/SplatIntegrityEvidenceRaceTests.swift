import XCTest

final class SplatIntegrityEvidenceRaceTests: XCTestCase {
    func testLateRecoveryRefusesStaleFailedEvidenceAfterNewerEvidenceAppears() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-integrity-evidence-race-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Integrity evidence race")
        try makeProcessableRaw(in: projectURL, store: store)

        let oldBytes = Data(repeating: 0x41, count: 64)
        let result = try commit(oldBytes, projectURL: projectURL, store: store)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        _ = try store.updateManifest(projectURL: projectURL) { $0.stage = .processing }
        let newBytes = Data(repeating: 0x51, count: 64)
        _ = try commit(newBytes, projectURL: projectURL, store: store)

        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        let failedEvidence = try JSONDecoder().decode(
            SplatCommitEvidence.self,
            from: Data(contentsOf: evidenceURL)
        )

        // Model a completion that wins after verification captured failedEvidence but before recovery.
        let newerEvidence = SplatCommitEvidence(
            fileName: ScanProjectStore.splatResultFileName,
            byteCount: failedEvidence.byteCount,
            completedAt: failedEvidence.completedAt.addingTimeInterval(1)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(newerEvidence).write(to: evidenceURL, options: .atomic)

        let corrupted = Data(repeating: 0x61, count: 64)
        try corrupted.write(to: result, options: .atomic)

        XCTAssertFalse(try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
            projectURL: projectURL,
            evidence: failedEvidence
        ))
        XCTAssertEqual(try Data(contentsOf: result), corrupted)
        XCTAssertEqual(
            try JSONDecoder().decode(SplatCommitEvidence.self, from: Data(contentsOf: evidenceURL)),
            newerEvidence
        )
    }

    private func commit(
        _ bytes: Data,
        projectURL: URL,
        store: ScanProjectStore
    ) throws -> URL {
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try bytes.write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
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
}
