import Foundation

private enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String { if case .failed(let value) = self { return value }; return "check failed" }
}

private func expect(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure.failed(message) }
}

private func makeRoot(_ name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("L2-AW08-\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func encodeLegacy(_ value: Lane2LifecycleSnapshot, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(value).write(to: url, options: [.atomic])
}

@main
struct L2AW08MetadataShardingSelfCheck {
    static func main() async throws {
        let fm = FileManager.default
        var roots: [URL] = []
        defer { for root in roots { try? fm.removeItem(at: root) } }

        // 1) Legacy v1 -> v2 migration preserves all records and leaves the legacy source intact.
        let migrationRoot = try makeRoot("migration"); roots.append(migrationRoot)
        let project = UUID(), asset = UUID(), exportID = UUID(), attempt = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = Lane2LifecycleSnapshot(
            projects: [Lane2ProjectOwnershipRecord(projectUUID: project, sourceAssetUUID: asset, sourceRelativePath: "Imports/song.m4a", updatedAt: fixedDate)],
            exports: [Lane2ExportRecord(id: exportID, projectUUID: project, relativePath: "Exports/mix.m4a", mediaType: "audio/mp4", createdAt: fixedDate, state: .ready)],
            failures: [Lane2FailureRecord(attemptUUID: attempt, projectUUID: project, operation: .exportAudio, stableCode: "EXPORT_INTERRUPTED", retryable: true, createdAt: fixedDate)]
        )
        let legacyURL = migrationRoot.appendingPathComponent(".LibraryLifecycle/lane2-lifecycle-v1.json")
        try encodeLegacy(legacy, to: legacyURL)
        let migratedStore = Lane2LifecycleMetadataStore(rootURL: migrationRoot)
        let migrated = try await migratedStore.snapshot()
        try expect(migrated.projects.count == 1 && migrated.projects[0].sourceAssetUUID == asset, "migration lost project ownership")
        try expect(migrated.exports.map(\.id) == [exportID], "migration lost export")
        try expect(migrated.failures.map(\.attemptUUID) == [attempt], "migration lost failure")
        try expect(fm.fileExists(atPath: legacyURL.path), "migration removed legacy document")
        try expect(fm.fileExists(atPath: migrationRoot.appendingPathComponent(".LibraryLifecycle/v2/schema.json").path), "v2 marker missing")

        // 2) Single-project mutation is shard-local: unrelated project bytes stay unchanged.
        let shardRoot = try makeRoot("shard-local"); roots.append(shardRoot)
        let shardStore = Lane2LifecycleMetadataStore(rootURL: shardRoot)
        let p1 = UUID(), p2 = UUID(), a1 = UUID(), a2 = UUID()
        try await shardStore.upsertProjectOwnership(projectUUID: p1, sourceAssetUUID: a1, sourceRelativePath: "Imports/a.m4a", now: fixedDate)
        try await shardStore.upsertProjectOwnership(projectUUID: p2, sourceAssetUUID: a2, sourceRelativePath: "Imports/b.m4a", now: fixedDate)
        let p2URL = shardRoot.appendingPathComponent(".LibraryLifecycle/v2/projects/\(p2.uuidString).json")
        let p2Before = try Data(contentsOf: p2URL)
        try await shardStore.upsertProjectOwnership(projectUUID: p1, sourceAssetUUID: UUID(), sourceRelativePath: "Imports/a2.m4a", now: fixedDate.addingTimeInterval(1))
        let p2After = try Data(contentsOf: p2URL)
        try expect(p2Before == p2After, "unrelated project shard was rewritten")

        // 3) Corrupt one shard: normal read fails closed, explicit quarantine preserves bad bytes,
        // and valid metadata remains readable.
        let corruptURL = shardRoot.appendingPathComponent(".LibraryLifecycle/v2/projects/\(p1.uuidString).json")
        let badBytes = Data("{corrupt-shard".utf8)
        try badBytes.write(to: corruptURL, options: [.atomic])
        do {
            _ = try await shardStore.snapshot()
            throw CheckFailure.failed("corrupt shard did not fail closed")
        } catch Lane2LifecycleMetadataFailure.corruptShard { }
        let report = try await shardStore.quarantineCorruptShards()
        try expect(report.quarantinedRelativePaths.count == 1, "expected exactly one quarantined shard")
        let quarantinedURL = shardRoot.appendingPathComponent(report.quarantinedRelativePaths[0])
        let quarantinedBytes = try Data(contentsOf: quarantinedURL)
        try expect(quarantinedBytes == badBytes, "quarantine did not preserve raw corrupt bytes")
        let afterQuarantine = try await shardStore.snapshot()
        try expect(afterQuarantine.projects.count == 1 && afterQuarantine.projects[0].projectUUID == p2, "valid shard did not survive quarantine")

        // 4) Corrupt legacy remains fail-closed until explicit preservation, then v2 can rebuild empty.
        let legacyCorruptRoot = try makeRoot("legacy-corrupt"); roots.append(legacyCorruptRoot)
        let corruptLegacyURL = legacyCorruptRoot.appendingPathComponent(".LibraryLifecycle/lane2-lifecycle-v1.json")
        try fm.createDirectory(at: corruptLegacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corruptLegacyBytes = Data("not-json".utf8)
        try corruptLegacyBytes.write(to: corruptLegacyURL)
        let legacyCorruptStore = Lane2LifecycleMetadataStore(rootURL: legacyCorruptRoot)
        do {
            _ = try await legacyCorruptStore.snapshot()
            throw CheckFailure.failed("corrupt legacy did not fail closed")
        } catch Lane2LifecycleMetadataFailure.corruptDocument { }
        let preserved = try await legacyCorruptStore.quarantineCorruptLegacyDocument()
        try expect(preserved != nil, "corrupt legacy was not quarantined")
        let preservedURL = legacyCorruptRoot.appendingPathComponent(preserved!)
        let preservedBytes = try Data(contentsOf: preservedURL)
        try expect(preservedBytes == corruptLegacyBytes, "legacy quarantine bytes changed")
        let rebuilt = try await legacyCorruptStore.snapshot()
        try expect(rebuilt.projects.isEmpty && rebuilt.exports.isEmpty, "explicit legacy recovery did not initialize empty v2")

        // 5) Export deleting state survives reopen and can converge idempotently.
        let cleanupRoot = try makeRoot("cleanup"); roots.append(cleanupRoot)
        let cleanupStore = Lane2LifecycleMetadataStore(rootURL: cleanupRoot)
        let cleanupProject = UUID()
        let records = try await cleanupStore.recordExports(projectUUID: cleanupProject, artifacts: [("Exports/one.m4a", "audio/mp4"), ("Exports/two.m4a", "audio/mp4")], now: fixedDate)
        try expect(records.count == 2, "export record batch mismatch")
        let deleting = try await cleanupStore.beginExportCleanup(projectUUID: cleanupProject)
        try expect(deleting.allSatisfy { $0.state == .deleting }, "cleanup state not persisted")
        let reopened = Lane2LifecycleMetadataStore(rootURL: cleanupRoot)
        let pendingAfterReopen = try await reopened.pendingExportCleanup()
        try expect(pendingAfterReopen.count == 2, "reopen lost pending cleanup")
        for record in deleting { try await reopened.finishExportCleanup(exportID: record.id) }
        let pendingAfterCleanup = try await reopened.pendingExportCleanup()
        try expect(pendingAfterCleanup.isEmpty, "cleanup did not converge")

        // 6) Failure history remains bounded even with repeated durable writes.
        for index in 0..<80 {
            try await reopened.recordFailure(
                Lane2FailureRecord(
                    attemptUUID: UUID(), projectUUID: cleanupProject, operation: .storagePreflight,
                    stableCode: "F\(index)", retryable: true, createdAt: fixedDate.addingTimeInterval(Double(index))
                )
            )
        }
        let failureSnapshot = try await reopened.snapshot()
        try expect(failureSnapshot.failures.count == 64, "failure history bound violated")
        try expect(failureSnapshot.failures.first?.stableCode == "F16" && failureSnapshot.failures.last?.stableCode == "F79", "failure history ordering violated")

        // 7) Large-library write/read benchmark. This is filesystem metadata evidence only.
        let benchmarkRoot = try makeRoot("benchmark"); roots.append(benchmarkRoot)
        let benchmarkStore = Lane2LifecycleMetadataStore(rootURL: benchmarkRoot)
        let count = 2_000
        let startWrite = Date()
        var benchmarkProjects: [UUID] = []
        benchmarkProjects.reserveCapacity(count)
        for index in 0..<count {
            let id = UUID(); benchmarkProjects.append(id)
            try await benchmarkStore.upsertProjectOwnership(
                projectUUID: id,
                sourceAssetUUID: UUID(),
                sourceRelativePath: "Imports/track-\(index).m4a",
                now: fixedDate
            )
        }
        let writeSeconds = Date().timeIntervalSince(startWrite)
        let updateTarget = benchmarkProjects[count / 2]
        let unrelated = benchmarkProjects[count / 2 + 1]
        let unrelatedURL = benchmarkRoot.appendingPathComponent(".LibraryLifecycle/v2/projects/\(unrelated.uuidString).json")
        let unrelatedBefore = try Data(contentsOf: unrelatedURL)
        let startUpdate = Date()
        try await benchmarkStore.upsertProjectOwnership(
            projectUUID: updateTarget,
            sourceAssetUUID: UUID(),
            sourceRelativePath: "Imports/updated.m4a",
            now: fixedDate.addingTimeInterval(2)
        )
        let updateSeconds = Date().timeIntervalSince(startUpdate)
        let unrelatedAfter = try Data(contentsOf: unrelatedURL)
        try expect(unrelatedAfter == unrelatedBefore, "large-library update rewrote unrelated shard")
        let startSnapshot = Date()
        let benchmarkSnapshot = try await benchmarkStore.snapshot()
        let snapshotSeconds = Date().timeIntervalSince(startSnapshot)
        try expect(benchmarkSnapshot.projects.count == count, "large-library snapshot count mismatch")

        // 8) Traversal remains rejected under v2.
        do {
            try await benchmarkStore.upsertProjectOwnership(projectUUID: UUID(), sourceAssetUUID: UUID(), sourceRelativePath: "../escape.m4a")
            throw CheckFailure.failed("traversal was accepted")
        } catch Lane2LifecycleMetadataFailure.invalidRelativePath { }

        print("L2_AW08_SELF_TEST_PASS scenarios=8 projects=\(count) write_s=\(String(format: "%.6f", writeSeconds)) single_update_s=\(String(format: "%.6f", updateSeconds)) snapshot_s=\(String(format: "%.6f", snapshotSeconds))")
    }
}
