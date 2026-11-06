import Foundation

@main
struct L2AW22DeletionOwnershipIndexSelfCheck {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2AW22SelfCheck-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        var scenarios = 0

        let project = UUID()
        let source = UUID()
        let record = try Lane2DeletionOwnershipRecord(
            projectUUID: project,
            sourceAssetUUID: source,
            artifactRelativePaths: ["Imports/p/source.m4a", "Stems/p/vocals.m4a"]
        )
        try index.persist(record)
        let loadedRecord = try index.record(projectUUID: project)
        precondition(loadedRecord == record)
        scenarios += 1

        try index.persist(record)
        let firstPending = try index.pendingRecords()
        precondition(firstPending.count == 1)
        scenarios += 1

        do {
            try index.persist(try .init(
                projectUUID: project,
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Imports/p/source.m4a"]
            ))
            fatalError("identity conflict accepted")
        } catch Lane2DeletionOwnershipIndexFailure.identityConflict {
            scenarios += 1
        }

        do {
            _ = try Lane2DeletionOwnershipRecord(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Exports/p/leak.m4a"]
            )
            fatalError("unsafe root accepted")
        } catch Lane2TombstonedMetadataCompactionFailure.unsafeArtifactPath {
            scenarios += 1
        }

        let planned = try Lane2TombstonedMetadataCompactionPolicy.plan(
            candidate: record.compactionCandidate,
            liveReferencedArtifactPaths: ["Imports/p/source.m4a"]
        )
        precondition(planned.artifactRelativePathsToDelete == ["Stems/p/vocals.m4a"])
        precondition(planned.retainedLiveArtifactPaths == ["Imports/p/source.m4a"])
        scenarios += 1

        precondition(!index.isLegacyScanComplete)
        try index.markLegacyScanComplete()
        precondition(Lane2DeletionOwnershipIndex(rootURL: root).isLegacyScanComplete)
        scenarios += 1

        try index.remove(projectUUID: project)
        try index.remove(projectUUID: project)
        let emptyPending = try index.pendingRecords()
        precondition(emptyPending.isEmpty)
        scenarios += 1

        let bulkCount = 2_000
        let started = Date()
        for i in 0..<bulkCount {
            try index.persist(try Lane2DeletionOwnershipRecord(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                artifactRelativePaths: [
                    "Imports/\(i)/source.m4a",
                    "Stems/\(i)/vocals.m4a"
                ]
            ))
        }
        let loaded = try index.pendingRecords()
        precondition(loaded.count == bulkCount)
        precondition(Set(loaded.map(\.projectUUID)).count == bulkCount)
        let elapsed = Date().timeIntervalSince(started)
        scenarios += 1

        print(String(
            format: "L2_AW22_SELF_TEST_PASS scenarios=%d ownership_records=%d elapsed_seconds=%.6f",
            scenarios,
            bulkCount,
            elapsed
        ))
    }
}
