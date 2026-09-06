import Foundation

@main
enum L2AW12MaintenanceProjectionSelfCheck {
    static func main() throws {
        let policy = LibraryEnumerationPolicy(batchSize: 128)

        let shared = "Imports/shared/song.m4a"
        let firstID = ProjectID()
        let secondID = ProjectID()
        let first = try LibraryMaintenanceProject(
            projectID: firstID,
            sourceAssetID: AssetID(),
            sourceRelativePath: shared,
            stemRelativePaths: [
                "Stems/\(firstID.rawValue.uuidString)/vocals.m4a",
                "Stems/\(firstID.rawValue.uuidString)/vocals.m4a"
            ]
        )
        let second = try LibraryMaintenanceProject(
            projectID: secondID,
            sourceAssetID: AssetID(),
            sourceRelativePath: shared,
            stemRelativePaths: ["Stems/\(secondID.rawValue.uuidString)/drums.m4a"]
        )

        precondition(first.artifactRelativePaths.count == 2)
        let others = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(
            in: [first, second],
            excluding: firstID
        )
        precondition(others.contains(shared))
        precondition(!others.contains("Stems/\(firstID.rawValue.uuidString)/vocals.m4a"))

        for path in ["", "/absolute.m4a", "../escape.m4a", "Stems/../escape.m4a", "Stems//x.m4a"] {
            do {
                _ = try LibraryMaintenanceProject(
                    projectID: ProjectID(),
                    sourceAssetID: AssetID(),
                    sourceRelativePath: path,
                    stemRelativePaths: []
                )
                preconditionFailure("invalid path accepted")
            } catch LibraryMaintenanceProjectionFailure.invalidRelativePath {
                // expected
            }
        }

        do {
            _ = try LibraryMaintenanceProjectionPolicy.validateUniqueProjects([first, first])
            preconditionFailure("duplicate project accepted")
        } catch LibraryMaintenanceProjectionFailure.duplicateProject {
            // expected
        }

        precondition(policy.estimatedProjectFetchOperations(projectCount: 10_000) == 396)
        precondition(policy.estimatedMaintenanceFetchOperations(projectCount: 10_000) == 159)
        precondition(policy.estimatedMaintenanceFetchOperations(projectCount: 10_000) < 396)

        let started = Date()
        var projects: [LibraryMaintenanceProject] = []
        projects.reserveCapacity(25_000)
        for index in 0..<25_000 {
            let id = ProjectID()
            projects.append(
                try LibraryMaintenanceProject(
                    projectID: id,
                    sourceAssetID: AssetID(),
                    sourceRelativePath: "Imports/\(index)/source.m4a",
                    stemRelativePaths: [
                        "Stems/\(id.rawValue.uuidString)/vocals.m4a",
                        "Stems/\(id.rawValue.uuidString)/drums.m4a"
                    ]
                )
            )
        }
        let referenced = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(in: projects)
        precondition(referenced.count == 75_000)
        let elapsed = Date().timeIntervalSince(started)

        print(
            "L2_AW12_SELF_TEST_PASS scenarios=6 projects=25000 referenced=75000 " +
            "full_fetch_estimate=396 maintenance_fetch_estimate=159 elapsed_seconds=\(String(format: \"%.6f\", elapsed))"
        )
    }
}
