import Foundation
import XCTest

final class Lane2ForegroundDeletePreparationTests: XCTestCase {
    func testSharedSourceAndStemAreRetainedWhileExclusiveStemDeletes() throws {
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
                "Stems/shared/vocals.m4a"
            ]
        )
        XCTAssertEqual(plan.sharedLiveArtifactPaths, [
            "Imports/shared/source.m4a",
            "Stems/shared/vocals.m4a"
        ])
        XCTAssertEqual(plan.artifactRelativePathsToDelete, ["Stems/target/drums.m4a"])
    }

    func testUnrelatedLivePathDoesNotRetainCandidate() throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Imports/target/source.m4a"]
        )
        let plan = try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPathsExcludingTarget: ["Imports/unrelated/source.m4a"]
        )
        XCTAssertTrue(plan.sharedLiveArtifactPaths.isEmpty)
        XCTAssertEqual(plan.artifactRelativePathsToDelete, ["Imports/target/source.m4a"])
    }

    func testUnsafeCandidatePathFailsClosed() {
        XCTAssertThrowsError(try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: .init(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["../outside.m4a"]
            ),
            liveReferencedArtifactPathsExcludingTarget: []
        ))
        XCTAssertThrowsError(try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: .init(
                projectUUID: UUID(),
                sourceAssetUUID: UUID(),
                artifactRelativePaths: ["Exports/not-delete-owned.m4a"]
            ),
            liveReferencedArtifactPathsExcludingTarget: []
        ))
    }

    func testCandidateDeduplicatesPathsBeforePlanning() throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: [
                "Imports/target/source.m4a",
                "Imports/target/source.m4a",
                "Stems/target/vocals.m4a"
            ]
        )
        let plan = try Lane2ForegroundDeletePreparationPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPathsExcludingTarget: []
        )
        XCTAssertEqual(plan.artifactRelativePathsToDelete.count, 2)
    }
}
