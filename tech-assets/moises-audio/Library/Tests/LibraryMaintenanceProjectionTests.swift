import Foundation
import XCTest

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class LibraryMaintenanceProjectionTests: XCTestCase {
    func testArtifactPathsDeduplicateWithinProjectAndExcludeTargetFromReferenceSet() throws {
        let shared = "Imports/shared/song.m4a"
        let first = ProjectID()
        let second = ProjectID()
        let a = try LibraryMaintenanceProject(
            projectID: first,
            sourceAssetID: AssetID(),
            sourceRelativePath: shared,
            stemRelativePaths: [
                "Stems/\(first.rawValue.uuidString)/vocals.m4a",
                "Stems/\(first.rawValue.uuidString)/vocals.m4a"
            ]
        )
        let b = try LibraryMaintenanceProject(
            projectID: second,
            sourceAssetID: AssetID(),
            sourceRelativePath: shared,
            stemRelativePaths: ["Stems/\(second.rawValue.uuidString)/drums.m4a"]
        )

        XCTAssertEqual(a.artifactRelativePaths.count, 2)
        let others = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(
            in: [a, b],
            excluding: first
        )
        XCTAssertTrue(others.contains(shared))
        XCTAssertFalse(others.contains("Stems/\(first.rawValue.uuidString)/vocals.m4a"))
    }

    func testInvalidPathsFailClosed() {
        let badPaths = ["", "/absolute.m4a", "../escape.m4a", "Stems/../escape.m4a", "Stems//x.m4a"]
        for path in badPaths {
            XCTAssertThrowsError(
                try LibraryMaintenanceProject(
                    projectID: ProjectID(),
                    sourceAssetID: AssetID(),
                    sourceRelativePath: path,
                    stemRelativePaths: []
                )
            )
        }
    }

    func testDuplicateProjectIDsFailClosed() throws {
        let id = ProjectID()
        let first = try LibraryMaintenanceProject(
            projectID: id,
            sourceAssetID: AssetID(),
            sourceRelativePath: "Imports/a.m4a",
            stemRelativePaths: []
        )
        let second = try LibraryMaintenanceProject(
            projectID: id,
            sourceAssetID: AssetID(),
            sourceRelativePath: "Imports/b.m4a",
            stemRelativePaths: []
        )
        XCTAssertThrowsError(
            try LibraryMaintenanceProjectionPolicy.validateUniqueProjects([first, second])
        )
    }

    func testMaintenanceQueryShapeIsSmallerThanFullSnapshotShape() {
        let policy = LibraryEnumerationPolicy(batchSize: 128)
        XCTAssertEqual(policy.estimatedProjectFetchOperations(projectCount: 10_000), 396)
        XCTAssertEqual(policy.estimatedMaintenanceFetchOperations(projectCount: 10_000), 159)
        XCTAssertLessThan(
            policy.estimatedMaintenanceFetchOperations(projectCount: 10_000),
            policy.estimatedProjectFetchOperations(projectCount: 10_000)
        )
    }
}
