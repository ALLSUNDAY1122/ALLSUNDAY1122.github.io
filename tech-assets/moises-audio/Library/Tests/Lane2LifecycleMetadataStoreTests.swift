import Foundation
import XCTest

final class Lane2LifecycleMetadataStoreTests: XCTestCase {
    func testOwnershipExportsCleanupAndFailureSurviveReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2Metadata-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let project = UUID()
        let asset = UUID()
        let first = Lane2LifecycleMetadataStore(rootURL: root)
        try await first.upsertProjectOwnership(
            projectUUID: project,
            sourceAssetUUID: asset,
            sourceRelativePath: "Imports/song.m4a"
        )
        let exports = try await first.recordExports(
            projectUUID: project,
            artifacts: [("Exports/mix.m4a", "audio/mp4")]
        )
        XCTAssertEqual(exports.count, 1)

        let attempt = UUID()
        try await first.recordFailure(
            Lane2FailureRecord(
                attemptUUID: attempt,
                projectUUID: project,
                operation: .exportAudio,
                stableCode: "EXPORT_INTERRUPTED",
                retryable: true,
                createdAt: Date()
            )
        )

        let reopened = Lane2LifecycleMetadataStore(rootURL: root)
        let snapshot = try await reopened.snapshot()
        XCTAssertEqual(snapshot.projects.first?.sourceAssetUUID, asset)
        XCTAssertEqual(snapshot.exports.first?.state, .ready)
        let latest = try await reopened.latestFailure(projectUUID: project)
        XCTAssertEqual(latest?.stableCode, "EXPORT_INTERRUPTED")

        let deleting = try await reopened.beginExportCleanup(projectUUID: project)
        XCTAssertEqual(deleting.first?.state, .deleting)
        let pending = try await Lane2LifecycleMetadataStore(rootURL: root).pendingExportCleanup()
        XCTAssertEqual(pending.count, 1)
        try await reopened.finishExportCleanup(exportID: try XCTUnwrap(deleting.first?.id))
        let afterCleanup = try await reopened.snapshot()
        XCTAssertTrue(afterCleanup.exports.isEmpty)
    }

    func testAbsoluteTraversalAndCorruptDocumentFailClosed() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lane2Metadata-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = Lane2LifecycleMetadataStore(rootURL: root)

        await XCTAssertThrowsErrorAsyncMetadata {
            try await store.upsertProjectOwnership(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                sourceRelativePath: "../escape.m4a"
            )
        }

        let url = root.appendingPathComponent(".LibraryLifecycle/lane2-lifecycle-v1.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: url)
        await XCTAssertThrowsErrorAsyncMetadata { _ = try await Lane2LifecycleMetadataStore(rootURL: root).snapshot() }
    }
}

private func XCTAssertThrowsErrorAsyncMetadata(
    _ operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
