import Foundation

@main
struct L2AW30ManagedArtifactCompatibilityCensusSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "L2AW30-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        func write(_ relativePath: String, body: String) throws {
            let url = root.appendingPathComponent(relativePath)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(body.utf8).write(to: url)
            try fm.setAttributes([.modificationDate: fixedDate], ofItemAtPath: url.path)
        }

        for index in 0..<257 {
            let managedRoot = index.isMultiple(of: 5) ? "Exports" : (index.isMultiple(of: 3) ? "Stems" : "Imports")
            try write(
                "\(managedRoot)/artifact-\(String(format: "%04d", index)).m4a",
                body: "\(index)"
            )
        }

        var passes = 0
        var completedGenerations = 0
        var maximumRegistered = 0
        var firstGenerationComplete = false
        while !Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker,
              passes < 40 {
            // Recreate every pass to model process relaunch and prove state is on disk.
            let report = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
                registrationLimit: 32
            )
            maximumRegistered = max(maximumRegistered, report.registeredThisPass)
            if report.generationCompleted {
                completedGenerations += 1
                if !firstGenerationComplete {
                    firstGenerationComplete = true
                    // Mutation between generations must invalidate the first digest and require a
                    // later stable generation pair before authority.
                    try write("Imports/0000-added-between-generations.m4a", body: "mutation")
                }
            }
            passes += 1
        }

        precondition(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
        precondition(maximumRegistered <= 32)
        precondition(completedGenerations >= 3)

        let postAuthority = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 32
        )
        precondition(postAuthority.scannedRegularFiles == 0)
        precondition(postAuthority.registeredThisPass == 0)

        let symlinkRoot = fm.temporaryDirectory.appendingPathComponent(
            "L2AW30Symlink-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fm.removeItem(at: symlinkRoot) }
        try fm.createDirectory(at: symlinkRoot.appendingPathComponent("Imports"), withIntermediateDirectories: true)
        let outside = symlinkRoot.appendingPathComponent("outside.m4a")
        try Data("outside".utf8).write(to: outside)
        try fm.createSymbolicLink(
            at: symlinkRoot.appendingPathComponent("Imports/link.m4a"),
            withDestinationURL: outside
        )
        var symlinkFailedClosed = false
        do {
            _ = try Lane2ManagedArtifactCompatibilityCensus(rootURL: symlinkRoot).advance()
        } catch Lane2ManagedArtifactCensusFailure.symlinkEncountered {
            symlinkFailedClosed = true
        }
        precondition(symlinkFailedClosed)
        precondition(!Lane2ManagedArtifactInventory(rootURL: symlinkRoot).hasValidAuthoritativeMarker)

        print(
            "L2_AW30_SELF_TEST_PASS initial_files=257 mutation_files=1 passes=\(passes) completed_generations=\(completedGenerations) max_registered_per_pass=\(maximumRegistered) authority=true post_authority_scan=0 symlink_fail_closed=\(symlinkFailedClosed) raw_enumeration_portably_unbounded=true"
        )
    }
}
