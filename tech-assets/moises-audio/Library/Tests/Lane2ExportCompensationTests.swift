import Foundation
import XCTest
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2ExportCompensationTests: XCTestCase {
    func testMetadataCommitFailureRemovesProducedExportButPreservesCorruptShard() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2Compensation-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let metadata = Lane2LifecycleMetadataStore(rootURL: root)
        _ = try await metadata.snapshot()
        let projectID = ProjectID()
        let corruptShard = root
            .appendingPathComponent(".LibraryLifecycle/v2/exports", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString + ".json")
        try FileManager.default.createDirectory(at: corruptShard.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: corruptShard)

        let relativePath = "Exports/Batches/\(UUID().uuidString)/Vocals.m4a"
        let coordinator = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: AW09UnusedImporter(),
            exporter: AW09WritingExporter(root: root, relativePath: relativePath),
            library: AW09EmptyLibrary(),
            metadata: metadata,
            storageReserveBytes: 64
        )

        await XCTAssertThrowsErrorAsyncAW09 {
            _ = try await coordinator.exportAndRecord(
                ExportRequest(projectID: projectID, kind: .separatedStems, preferredContainer: "m4a")
            )
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptShard.path), "corrupt metadata is preserved for explicit quarantine")
    }

    func testUnsafeReturnedPathIsNeverDeletedAndCompensationFailureIsDurablySignalled() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2Compensation-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let metadata = Lane2LifecycleMetadataStore(rootURL: root)
        _ = try await metadata.snapshot()
        let projectID = ProjectID()

        let corruptShard = root
            .appendingPathComponent(".LibraryLifecycle/v2/exports", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString + ".json")
        try FileManager.default.createDirectory(at: corruptShard.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: corruptShard)

        let unsafePath = "Imports/do-not-delete.m4a"
        let coordinator = Lane2DurableLifecycleCoordinator(
            rootURL: root,
            importer: AW09UnusedImporter(),
            exporter: AW09WritingExporter(root: root, relativePath: unsafePath),
            library: AW09EmptyLibrary(),
            metadata: metadata,
            storageReserveBytes: 64
        )

        await XCTAssertThrowsErrorAsyncAW09 {
            _ = try await coordinator.exportAndRecord(
                ExportRequest(projectID: projectID, kind: .customMix, preferredContainer: "m4a")
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(unsafePath).path))
        let latest = try await metadata.latestFailure(projectUUID: projectID.rawValue)
        XCTAssertEqual(latest?.stableCode, "EXPORT_COMPENSATION_INCOMPLETE")
    }
}

private struct AW09UnusedImporter: AudioImporting {
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        throw DomainFailure.cancelled
    }
}

private struct AW09WritingExporter: AudioExporting {
    let root: URL
    let relativePath: String

    func export(_ request: ExportRequest) async throws -> [ExportArtifact] {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("export".utf8).write(to: url)
        return [ExportArtifact(relativePath: relativePath, mediaType: "audio/mp4")]
    }
}

private actor AW09EmptyLibrary: ProjectLibraryPersisting {
    func createProject(source: LocalAudioAsset) async throws -> ProjectID { ProjectID() }
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {}
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
    func listProjects() async throws -> [PersistedProjectSnapshot] { [] }
    func loadProject(projectID: ProjectID) async throws -> PersistedProjectSnapshot? { nil }
    func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws {}
    func createSetlist(name: String) async throws -> SetlistID { SetlistID() }
    func renameSetlist(setlistID: SetlistID, name: String) async throws {}
    func listSetlists() async throws -> [SetlistSnapshot] { [] }
    func replaceSetlistEntries(setlistID: SetlistID, orderedProjectIDs: [ProjectID]) async throws {}
    func deleteSetlist(setlistID: SetlistID) async throws {}
    func deleteProject(projectID: ProjectID) async throws {}
    func recoveryPlan(projectID: ProjectID) async throws -> ProcessingRecoveryPlan { .none }
}

private func XCTAssertThrowsErrorAsyncAW09(
    _ operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
