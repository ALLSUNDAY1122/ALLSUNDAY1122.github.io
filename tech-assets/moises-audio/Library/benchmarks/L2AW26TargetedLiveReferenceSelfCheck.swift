import Foundation

@main
struct L2AW26TargetedLiveReferenceSelfCheck {
    static func main() throws {
        var scenarios = 0
        let simulatedLiveProjects = 100_000
        var candidatePaths = Set<String>()
        for index in 0..<64 {
            candidatePaths.insert("Imports/\(index)/source.m4a")
            candidatePaths.insert("Stems/\(index)/vocals.m4a")
            candidatePaths.insert("Stems/\(index)/drums.m4a")
        }
        let plan = try Lane2TargetedLiveReferenceQueryPolicy.plan(
            candidateArtifactPaths: candidatePaths,
            batchSize: 128
        )
        precondition(plan.requestedArtifactPathCount == 192)
        precondition(plan.sourceArtifactPaths.count == 64)
        precondition(plan.stemArtifactPaths.count == 128)
        precondition(plan.sourceBatchCount == 1)
        precondition(plan.stemBatchCount == 1)
        scenarios += 1

        do {
            _ = try Lane2TargetedLiveReferenceQueryPolicy.plan(
                candidateArtifactPaths: ["Exports/not-owned.m4a"]
            )
            fatalError("unsafe path accepted")
        } catch Lane2TargetedLiveReferenceFailure.unsafeArtifactPath {
            scenarios += 1
        }

        let first = Lane2TargetedLiveReferenceDiagnostics(
            usedTargetedStoreQuery: true,
            requestedProjectIDs: 64,
            requestedArtifactPaths: 192,
            sourceArtifactPaths: 64,
            stemArtifactPaths: 128,
            liveProjectIDsMatched: 3,
            liveArtifactPathsMatched: 5,
            logicalFetchCalls: 5
        )
        let second = Lane2TargetedLiveReferenceDiagnostics(
            usedTargetedStoreQuery: true,
            requestedProjectIDs: 0,
            requestedArtifactPaths: 8,
            sourceArtifactPaths: 4,
            stemArtifactPaths: 4,
            liveProjectIDsMatched: 0,
            liveArtifactPathsMatched: 2,
            logicalFetchCalls: 4
        )
        let merged = first.merged(with: second)
        precondition(merged.requestedArtifactPaths == 200)
        precondition(merged.liveArtifactPathsMatched == 7)
        precondition(merged.logicalFetchCalls == 9)
        scenarios += 1

        let started = Date()
        var checksum = 0
        for _ in 0..<10_000 {
            checksum &+= plan.requestedArtifactPathCount
            checksum &+= plan.sourceBatchCount + plan.stemBatchCount
        }
        precondition(checksum > 0)
        let elapsed = Date().timeIntervalSince(started)
        scenarios += 1

        print(String(
            format: "L2_AW26_SELF_TEST_PASS scenarios=%d simulated_live_projects=%d candidate_paths=%d source_paths=%d stem_paths=%d batch_size=%d elapsed_seconds=%.6f",
            scenarios,
            simulatedLiveProjects,
            plan.requestedArtifactPathCount,
            plan.sourceArtifactPaths.count,
            plan.stemArtifactPaths.count,
            plan.batchSize,
            elapsed
        ))
    }
}
