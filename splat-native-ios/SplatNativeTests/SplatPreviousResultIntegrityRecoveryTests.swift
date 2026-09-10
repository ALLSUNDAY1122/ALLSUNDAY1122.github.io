import XCTest

final class SplatPreviousResultIntegrityRecoveryTests: XCTestCase {
    func testSameSizeCorruptedCurrentResultRecoversFromExactTrustedBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-same-size-current-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Same-size integrity recovery")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x31, count: 64)
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try trustedBytes.write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .finished
            value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        // Seal the trusted commit, then preserve the exact previous bytes as reprocess protection.
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        // Atomic replacement keeps the byte count identical while changing the content hash. This
        // used to bypass structural recovery and then fail the strong verifier without using the
        // valid protected backup.
        try Data(repeating: 0x7C, count: trustedBytes.count).write(to: result, options: .atomic)
        XCTAssertNotEqual(try Data(contentsOf: result), trustedBytes)

        let verified = try SplatCompletionVerifier.verifyWithDigest(sourceURL: result)
        XCTAssertEqual(verified.url.standardizedFileURL, result.standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: result), trustedBytes)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.fileName).path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path
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
}
