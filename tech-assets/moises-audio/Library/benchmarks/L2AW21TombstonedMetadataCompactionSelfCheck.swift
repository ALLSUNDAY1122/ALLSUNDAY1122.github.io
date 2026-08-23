import Foundation

private actor GateProbe {
    private var active = 0
    private var peak = 0

    func enter() {
        active += 1
        peak = max(peak, active)
    }

    func leave() {
        active -= 1
    }

    func peakValue() -> Int { peak }
}

@main
struct L2AW21TombstonedMetadataCompactionSelfCheck {
    static func main() async throws {
        var scenarios = 0

        let project = UUID()
        let asset = UUID()
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: project,
            sourceAssetUUID: asset,
            artifactRelativePaths: [
                "Imports/shared/source.m4a",
                "Stems/\(project.uuidString)/vocals.m4a"
            ]
        )

        let plan = try Lane2TombstonedMetadataCompactionPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPaths: ["Imports/shared/source.m4a"]
        )
        precondition(plan.artifactRelativePathsToDelete == ["Stems/\(project.uuidString)/vocals.m4a"])
        precondition(plan.retainedLiveArtifactPaths == ["Imports/shared/source.m4a"])
        scenarios += 1

        try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
            relativePaths: ["Stems/\(project.uuidString)/vocals.m4a"],
            candidate: candidate,
            liveReferencedArtifactPaths: ["Imports/shared/source.m4a"]
        )
        scenarios += 1

        do {
            try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                relativePaths: ["Imports/other/source.m4a"],
                candidate: candidate,
                liveReferencedArtifactPaths: []
            )
            fatalError("unowned journal path accepted")
        } catch Lane2TombstonedMetadataCompactionFailure.journalArtifactNotOwnedByProject {
            scenarios += 1
        }

        do {
            try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                relativePaths: ["Imports/shared/source.m4a"],
                candidate: candidate,
                liveReferencedArtifactPaths: ["Imports/shared/source.m4a"]
            )
            fatalError("live path accepted for deletion")
        } catch Lane2TombstonedMetadataCompactionFailure.journalTargetsLiveArtifact {
            scenarios += 1
        }

        for unsafe in ["Exports/leak.m4a", "Staging/file.part", "../outside", "Imports/../outside"] {
            do {
                _ = try Lane2TombstonedMetadataCompactionPolicy.plan(
                    candidate: .init(projectUUID: UUID(), sourceAssetUUID: UUID(), artifactRelativePaths: [unsafe]),
                    liveReferencedArtifactPaths: []
                )
                fatalError("unsafe path accepted: \(unsafe)")
            } catch Lane2TombstonedMetadataCompactionFailure.unsafeArtifactPath {
                continue
            }
        }
        scenarios += 1

        precondition(
            !Lane2TombstonedMetadataCompactionPolicy.shouldRemoveSourceAsset(
                sourceAssetUUID: asset,
                remainingProjectSourceAssetUUIDs: [asset]
            )
        )
        precondition(
            Lane2TombstonedMetadataCompactionPolicy.shouldRemoveSourceAsset(
                sourceAssetUUID: asset,
                remainingProjectSourceAssetUUIDs: []
            )
        )
        scenarios += 1

        do {
            try Lane2TombstonedMetadataCompactionPolicy.requireUniqueProjects([candidate, candidate])
            fatalError("duplicate project identity accepted")
        } catch Lane2TombstonedMetadataCompactionFailure.duplicateProjectIdentity {
            scenarios += 1
        }

        let count = 50_000
        let start = Date()
        var totalPaths = 0
        for index in 0..<count {
            let p = UUID()
            let c = Lane2TombstonedProjectCompactionCandidate(
                projectUUID: p,
                sourceAssetUUID: UUID(),
                artifactRelativePaths: [
                    "Imports/\(index)/source.m4a",
                    "Stems/\(index)/vocals.m4a"
                ]
            )
            let result = try Lane2TombstonedMetadataCompactionPolicy.plan(
                candidate: c,
                liveReferencedArtifactPaths: index.isMultiple(of: 10) ? ["Imports/\(index)/source.m4a"] : []
            )
            totalPaths += result.artifactRelativePathsToDelete.count + result.retainedLiveArtifactPaths.count
        }
        precondition(totalPaths == count * 2)
        let elapsed = Date().timeIntervalSince(start)
        scenarios += 1

        let gate = Lane2LibraryMutationGate()
        let probe = GateProbe()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    await gate.lock()
                    await probe.enter()
                    try? await Task.sleep(for: .milliseconds(1))
                    await probe.leave()
                    await gate.unlock()
                }
            }
        }
        let peak = await probe.peakValue()
        precondition(peak == 1)
        scenarios += 1

        print(String(
            format: "L2_AW21_SELF_TEST_PASS scenarios=%d projects=%d artifact_paths=%d gate_tasks=200 gate_peak=%d elapsed_seconds=%.6f",
            scenarios,
            count,
            totalPaths,
            peak,
            elapsed
        ))
    }
}
