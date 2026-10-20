import XCTest

final class SplatMissingResultRecoveryTests: XCTestCase {
    func testMissingCurrentResultRecoversFromTrustedBackupForSameCompletionEvidence() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-missing-result-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Missing result recovery")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x39, count: 64)
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try trustedBytes.write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)
        try FileManager.default.removeItem(at: result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))

        let verified = try SplatCompletionVerifier.verifyWithDigest(sourceURL: result)
        XCTAssertEqual(verified.url.standardizedFileURL, result.standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: result), trustedBytes)
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
