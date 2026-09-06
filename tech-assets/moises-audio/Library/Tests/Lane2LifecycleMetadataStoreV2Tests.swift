import Foundation
import XCTest

final class Lane2LifecycleMetadataStoreV2Tests: XCTestCase {
    func testLegacyMigrationPreservesRecordsAndSourceDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2MetadataV2-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = UUID(), asset = UUID(), exportID = UUID(), attempt = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = Lane2LifecycleSnapshot(
            projects: [Lane2ProjectOwnershipRecord(projectUUID: project, sourceAssetUUID: asset, sourceRelativePath: "Imports/source.m4a", updatedAt: now)],
            exports: [Lane2ExportRecord(id: exportID, projectUUID: project, relativePath: "Exports/mix.m4a", mediaType: "audio/mp4", createdAt: now, state: .ready)],
            failures: [Lane2FailureRecord(attemptUUID: attempt, projectUUID: project, operation: .exportAudio, stableCode: "EXPORT_INTERRUPTED", retryable: true, createdAt: now)]
        )
        let legacyURL = root.appendingPathComponent(".LibraryLifecycle/lane2-lifecycle-v1.json")
        try FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(legacy).write(to: legacyURL, options: [.atomic])

        let snapshot = try await Lane2LifecycleMetadataStore(rootURL: root).snapshot()
        XCTAssertEqual(snapshot.projects.first?.sourceAssetUUID, asset)
        XCTAssertEqual(snapshot.exports.first?.id, exportID)
        XCTAssertEqual(snapshot.failures.first?.attemptUUID, attempt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".LibraryLifecycle/v2/schema.json").path))
    }

    func testProjectUpdateDoesNotRewriteUnrelatedShard() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2MetadataV2-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = Lane2LifecycleMetadataStore(rootURL: root)
        let first = UUID(), second = UUID()
        try await store.upsertProjectOwnership(projectUUID: first, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/a.m4a")
        try await store.upsertProjectOwnership(projectUUID: second, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/b.m4a")
        let secondURL = root.appendingPathComponent(".LibraryLifecycle/v2/projects/\(second.uuidString).json")
        let before = try Data(contentsOf: secondURL)
        try await store.upsertProjectOwnership(projectUUID: first, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/a2.m4a")
        XCTAssertEqual(try Data(contentsOf: secondURL), before)
    }

    func testCorruptShardFailsClosedThenExplicitQuarantinePreservesBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2MetadataV2-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = Lane2LifecycleMetadataStore(rootURL: root)
        let badProject = UUID(), goodProject = UUID()
        try await store.upsertProjectOwnership(projectUUID: badProject, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/bad.m4a")
        try await store.upsertProjectOwnership(projectUUID: goodProject, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/good.m4a")
        let badURL = root.appendingPathComponent(".LibraryLifecycle/v2/projects/\(badProject.uuidString).json")
        let bytes = Data("not-json".utf8)
        try bytes.write(to: badURL, options: [.atomic])

        do {
            _ = try await store.snapshot()
            XCTFail("Expected corrupt shard")
        } catch Lane2LifecycleMetadataFailure.corruptShard { }

        let report = try await store.quarantineCorruptShards()
        XCTAssertEqual(report.quarantinedRelativePaths.count, 1)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(try XCTUnwrap(report.quarantinedRelativePaths.first))), bytes)
        let recovered = try await store.snapshot()
        XCTAssertEqual(recovered.projects.map(\.projectUUID), [goodProject])
    }

    func testCorruptLegacyRequiresExplicitRecoveryAndPreservesRawDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2MetadataV2-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = root.appendingPathComponent(".LibraryLifecycle/lane2-lifecycle-v1.json")
        try FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("legacy-corrupt".utf8)
        try bytes.write(to: legacyURL)
        let store = Lane2LifecycleMetadataStore(rootURL: root)

        do {
            _ = try await store.snapshot()
            XCTFail("Expected corrupt legacy")
        } catch Lane2LifecycleMetadataFailure.corruptDocument { }

        let preservedOptional = try await store.quarantineCorruptLegacyDocument()
        let preserved = try XCTUnwrap(preservedOptional)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(preserved)), bytes)
        let empty = try await store.snapshot()
        XCTAssertTrue(empty.projects.isEmpty)
        XCTAssertTrue(empty.exports.isEmpty)
    }

    func testCleanupStateAndFailureBoundSurviveReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2MetadataV2-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = UUID()
        let store = Lane2LifecycleMetadataStore(rootURL: root)
        let exports = try await store.recordExports(projectUUID: project, artifacts: [("Exports/a.m4a", "audio/mp4"), ("Exports/b.m4a", "audio/mp4")])
        _ = try await store.beginExportCleanup(projectUUID: project)
        let reopened = Lane2LifecycleMetadataStore(rootURL: root)
        let pending = try await reopened.pendingExportCleanup()
        XCTAssertEqual(pending.count, 2)
        for record in exports { try await reopened.finishExportCleanup(exportID: record.id) }
        let pendingAfter = try await reopened.pendingExportCleanup()
        XCTAssertTrue(pendingAfter.isEmpty)

        for index in 0..<80 {
            try await reopened.recordFailure(Lane2FailureRecord(attemptUUID: UUID(), projectUUID: project, operation: .storagePreflight, stableCode: "F\(index)", retryable: true, createdAt: Date(timeIntervalSince1970: Double(index))))
        }
        let snapshot = try await reopened.snapshot()
        XCTAssertEqual(snapshot.failures.count, 64)
        XCTAssertEqual(snapshot.failures.first?.stableCode, "F16")
        XCTAssertEqual(snapshot.failures.last?.stableCode, "F79")
    }
}
