import Foundation
import XCTest
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2DurableLifecycleCoordinatorTests: XCTestCase {
    func testImportPersistEditExportAndRelaunchMetadataLifecycle() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2E2E-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Lane2FakeLibrary()
        let coordinator = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: Lane2FakeImporter(root: root, failure: nil),
            exporter: Lane2FakeExporter(root: root),
            library: library,
            metadata: Lane2LifecycleMetadataStore(rootURL: root),
            storageReserveBytes: 64
        )

        let projectID = try await coordinator.importAndCreateProject(from: .appOwnedFile(relativePath: "ignored.m4a"))
        let edits = ProjectUserEdits(
            schemaVersion: 1,
            tempoRatio: 0.9,
            pitchSemitones: 1,
            metronomeEnabled: true,
            countInClicks: 4,
            loopStartSeconds: 2,
            loopEndSeconds: 8,
            stemMix: []
        )
        try await coordinator.saveUserEdits(projectID: projectID, edits: edits)
        let exported = try await coordinator.exportAndRecord(
            ExportRequest(projectID: projectID, kind: .customMix, preferredContainer: "m4a")
        )
        XCTAssertEqual(exported.count, 1)

        let first = try await coordinator.relaunchState(projectID: projectID)
        XCTAssertEqual(first.project?.projectID, projectID)
        XCTAssertEqual(first.project?.edits, edits)
        XCTAssertEqual(first.ownership?.projectUUID, projectID.rawValue)
        XCTAssertEqual(first.exports.count, 1)

        // Simulate death after ready -> deleting metadata commit and before file deletion.
        let metadata = Lane2LifecycleMetadataStore(rootURL: root)
        let deleting = try await metadata.beginExportCleanup(projectUUID: projectID.rawValue)
        let exportURL = root.appendingPathComponent(try XCTUnwrap(deleting.first?.relativePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        let relaunched = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: Lane2FakeImporter(root: root, failure: nil),
            exporter: Lane2FakeExporter(root: root),
            library: library,
            metadata: Lane2LifecycleMetadataStore(rootURL: root),
            storageReserveBytes: 64
        )
        try await relaunched.recoverPendingExportCleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
        let afterCleanup = try await relaunched.lifecycleSnapshot()
        XCTAssertTrue(afterCleanup.exports.isEmpty)
    }

    func testInterruptedImportOwnershipHandoffIsRepairedFromCanonicalLibrary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2E2E-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourcePath = "Imports/reconcile/source.m4a"
        let sourceURL = root.appendingPathComponent(sourcePath)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: sourceURL)

        let library = Lane2FakeLibrary()
        let source = LocalAudioAsset(id: AssetID(), relativePath: sourcePath, mediaKind: .audio, durationSeconds: 8)
        let projectID = try await library.createProject(source: source)
        let metadata = Lane2LifecycleMetadataStore(rootURL: root)
        let before = try await metadata.snapshot()
        XCTAssertTrue(before.projects.isEmpty)

        let coordinator = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: Lane2FakeImporter(root: root, failure: nil),
            exporter: Lane2FakeExporter(root: root),
            library: library,
            metadata: metadata,
            storageReserveBytes: 64
        )
        try await coordinator.reconcileProjectOwnership()
        let repaired = try await coordinator.lifecycleSnapshot()
        XCTAssertEqual(repaired.projects.first?.projectUUID, projectID.rawValue)
        XCTAssertEqual(repaired.projects.first?.sourceAssetUUID, source.id.rawValue)
        XCTAssertEqual(repaired.projects.first?.sourceRelativePath, sourcePath)
    }

    func testCanonicalDeleteConvergesExportAndOwnershipCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2E2E-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Lane2FakeLibrary()
        let coordinator = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: Lane2FakeImporter(root: root, failure: nil),
            exporter: Lane2FakeExporter(root: root),
            library: library,
            metadata: Lane2LifecycleMetadataStore(rootURL: root),
            storageReserveBytes: 64
        )
        let projectID = try await coordinator.importAndCreateProject(from: .appOwnedFile(relativePath: "ignored.m4a"))
        let exported = try await coordinator.exportAndRecord(
            ExportRequest(projectID: projectID, kind: .customMix, preferredContainer: "m4a")
        )
        let exportURL = root.appendingPathComponent(try XCTUnwrap(exported.first?.relativePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        try await coordinator.deleteProjectAndOwnedArtifacts(projectID: projectID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
        let snapshot = try await coordinator.lifecycleSnapshot()
        XCTAssertFalse(snapshot.projects.contains { $0.projectUUID == projectID.rawValue })
        XCTAssertFalse(snapshot.exports.contains { $0.projectUUID == projectID.rawValue })
    }

    func testUnsupportedCodecAndStoragePressurePersistStableFailureCodes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2E2E-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Lane2FakeLibrary()
        let failing = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: Lane2FakeImporter(root: root, failure: .unsupportedMedia),
            exporter: Lane2FakeExporter(root: root),
            library: library,
            metadata: Lane2LifecycleMetadataStore(rootURL: root),
            storageReserveBytes: 64
        )

        await XCTAssertThrowsErrorAsyncCoordinator {
            _ = try await failing.importAndCreateProject(from: .appOwnedFile(relativePath: "bad.wma"))
        }
        let reopened = Lane2LifecycleMetadataStore(rootURL: root)
        let unsupported = try await reopened.latestFailure(projectUUID: nil)
        XCTAssertEqual(unsupported?.stableCode, "UNSUPPORTED_MEDIA")

        await XCTAssertThrowsErrorAsyncCoordinator {
            try await failing.preflight(requiredBytes: 100, availableBytes: 100)
        }
        let storage = try await reopened.latestFailure(projectUUID: nil)
        XCTAssertEqual(storage?.stableCode, "INSUFFICIENT_STORAGE")
    }
}

private actor Lane2FakeLibrary: ProjectLibraryPersisting {
    private var projects: [ProjectID: PersistedProjectSnapshot] = [:]

    func createProject(source: LocalAudioAsset) async throws -> ProjectID {
        let id = ProjectID()
        projects[id] = PersistedProjectSnapshot(projectID: id, source: source, processing: nil, stems: [], edits: nil)
        return id
    }

    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {
        guard let project = projects[projectID] else { return }
        projects[projectID] = PersistedProjectSnapshot(
            projectID: project.projectID,
            source: project.source,
            processing: snapshot,
            stems: project.stems,
            edits: project.edits
        )
    }

    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {
        guard let project = projects[projectID] else { return }
        projects[projectID] = PersistedProjectSnapshot(
            projectID: project.projectID,
            source: project.source,
            processing: project.processing,
            stems: stems,
            edits: project.edits
        )
    }

    func listProjects() async throws -> [PersistedProjectSnapshot] { Array(projects.values) }
    func loadProject(projectID: ProjectID) async throws -> PersistedProjectSnapshot? { projects[projectID] }

    func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws {
        guard let project = projects[projectID] else { return }
        projects[projectID] = PersistedProjectSnapshot(
            projectID: project.projectID,
            source: project.source,
            processing: project.processing,
            stems: project.stems,
            edits: edits
        )
    }

    func createSetlist(name: String) async throws -> SetlistID { SetlistID() }
    func renameSetlist(setlistID: SetlistID, name: String) async throws {}
    func listSetlists() async throws -> [SetlistSnapshot] { [] }
    func replaceSetlistEntries(setlistID: SetlistID, orderedProjectIDs: [ProjectID]) async throws {}
    func deleteSetlist(setlistID: SetlistID) async throws {}
    func deleteProject(projectID: ProjectID) async throws { projects.removeValue(forKey: projectID) }
    func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan { .none }
}

private struct Lane2FakeImporter: AudioImporting {
    let root: URL
    let failure: DomainFailure?

    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        if let failure { throw failure }
        let relativePath = "Imports/e2e/source.m4a"
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: url)
        return LocalAudioAsset(id: AssetID(), relativePath: relativePath, mediaKind: .audio, durationSeconds: 12)
    }
}

private struct Lane2FakeExporter: AudioExporting {
    let root: URL

    func export(_ request: ExportRequest) async throws -> [ExportArtifact] {
        let relativePath = "Exports/\(request.projectID.rawValue.uuidString).m4a"
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("export".utf8).write(to: url)
        return [ExportArtifact(relativePath: relativePath, mediaType: "audio/mp4")]
    }
}

private func XCTAssertThrowsErrorAsyncCoordinator(
    _ operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
