import Foundation

@main
struct L2AW23LegacyTombstoneProjectionSelfCheck {
    static func main() throws {
        var scenarios = 0
        let sharedAsset = UUID()
        let first = UUID()
        let second = UUID()
        let batch = try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
            projects: [
                .init(projectUUID: first, sourceAssetUUID: sharedAsset),
                .init(projectUUID: second, sourceAssetUUID: sharedAsset)
            ],
            assets: [.init(assetUUID: sharedAsset, relativePath: "Imports/shared/source.m4a")],
            stems: [
                .init(projectUUID: first, relativePath: "Stems/first/vocals.m4a"),
                .init(projectUUID: second, relativePath: "Stems/second/vocals.m4a")
            ]
        )
        precondition(batch.count == 2)
        precondition(batch[0].artifactRelativePaths.contains("Imports/shared/source.m4a"))
        precondition(batch[1].artifactRelativePaths.contains("Imports/shared/source.m4a"))
        scenarios += 1

        do {
            _ = try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
                projects: [.init(projectUUID: UUID(), sourceAssetUUID: UUID())],
                assets: [],
                stems: []
            )
            fatalError("missing asset accepted")
        } catch Lane2TombstonedMetadataCompactionFailure.missingSourceAsset {
            scenarios += 1
        }

        let duplicateAsset = UUID()
        do {
            _ = try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
                projects: [],
                assets: [
                    .init(assetUUID: duplicateAsset, relativePath: "Imports/a/source.m4a"),
                    .init(assetUUID: duplicateAsset, relativePath: "Imports/b/source.m4a")
                ],
                stems: []
            )
            fatalError("duplicate asset accepted")
        } catch Lane2LegacyTombstoneProjectionFailure.duplicateAssetIdentity {
            scenarios += 1
        }

        let count = 100_000
        let policy = LibraryEnumerationPolicy(batchSize: 128)
        let metrics = Lane2LegacyTombstoneProjectionPolicy.metrics(
            projectCount: count,
            enumerationPolicy: policy
        )
        precondition(metrics.batchCount == 782)
        precondition(metrics.totalLogicalFetchCalls == 1_565)
        precondition(Lane2LegacyTombstoneProjectionPolicy.legacyNPlusOneFetchUpperBound(projectCount: count) == 200_001)
        scenarios += 1

        let start = Date()
        var candidateCount = 0
        for range in policy.ranges(forCount: count) {
            var projects: [Lane2LegacyTombstoneProjectRow] = []
            var assets: [Lane2LegacyTombstoneAssetRow] = []
            var stems: [Lane2LegacyTombstoneStemRow] = []
            projects.reserveCapacity(range.count)
            assets.reserveCapacity(range.count)
            stems.reserveCapacity(range.count * 2)
            for index in range {
                let project = UUID()
                let asset = UUID()
                projects.append(.init(projectUUID: project, sourceAssetUUID: asset))
                assets.append(.init(assetUUID: asset, relativePath: "Imports/\(index)/source.m4a"))
                stems.append(.init(projectUUID: project, relativePath: "Stems/\(index)/vocals.m4a"))
                stems.append(.init(projectUUID: project, relativePath: "Stems/\(index)/drums.m4a"))
            }
            candidateCount += try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
                projects: projects,
                assets: assets,
                stems: stems
            ).count
        }
        precondition(candidateCount == count)
        let elapsed = Date().timeIntervalSince(start)
        scenarios += 1

        print(String(
            format: "L2_AW23_SELF_TEST_PASS scenarios=%d projects=%d batch_size=%d logical_fetch_upper_bound=%d legacy_n_plus_one=%d elapsed_seconds=%.6f",
            scenarios,
            count,
            policy.batchSize,
            metrics.totalLogicalFetchCalls,
            Lane2LegacyTombstoneProjectionPolicy.legacyNPlusOneFetchUpperBound(projectCount: count),
            elapsed
        ))
    }
}
