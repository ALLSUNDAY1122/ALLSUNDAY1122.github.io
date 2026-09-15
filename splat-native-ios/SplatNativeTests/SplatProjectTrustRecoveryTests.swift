import XCTest

final class SplatProjectTrustRecoveryTests: XCTestCase {
    func testUntrustedFinishedProjectWithRawDataCanBeDowngradedForSafeReprocess() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Recoverable")

        try makeProcessableRaw(in: projectURL, store: store)
        let result = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try Data(repeating: 0, count: 64).write(to: result)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let before = try store.loadProject(id: projectURL.deletingPathExtension().lastPathComponent)
        XCTAssertNil(SplatProjectTrustRecovery.trustedResultURL(for: before))
        XCTAssertTrue(SplatProjectTrustRecovery.canRecoverForReprocess(before, store: store))

        try SplatProjectTrustRecovery.prepareForReprocess(before, store: store)
        let repaired = try store.loadProject(id: before.id)

        XCTAssertEqual(repaired.manifest.stage, .captured)
        XCTAssertNil(repaired.manifest.splatFileName)
        XCTAssertTrue(repaired.manifest.rawDataRetained)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path), "Suspect output is retained until reconstruction actually starts")
    }

    func testTrustedCompletedProjectIsNeverDowngraded() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Trusted")
        try makeProcessableRaw(in: projectURL, store: store)

        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0, count: 64).write(to: pending)
        _ = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let project = try store.loadProject(id: projectURL.deletingPathExtension().lastPathComponent)
        XCTAssertNotNil(SplatProjectTrustRecovery.trustedResultURL(for: project))
        XCTAssertFalse(SplatProjectTrustRecovery.canRecoverForReprocess(project, store: store))
        XCTAssertThrowsError(try SplatProjectTrustRecovery.prepareForReprocess(project, store: store))
    }

    func testUntrustedFinishedProjectWithoutRawDataCannotPretendToBeRecoverable() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "No raw")
        let result = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try Data(repeating: 0, count: 64).write(to: result)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
            manifest.rawDataRetained = false
        }

        let project = try store.loadProject(id: projectURL.deletingPathExtension().lastPathComponent)
        XCTAssertNil(SplatProjectTrustRecovery.trustedResultURL(for: project))
        XCTAssertFalse(SplatProjectTrustRecovery.canRecoverForReprocess(project, store: store))
        XCTAssertThrowsError(try SplatProjectTrustRecovery.prepareForReprocess(project, store: store))
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
            .appendingPathComponent("c2-trust-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
