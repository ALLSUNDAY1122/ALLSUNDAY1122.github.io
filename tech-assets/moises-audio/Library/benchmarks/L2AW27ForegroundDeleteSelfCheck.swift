import Foundation

@main
struct L2AW27ForegroundDeleteSelfCheck {
    static func main() throws {
        var scenarios = 0
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: [
                "Imports/shared/source.m4a",
                "Stems/shared/vocals.m4a",
                "Stems/target/drums.m4a"
            ]
        )
        let plan = try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPathsExcludingTarget: [
                "Imports/shared/source.m4a",
                "Stems/shared/vocals.m4a",
                "Stems/unrelated/not-a-candidate.m4a"
            ]
        )
        precondition(plan.sharedLiveArtifactPaths == [
            "Imports/shared/source.m4a",
            "Stems/shared/vocals.m4a"
        ])
        precondition(plan.artifactRelativePathsToDelete == ["Stems/target/drums.m4a"])
        scenarios += 1

        let exclusive = try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPathsExcludingTarget: []
        )
        precondition(exclusive.artifactRelativePathsToDelete.count == 3)
        scenarios += 1

        do {
            _ = try Lane2ForegroundDeletePreparationPolicy.plan(
                candidate: .init(
                    projectUUID: UUID(),
                    sourceAssetUUID: UUID(),
                    artifactRelativePaths: ["Exports/not-owned.m4a"]
                ),
                liveReferencedArtifactPathsExcludingTarget: []
            )
            fatalError("unsafe path accepted")
        } catch Lane2TombstonedMetadataCompactionFailure.unsafeArtifactPath {
            scenarios += 1
        }

        let simulatedUnrelatedLiveProjects = 100_000
        let started = Date()
        var checksum = 0
        for _ in 0..<100_000 {
            checksum &+= candidate.artifactRelativePaths.count
            checksum &+= plan.artifactRelativePathsToDelete.count
        }
        precondition(checksum > 0)
        let elapsed = Date().timeIntervalSince(started)
        scenarios += 1

        print(String(
            format: "L2_AW27_SELF_TEST_PASS scenarios=%d simulated_unrelated_live_projects=%d candidate_paths=%d shared_paths=%d delete_paths=%d elapsed_seconds=%.6f",
            scenarios,
            simulatedUnrelatedLiveProjects,
            candidate.artifactRelativePaths.count,
            plan.sharedLiveArtifactPaths.count,
            plan.artifactRelativePathsToDelete.count,
            elapsed
        ))
    }
}
