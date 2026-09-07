import Foundation
import XCTest

final class Lane2LifecycleQuarantineRecoveryTests: XCTestCase {
    func testValidExportShardDoesNotCreateBarrier() async throws {
        try await withRoot { root in
            let project = UUID()
            try writeShard(root: root, filename: project.uuidString + ".json", records: [record(project: project, path: "Exports/Batches/a/Vocals.m4a")])
            let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
            let prepared = try await guarder.prepareBarrierForCurrentCorruptExportShards()
            XCTAssertNil(prepared)
            let currentBarrier = try await guarder.barrier()
            XCTAssertNil(currentBarrier)
        }
    }

    func testCorruptAttributedShardCreatesBarrierBeforeShardMoves() async throws {
        try await withRoot { root in
            let project = UUID()
            let url = exportDirectory(root).appendingPathComponent(project.uuidString + ".json")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("{broken".utf8).write(to: url)

            let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
            let prepared = try await guarder.prepareBarrierForCurrentCorruptExportShards()
            let barrier = try XCTUnwrap(prepared)
            XCTAssertEqual(barrier.affectedProjectUUIDs, [project])
            XCTAssertFalse(barrier.hasUnattributedShard)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "barrier must exist before quarantine moves bytes")
            await XCTAssertThrowsErrorAsync { try await guarder.requireExportMetadataConsistent() }

            try FileManager.default.removeItem(at: url)
            let persisted = try await guarder.barrier()
            XCTAssertNotNil(persisted, "barrier must survive post-scan shard movement")
        }
    }

    func testMalformedShardFilenameProducesUnattributedBarrier() async throws {
        try await withRoot { root in
            let url = exportDirectory(root).appendingPathComponent("not-a-uuid.json")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("[]".utf8).write(to: url)
            let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
            let prepared = try await guarder.prepareBarrierForCurrentCorruptExportShards()
            let barrier = try XCTUnwrap(prepared)
            XCTAssertTrue(barrier.hasUnattributedShard)
            XCTAssertTrue(barrier.affectedProjectUUIDs.isEmpty)
        }
    }

    func testLegacyBarrierSurvivesV2Removal() async throws {
        try await withRoot { root in
            let v2 = root.appendingPathComponent(".LibraryLifecycle/v2", isDirectory: true)
            try FileManager.default.createDirectory(at: v2, withIntermediateDirectories: true)
            try Data("temp".utf8).write(to: v2.appendingPathComponent("temp.txt"))
            let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
            _ = try await guarder.prepareBarrierForLegacyCorruption()
            try FileManager.default.removeItem(at: v2)
            let current = try await guarder.barrier()
            XCTAssertTrue(try XCTUnwrap(current).hasUnattributedShard)
        }
    }

    func testResolutionRequiresAllAttributedProjectsAndExplicitUnattributedAck() async throws {
        let first = UUID(), second = UUID()
        let barrier = Lane2ExportMetadataQuarantineBarrier(
            corruptExportShardRelativePaths: ["one", "two"],
            affectedProjectUUIDs: [first, second],
            hasUnattributedShard: true
        )
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)

        await XCTAssertThrowsErrorAsync {
            try await guarder.validate(
                resolution: .init(acknowledgedEmptyProjectUUIDs: [first]),
                against: barrier
            )
        }
        await XCTAssertThrowsErrorAsync {
            try await guarder.validate(
                resolution: .init(acknowledgedEmptyProjectUUIDs: [first, second]),
                against: barrier
            )
        }
        try await guarder.validate(
            resolution: .init(
                acknowledgedEmptyProjectUUIDs: [first, second],
                acknowledgeUnattributedMetadataLoss: true
            ),
            against: barrier
        )
    }

    func testRecoveredArtifactsMustBeNonEmptyExportsFiles() async throws {
        try await withRoot { root in
            let project = UUID()
            let guarder = Lane2LifecycleQuarantineRecovery(rootURL: root)
            let ready = "Exports/Batches/x/Vocals.m4a"
            let readyURL = root.appendingPathComponent(ready)
            try FileManager.default.createDirectory(at: readyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("audio".utf8).write(to: readyURL)
            try await guarder.requireRecoveredArtifactsReady([
                .init(projectUUID: project, relativePath: ready, mediaType: "audio/mp4")
            ])
            await XCTAssertThrowsErrorAsync {
                try await guarder.requireRecoveredArtifactsReady([
                    .init(projectUUID: project, relativePath: "Imports/no.m4a", mediaType: "audio/mp4")
                ])
            }
        }
    }

    private func withRoot(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AW13-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(root)
    }

    private func exportDirectory(_ root: URL) -> URL {
        root.appendingPathComponent(".LibraryLifecycle/v2/exports", isDirectory: true)
    }

    private func writeShard(root: URL, filename: String, records: [Lane2ExportRecord]) throws {
        let url = exportDirectory(root).appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(records).write(to: url)
    }

    private func record(project: UUID, path: String) -> Lane2ExportRecord {
        Lane2ExportRecord(id: UUID(), projectUUID: project, relativePath: path, mediaType: "audio/mp4", createdAt: Date(), state: .ready)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
