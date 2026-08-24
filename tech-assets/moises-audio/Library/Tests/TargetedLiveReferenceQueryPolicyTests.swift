import Foundation
import XCTest

final class Lane2TargetedLiveReferenceQueryPolicyTests: XCTestCase {
    func testClassifiesAndDeduplicatesCandidatePaths() throws {
        let plan = try Lane2TargetedLiveReferenceQueryPolicy.plan(
            candidateArtifactPaths: [
                "Imports/a/source.m4a",
                "Stems/a/vocals.m4a",
                "Stems/a/vocals.m4a",
                "Imports/b/source.wav"
            ],
            batchSize: 2
        )
        XCTAssertEqual(plan.sourceArtifactPaths, ["Imports/a/source.m4a", "Imports/b/source.wav"])
        XCTAssertEqual(plan.stemArtifactPaths, ["Stems/a/vocals.m4a"])
        XCTAssertEqual(plan.requestedArtifactPathCount, 3)
        XCTAssertEqual(plan.sourceBatchCount, 1)
        XCTAssertEqual(plan.stemBatchCount, 1)
    }

    func testLargeCandidateSetIsBatchCountedWithoutLiveLibraryInput() throws {
        var paths = Set<String>()
        for index in 0..<513 {
            paths.insert(index.isMultiple(of: 2)
                ? "Imports/\(index)/source.m4a"
                : "Stems/\(index)/vocals.m4a")
        }
        let plan = try Lane2TargetedLiveReferenceQueryPolicy.plan(
            candidateArtifactPaths: paths,
            batchSize: 128
        )
        XCTAssertEqual(plan.requestedArtifactPathCount, 513)
        XCTAssertEqual(plan.sourceBatchCount, 3)
        XCTAssertEqual(plan.stemBatchCount, 2)
    }

    func testUnsafePathsFailClosed() {
        for path in [
            "Exports/x/mix.m4a",
            "../outside",
            "/absolute/file.m4a",
            "Imports/../escape.m4a",
            "Imports\\x\\source.m4a",
            "Stems//vocals.m4a"
        ] {
            XCTAssertThrowsError(
                try Lane2TargetedLiveReferenceQueryPolicy.plan(candidateArtifactPaths: [path])
            )
        }
    }

    func testDiagnosticsMergePreservesMeasurementTotals() {
        let first = Lane2TargetedLiveReferenceDiagnostics(
            usedTargetedStoreQuery: true,
            requestedProjectIDs: 2,
            requestedArtifactPaths: 4,
            sourceArtifactPaths: 2,
            stemArtifactPaths: 2,
            liveProjectIDsMatched: 1,
            liveArtifactPathsMatched: 2,
            logicalFetchCalls: 5
        )
        let second = Lane2TargetedLiveReferenceDiagnostics(
            usedTargetedStoreQuery: true,
            requestedProjectIDs: 0,
            requestedArtifactPaths: 3,
            sourceArtifactPaths: 1,
            stemArtifactPaths: 2,
            liveProjectIDsMatched: 0,
            liveArtifactPathsMatched: 1,
            logicalFetchCalls: 4
        )
        let merged = first.merged(with: second)
        XCTAssertTrue(merged.usedTargetedStoreQuery)
        XCTAssertEqual(merged.requestedProjectIDs, 2)
        XCTAssertEqual(merged.requestedArtifactPaths, 7)
        XCTAssertEqual(merged.liveArtifactPathsMatched, 3)
        XCTAssertEqual(merged.logicalFetchCalls, 9)
    }
}
