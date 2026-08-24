import Foundation

@main
struct L2AW24LegacyRecoverySliceSelfCheck {
    static func main() throws {
        var scenarios = 0
        let budget = Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 64)
        precondition(budget.projectsPerLaunch == 64)
        precondition(budget.selectedCount(available: 65) == 64)
        precondition(budget.hasMore(availableWithSentinel: 65))
        precondition(!budget.hasMore(availableWithSentinel: 64))
        scenarios += 1

        precondition(Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 0).projectsPerLaunch == 8)
        precondition(Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 10_000).projectsPerLaunch == 256)
        scenarios += 1

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2AW24SelfCheck-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = Lane2LegacyRecoverySliceState(rootURL: root)
        precondition(!state.isActive)
        try state.activate()
        precondition(Lane2LegacyRecoverySliceState(rootURL: root).isActive)
        scenarios += 1
        try state.finish()
        try state.finish()
        precondition(!state.isActive)
        scenarios += 1

        let projects = 100_000
        precondition(budget.launchCount(forProjectCount: projects) == 1_563)
        precondition(budget.logicalFetchUpperBoundPerLaunch == 3)
        let oldRootMaterialization = projects
        let boundedRootMaterialization = budget.projectsPerLaunch + 1
        precondition(boundedRootMaterialization == 65)
        scenarios += 1

        let started = Date()
        var processed = 0
        var launches = 0
        while processed < projects {
            let remaining = projects - processed
            let selected = budget.selectedCount(available: remaining)
            precondition(selected > 0 && selected <= 64)
            processed += selected
            launches += 1
        }
        precondition(processed == projects)
        precondition(launches == 1_563)
        let elapsed = Date().timeIntervalSince(started)
        scenarios += 1

        print(String(
            format: "L2_AW24_SELF_TEST_PASS scenarios=%d projects=%d budget=%d launches=%d root_rows_per_launch=%d logical_fetch_upper_bound_per_launch=%d old_root_rows=%d elapsed_seconds=%.6f",
            scenarios,
            projects,
            budget.projectsPerLaunch,
            launches,
            boundedRootMaterialization,
            budget.logicalFetchUpperBoundPerLaunch,
            oldRootMaterialization,
            elapsed
        ))
    }
}
