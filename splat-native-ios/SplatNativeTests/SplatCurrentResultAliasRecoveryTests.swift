import XCTest

final class SplatCurrentResultAliasRecoveryTests: XCTestCase {
    func testTrustedBackupRepairsSymlinkedCurrentResultWithoutTouchingExternalTarget() throws {
        let fileManager = FileManager.default
        let root = try makeRoot("current-result-alias")
        let externalRoot = try makeRoot("current-result-external")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Repair aliased current result")
        try makeProcessableRaw(in: projectURL, store: store)

        let trustedBytes = Data(repeating: 0x19, count: 64)
        let result = try commitResult(trustedBytes, in: projectURL, store: store)
        XCTAssertEqual(try SplatCompletionVerifier.verify(sourceURL: result), result)
        try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: result)

        let external = externalRoot.appendingPathComponent("replacement.splat")
        let externalBytes = Data(repeating: 0x7A, count: trustedBytes.count)
        try externalBytes.write(to: external, options: .atomic)
        try fileManager.removeItem(at: result)
        try fileManager.createSymbolicLink(at: result, withDestinationURL: external)

        let verified = try SplatCompletionVerifier.verify(sourceURL: result)

        XCTAssertEqual(verified.standardizedFileURL, result.standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: result), trustedBytes)
        XCTAssertEqual(try Data(contentsOf: external), externalBytes)
        let values = try result.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        XCTAssertEqual(values.isRegularFile, true)
        XCTAssertNotEqual(values.isSymbolicLink, true)
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
