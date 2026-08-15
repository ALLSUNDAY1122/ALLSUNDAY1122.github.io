import Foundation
import XCTest

final class ScanProjectStoreTests: XCTestCase {
    private var rootURL: URL!
    private var store: ScanProjectStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanProjectStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = ScanProjectStore(rootURL: rootURL)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        store = nil
        rootURL = nil
    }

    func testProjectSurvivesStoreRecreation() throws {
        let created = try store.createProject(title: "机")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .captured
            manifest.acceptedFrames = 36
            manifest.featurePointCount = 900
            manifest.coverageSectorCount = 9
        }
        let projects = ScanProjectStore(rootURL: rootURL).listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].manifest.id, created.1.id)
        XCTAssertEqual(projects[0].manifest.acceptedFrames, 36)
        XCTAssertEqual(projects[0].manifest.stage, .captured)
    }

    func testCheckpointBackupRecoversAfterPrimaryCorruption() throws {
        let created = try store.createProject(title: "撮影途中")
        let first = ScanCaptureCheckpoint(
            frames: [], featurePoints: [StoredFeaturePoint(id: 1, x: 1, y: 2, z: 3)],
            coverageSectors: [0, 1], estimatedTargetCenter: StoredVector3(x: 0, y: 0, z: -1),
            lastAcceptedTransform: nil, lastAcceptedTimestamp: 10
        )
        let second = ScanCaptureCheckpoint(
            frames: [], featurePoints: [StoredFeaturePoint(id: 2, x: 4, y: 5, z: 6)],
            coverageSectors: [0, 1, 2], estimatedTargetCenter: StoredVector3(x: 0, y: 0, z: -1),
            lastAcceptedTransform: nil, lastAcceptedTimestamp: 20
        )
        try store.saveCheckpoint(first, projectURL: created.0)
        try store.saveCheckpoint(second, projectURL: created.0)
        try Data("broken-checkpoint".utf8).write(
            to: created.0.appendingPathComponent(ScanProjectStore.checkpointFileName), options: .atomic
        )
        let recovered = try ScanProjectStore(rootURL: rootURL).loadCheckpoint(projectURL: created.0)
        XCTAssertEqual(recovered.lastAcceptedTimestamp, 10)
        XCTAssertEqual(recovered.coverageSectors, [0, 1])
    }

    func testCorruptedPrimaryManifestRecoversFromBackup() throws {
        let created = try store.createProject(title: "原本")
        _ = try store.updateManifest(projectURL: created.0) { $0.title = "復元対象" }
        _ = try store.updateManifest(projectURL: created.0) { $0.acceptedFrames = 12 }
        try Data("broken-json".utf8).write(
            to: created.0.appendingPathComponent(ScanProjectStore.manifestFileName), options: .atomic
        )
        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.title, "復元対象")
    }

    func testInterruptedProcessingReturnsToCapturedWhenRawExists() throws {
        let created = try store.createProject(title: "処理中")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .captured)
        XCTAssertTrue(recovered.manifest.recoveredAfterInterruption)
        XCTAssertTrue(recovered.manifest.rawDataRetained)
    }

    func testAlignedPartialOutputIsNeverPromotedToFinished() throws {
        let created = try store.createProject(title: "aligned partial")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        let direct = created.0.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try splatData(0xAA).write(to: direct)

        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .captured)
        XCTAssertNil(recovered.manifest.splatFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: direct.path))
    }

    func testUnalignedPendingOutputIsDiscarded() throws {
        let created = try store.createProject(title: "unaligned partial")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        let pending = created.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0xBB, count: 47).write(to: pending)

        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .captured)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
    }

    func testCommittedSplatRecoversWhenManifestUpdateWasInterrupted() throws {
        let created = try store.createProject(title: "committed")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        let pending = created.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try splatData(0xCC).write(to: pending)
        _ = try store.commitPendingSplat(projectURL: created.0)

        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .finished)
        XCTAssertEqual(recovered.manifest.splatFileName, ScanProjectStore.splatResultFileName)
        XCTAssertEqual(try Data(contentsOf: recovered.resultURL!), splatData(0xCC))
    }

    func testReprocessCrashRestoresPreviousCompletedSplat() throws {
        let created = try store.createProject(title: "再生成")
        try makeProcessableRaw(in: created.0)
        let result = created.0.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try splatData(0x2A).write(to: result)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.previousSplatFileName).path
        ))
        try splatData(0xEE).write(to: result)

        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .finished)
        XCTAssertEqual(try Data(contentsOf: result), splatData(0x2A))
    }

    func testSuccessfulReprocessUsesPendingCommitContract() throws {
        let created = try store.createProject(title: "再生成成功")
        try makeProcessableRaw(in: created.0)
        let result = created.0.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try splatData(0x10).write(to: result)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        let pending = created.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try splatData(0x20).write(to: pending)
        let committed = try store.commitPendingSplat(projectURL: created.0)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = committed.lastPathComponent
        }

        XCTAssertEqual(try Data(contentsOf: result), splatData(0x20))
        XCTAssertNotNil(store.trustedSplatURL(projectURL: created.0))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.previousSplatFileName).path
        ))
    }

    func testMeshReprocessRequestUsesSameRetainedRawPackage() throws {
        let created = try store.createProject(title: "Mesh")
        try makeProcessableRaw(in: created.0)
        let request = try store.reprocessRequest(projectURL: created.0, representation: .mesh)
        XCTAssertEqual(request.representation, .mesh)
        XCTAssertEqual(request.projectID, created.1.id)
        XCTAssertEqual(request.imagesURL.lastPathComponent, "images")
    }

    func testFailureStateSurvivesRelaunch() throws {
        let created = try store.createProject(title: "失敗")
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .failed
            manifest.lastError = "synthetic failure"
        }
        let recovered = try ScanProjectStore(rootURL: rootURL).loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .failed)
        XCTAssertEqual(recovered.manifest.lastError, "synthetic failure")
    }

    func testClearRawDataPreservesCommittedResultThumbnailAndEvidence() throws {
        let created = try store.createProject(title: "完成")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { $0.stage = .processing }
        try splatData(2).write(to: created.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName))
        let result = try store.commitPendingSplat(projectURL: created.0)
        try store.setThumbnail(data: Data(repeating: 3, count: 16), projectURL: created.0)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = result.lastPathComponent
        }

        try store.clearRawData(projectURL: created.0)
        let loaded = try store.loadProject(id: created.1.id)
        XCTAssertFalse(loaded.manifest.rawDataRetained)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.thumbnailFileName).path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.0.appendingPathComponent("images").path))
    }

    func testTrashIsRecoverableAcrossRelaunchBeforePermanentDelete() throws {
        let created = try store.createProject(title: "削除テスト")
        try store.moveToTrash(projectURL: created.0)
        let relaunched = ScanProjectStore(rootURL: rootURL)
        XCTAssertEqual(relaunched.listProjects().count, 0)
        XCTAssertEqual(relaunched.listTrash().count, 1)
        try relaunched.restoreFromTrash(id: created.1.id)
        XCTAssertEqual(ScanProjectStore(rootURL: rootURL).listProjects().count, 1)
    }

    func testLegacyPoCFolderMigratesWithoutLosingRawData() throws {
        let legacyID = "legacy-project"
        let legacy = rootURL.appendingPathComponent(legacyID).appendingPathExtension(ScanProjectStore.projectExtension)
        try makeProcessableRaw(in: legacy)
        let projects = ScanProjectStore(rootURL: rootURL).listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].manifest.id, legacyID)
        XCTAssertEqual(projects[0].manifest.stage, .captured)
        XCTAssertTrue(projects[0].manifest.rawDataRetained)
    }

    private func makeProcessableRaw(in projectURL: URL) throws {
        let images = projectURL.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data(repeating: 9, count: 20).write(to: images.appendingPathComponent("frame_00000.jpg"))
        try Data("{}".utf8).write(to: projectURL.appendingPathComponent("transforms.json"))
        try Data("ply".utf8).write(to: projectURL.appendingPathComponent("points3D.ply"))
    }

    private func splatData(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 64)
    }
}
