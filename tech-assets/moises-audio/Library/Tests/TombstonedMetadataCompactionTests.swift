import Foundation
import XCTest

final class TombstonedMetadataCompactionTests: XCTestCase {
    func testPlanRetainsLiveSharedPaths() throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Imports/shared/source.m4a", "Stems/dead/vocals.m4a"]
        )
        let plan = try Lane2TombstonedMetadataCompactionPolicy.plan(
            candidate: candidate,
            liveReferencedArtifactPaths: ["Imports/shared/source.m4a"]
        )
        XCTAssertEqual(plan.artifactRelativePathsToDelete, ["Stems/dead/vocals.m4a"])
        XCTAssertEqual(plan.retainedLiveArtifactPaths, ["Imports/shared/source.m4a"])
    }

    func testUnsafeRootsAndTraversalAreRejected() throws {
        for path in ["Exports/leak.m4a", "../outside", "Staging/file.part", "Imports/../outside"] {
            let candidate = Lane2TombstonedProjectCompactionCandidate(
                projectUUID: UUID(), sourceAssetUUID: UUID(), artifactRelativePaths: [path]
            )
            XCTAssertThrowsError(
                try Lane2TombstonedMetadataCompactionPolicy.plan(
                    candidate: candidate,
                    liveReferencedArtifactPaths: []
                )
            )
        }
    }

    func testJournalCannotTargetPathNotOwnedByTombstone() throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Imports/dead/source.m4a"]
        )
        XCTAssertThrowsError(
            try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                relativePaths: ["Imports/other/source.m4a"],
                candidate: candidate,
                liveReferencedArtifactPaths: []
            )
        ) { error in
            XCTAssertEqual(
                error as? Lane2TombstonedMetadataCompactionFailure,
                .journalArtifactNotOwnedByProject("Imports/other/source.m4a")
            )
        }
    }

    func testJournalCannotDeleteLiveReferencedPath() throws {
        let candidate = Lane2TombstonedProjectCompactionCandidate(
            projectUUID: UUID(),
            sourceAssetUUID: UUID(),
            artifactRelativePaths: ["Imports/shared/source.m4a"]
        )
        XCTAssertThrowsError(
            try Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(
                relativePaths: ["Imports/shared/source.m4a"],
                candidate: candidate,
                liveReferencedArtifactPaths: ["Imports/shared/source.m4a"]
            )
        ) { error in
            XCTAssertEqual(
                error as? Lane2TombstonedMetadataCompactionFailure,
                .journalTargetsLiveArtifact("Imports/shared/source.m4a")
            )
        }
    }

    func testSharedAssetRetentionRequiresNoRemainingProjectReference() {
        let asset = UUID()
        XCTAssertFalse(
            Lane2TombstonedMetadataCompactionPolicy.shouldRemoveSourceAsset(
                sourceAssetUUID: asset,
                remainingProjectSourceAssetUUIDs: [asset]
            )
        )
        XCTAssertTrue(
            Lane2TombstonedMetadataCompactionPolicy.shouldRemoveSourceAsset(
                sourceAssetUUID: asset,
                remainingProjectSourceAssetUUIDs: []
            )
        )
    }

    func testDuplicateCandidateIdentityFailsClosed() throws {
        let id = UUID()
        let candidates = [
            Lane2TombstonedProjectCompactionCandidate(projectUUID: id, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/a/source.m4a"]),
            Lane2TombstonedProjectCompactionCandidate(projectUUID: id, sourceAssetUUID: UUID(), artifactRelativePaths: ["Imports/b/source.m4a"])
        ]
        XCTAssertThrowsError(try Lane2TombstonedMetadataCompactionPolicy.requireUniqueProjects(candidates)) { error in
            XCTAssertEqual(error as? Lane2TombstonedMetadataCompactionFailure, .duplicateProjectIdentity(id))
        }
    }
}
