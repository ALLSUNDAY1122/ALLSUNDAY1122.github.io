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
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .captured
            manifest.acceptedFrames = 36
            manifest.featurePointCount = 900
            manifest.coverageSectorCount = 9
        }

        let relaunched = ScanProjectStore(rootURL: rootURL)
        let projects = relaunched.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].manifest.id, created.1.id)
        XCTAssertEqual(projects[0].manifest.title, "机")
        XCTAssertEqual(projects[0].manifest.acceptedFrames, 36)
    }

    func testCorruptedPrimaryManifestRecoversFromBackup() throws {
        let created = try store.createProject(title: "原本")
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.title = "復元対象"
        }
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.acceptedFrames = 12
        }
        try Data("broken-json".utf8).write(
            to: created.0.appendingPathComponent(ScanProjectStore.manifestFileName),
            options: .atomic
        )

        let relaunched = ScanProjectStore(rootURL: rootURL)
        let recovered = try relaunched.loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.title, "復元対象")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: created.0.appendingPathComponent(ScanProjectStore.manifestFileName).path
        ))
    }

    func testInterruptedProcessingReturnsToCapturedWhenRawExists() throws {
        let created = try store.createProject(title: "処理中")
        try makeProcessableRaw(in: created.0)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .processing
        }

        let relaunched = ScanProjectStore(rootURL: rootURL)
        let recovered = try relaunched.loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .captured)
        XCTAssertTrue(recovered.manifest.recoveredAfterInterruption)
        XCTAssertNotNil(recovered.manifest.lastError)
        XCTAssertTrue(recovered.manifest.rawDataRetained)
    }

    func testInterruptedProcessingCompletesRecoveryWhenSplatWasAlreadyWritten() throws {
        let created = try store.createProject(title: "書込済み")
        try Data(repeating: 1, count: 64).write(to: created.0.appendingPathComponent("result.splat"))
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .processing
        }

        let relaunched = ScanProjectStore(rootURL: rootURL)
        let recovered = try relaunched.loadProject(id: created.1.id)
        XCTAssertEqual(recovered.manifest.stage, .finished)
        XCTAssertEqual(recovered.manifest.splatFileName, "result.splat")
        XCTAssertTrue(recovered.manifest.recoveredAfterInterruption)
    }

    func testClearRawDataPreservesFinishedResultAndThumbnail() throws {
        let created = try store.createProject(title: "完成")
        try makeProcessableRaw(in: created.0)
        try Data(repeating: 2, count: 64).write(to: created.0.appendingPathComponent("result.splat"))
        try store.setThumbnail(data: Data(repeating: 3, count: 16), projectURL: created.0)
        _ = try store.updateManifest(projectURL: created.0) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = "result.splat"
        }

        try store.clearRawData(projectURL: created.0)
        let loaded = try store.loadProject(id: created.1.id)
        XCTAssertFalse(loaded.manifest.rawDataRetained)
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.0.appendingPathComponent("result.splat").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.0.appendingPathComponent(ScanProjectStore.thumbnailFileName).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.0.appendingPathComponent("images").path))
    }

    func testTrashIsRecoverableBeforePermanentDelete() throws {
        let created = try store.createProject(title: "削除テスト")
        try store.moveToTrash(projectURL: created.0)
        XCTAssertEqual(store.listProjects().count, 0)
        XCTAssertEqual(store.listTrash().count, 1)

        try store.restoreFromTrash(id: created.1.id)
        XCTAssertEqual(store.listProjects().count, 1)
        XCTAssertEqual(store.listTrash().count, 0)
    }

    func testLegacyPoCFolderMigratesWithoutLosingRawData() throws {
        let legacyID = "legacy-project"
        let legacy = rootURL.appendingPathComponent(legacyID).appendingPathExtension(ScanProjectStore.projectExtension)
        let images = legacy.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 20).write(to: images.appendingPathComponent("frame_00000.jpg"))
        try Data("{}".utf8).write(to: legacy.appendingPathComponent("transforms.json"))
        try Data("ply".utf8).write(to: legacy.appendingPathComponent("points3D.ply"))

        let relaunched = ScanProjectStore(rootURL: rootURL)
        let projects = relaunched.listProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].manifest.id, legacyID)
        XCTAssertEqual(projects[0].manifest.stage, .captured)
        XCTAssertTrue(projects[0].manifest.rawDataRetained)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent(ScanProjectStore.manifestFileName).path))
    }

    private func makeProcessableRaw(in projectURL: URL) throws {
        let images = projectURL.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data(repeating: 9, count: 20).write(to: images.appendingPathComponent("frame_00000.jpg"))
        try Data("{}".utf8).write(to: projectURL.appendingPathComponent("transforms.json"))
        try Data("ply".utf8).write(to: projectURL.appendingPathComponent("points3D.ply"))
    }
}
