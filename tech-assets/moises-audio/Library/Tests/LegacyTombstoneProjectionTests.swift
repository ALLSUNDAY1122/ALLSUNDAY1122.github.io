import Foundation
import XCTest

final class Lane2LegacyTombstoneProjectionTests: XCTestCase {
    func testMaterializesSharedAssetAndStemPathsWithoutPerProjectLookupSemantics() throws {
        let sharedAsset = UUID()
        let first = UUID()
        let second = UUID()
        let rows = [
            Lane2LegacyTombstoneProjectRow(projectUUID: first, sourceAssetUUID: sharedAsset),
            Lane2LegacyTombstoneProjectRow(projectUUID: second, sourceAssetUUID: sharedAsset)
        ]
        let candidates = try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
            projects: rows,
            assets: [.init(assetUUID: sharedAsset, relativePath: "Imports/shared/source.m4a")],
            stems: [
                .init(projectUUID: first, relativePath: "Stems/first/vocals.m4a"),
                .init(projectUUID: first, relativePath: "Stems/first/drums.m4a"),
                .init(projectUUID: second, relativePath: "Stems/second/vocals.m4a")
            ]
        )
        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates[0].sourceAssetUUID, sharedAsset)
        XCTAssertEqual(candidates[0].artifactRelativePaths, [
            "Imports/shared/source.m4a",
            "Stems/first/drums.m4a",
            "Stems/first/vocals.m4a"
        ])
        XCTAssertEqual(candidates[1].artifactRelativePaths, [
            "Imports/shared/source.m4a",
            "Stems/second/vocals.m4a"
        ])
    }

    func testMissingAssetFailsClosed() {
        XCTAssertThrowsError(try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
            projects: [.init(projectUUID: UUID(), sourceAssetUUID: UUID())],
            assets: [],
            stems: []
        ))
    }

    func testDuplicateAssetIdentityFailsClosed() {
        let asset = UUID()
        XCTAssertThrowsError(try Lane2LegacyTombstoneProjectionPolicy.materializeBatch(
            projects: [],
            assets: [
                .init(assetUUID: asset, relativePath: "Imports/a/source.m4a"),
                .init(assetUUID: asset, relativePath: "Imports/b/source.m4a")
            ],
            stems: []
        ))
    }

    func testMetricsCollapseNPlusOneToBatchBoundedFetchCalls() {
        let policy = LibraryEnumerationPolicy(batchSize: 128)
        let metrics = Lane2LegacyTombstoneProjectionPolicy.metrics(
            projectCount: 10_000,
            enumerationPolicy: policy
        )
        XCTAssertEqual(metrics.batchCount, 79)
        XCTAssertEqual(metrics.totalLogicalFetchCalls, 159)
        XCTAssertEqual(
            Lane2LegacyTombstoneProjectionPolicy.legacyNPlusOneFetchUpperBound(projectCount: 10_000),
            20_001
        )
        XCTAssertLessThan(metrics.totalLogicalFetchCalls, 200)
    }

    func testEmptyProjectionStillHasOneRootFetchAndNoRelatedFetches() {
        let metrics = Lane2LegacyTombstoneProjectionPolicy.metrics(
            projectCount: 0,
            enumerationPolicy: LibraryEnumerationPolicy()
        )
        XCTAssertEqual(metrics.totalLogicalFetchCalls, 1)
        XCTAssertEqual(metrics.batchCount, 0)
    }
}
