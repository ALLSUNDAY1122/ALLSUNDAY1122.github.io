import XCTest

final class SplatPreviousResultIntegrityRecoveryTests: XCTestCase {
    func testSameSizeCorruptedCurrentResultRecoversFromExactTrustedBackup() throws {
        let root = try makeRoot("same-size-current-recovery")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Same-size integrity recovery")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x31, count: 64)
        let result = try commitResult(trustedBytes, in: projectURL, store: store)

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
        assertBackupMissing(projectURL)
    }

    func testCorruptedNewerCommitNeverRollsBackToOlderTrustedBackup() throws {
        let root = try makeRoot("newer-commit-no-rollback")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Do not restore stale backup")
        try makeProcessableRaw(in: projectURL, store: store)

        let oldBytes = Data(repeating: 0x22, count: 64)
        let oldResult = try commitResult(oldBytes, in: projectURL, store: store)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: oldResult), oldResult)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: oldResult)

        _ = try store.updateManifest(projectURL: projectURL) { value in value.stage = .processing }
        let newBytes = Data(repeating: 0x55, count: 96)
        let newResult = try commitResult(newBytes, in: projectURL, store: store)

        // Keep the old protected backup alive and corrupt the newer commit without changing size.
        try Data(repeating: 0x6A, count: newBytes.count).write(to: newResult, options: .atomic)
        XCTAssertThrowsError(try SplatCompletionVerifier.verify(sourceURL: newResult))
        XCTAssertEqual(try Data(contentsOf: newResult), Data(repeating: 0x6A, count: newBytes.count))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectURL.appendingPathComponent(SplatPreviousResultEvidence.assetFileName).path
        ))
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
