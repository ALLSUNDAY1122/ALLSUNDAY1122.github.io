import XCTest
@testable import HQGoldenSupport

final class ReferenceAlignmentTests: XCTestCase {
    func testPerfectSequencePassesCoreReferenceMetrics() {
        let matches = [
            ReferenceNearestMatch(outputIndex: 0, referenceIndex: 0, distance: 1),
            ReferenceNearestMatch(outputIndex: 1, referenceIndex: 1, distance: 1),
            ReferenceNearestMatch(outputIndex: 2, referenceIndex: 2, distance: 1)
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 3, nearestMatches: matches, threshold: 5)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.unmatchedOutputCount, 0)
        XCTAssertEqual(metrics.duplicateRate, 0, accuracy: 0.000001)
        XCTAssertEqual(metrics.orderingAccuracy, 1, accuracy: 0.000001)
    }

    func testThresholdRejectsUnmatchedOutputAndReducesRecall() {
        let matches = [
            ReferenceNearestMatch(outputIndex: 0, referenceIndex: 0, distance: 1),
            ReferenceNearestMatch(outputIndex: 1, referenceIndex: 1, distance: 10),
            ReferenceNearestMatch(outputIndex: 2, referenceIndex: 2, distance: 1)
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 3, nearestMatches: matches, threshold: 5)
        XCTAssertEqual(metrics.pageRecall, 2.0 / 3.0, accuracy: 0.000001)
        XCTAssertEqual(metrics.unmatchedOutputCount, 1)
    }

    func testDuplicateReferenceMatchCountsExtraOutput() {
        let matches = [
            ReferenceNearestMatch(outputIndex: 0, referenceIndex: 0, distance: 1),
            ReferenceNearestMatch(outputIndex: 1, referenceIndex: 1, distance: 1),
            ReferenceNearestMatch(outputIndex: 2, referenceIndex: 1, distance: 1),
            ReferenceNearestMatch(outputIndex: 3, referenceIndex: 2, distance: 1)
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 3, nearestMatches: matches, threshold: 5)
        XCTAssertEqual(metrics.matchedReferencePageCount, 3)
        XCTAssertEqual(metrics.duplicateExtraCount, 1)
        XCTAssertEqual(metrics.duplicateRate, 0.25, accuracy: 0.000001)
    }

    func testReversalReducesOrderingAccuracy() {
        let matches = [
            ReferenceNearestMatch(outputIndex: 0, referenceIndex: 0, distance: 1),
            ReferenceNearestMatch(outputIndex: 1, referenceIndex: 2, distance: 1),
            ReferenceNearestMatch(outputIndex: 2, referenceIndex: 1, distance: 1)
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 3, nearestMatches: matches, threshold: 5)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.orderingAccuracy, 2.0 / 3.0, accuracy: 0.000001)
    }

    func testCanonicalCorpusOverridesRawPDFPageCount() {
        let matches = [
            ReferenceNearestMatch(
                outputIndex: 0,
                referenceIndex: 7,
                distance: 0.1,
                canonicalReferenceIndex: 0,
                referenceCorpusPageCount: 3,
                referenceCorpusGroupID: "g1"
            ),
            ReferenceNearestMatch(
                outputIndex: 1,
                referenceIndex: 9,
                distance: 0.1,
                canonicalReferenceIndex: 1,
                referenceCorpusPageCount: 3,
                referenceCorpusGroupID: "g2"
            ),
            ReferenceNearestMatch(
                outputIndex: 2,
                referenceIndex: 12,
                distance: 0.1,
                canonicalReferenceIndex: 2,
                referenceCorpusPageCount: 3,
                referenceCorpusGroupID: "g3"
            )
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 28, nearestMatches: matches, threshold: 0.2)
        XCTAssertEqual(metrics.referencePageCount, 3)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.orderingAccuracy, 1, accuracy: 0.000001)
    }

    func testCanonicalGroupCountsDuplicateAcrossDifferentRawCaptures() {
        let matches = [
            ReferenceNearestMatch(
                outputIndex: 0,
                referenceIndex: 12,
                distance: 0.1,
                canonicalReferenceIndex: 0,
                referenceCorpusPageCount: 2
            ),
            ReferenceNearestMatch(
                outputIndex: 1,
                referenceIndex: 14,
                distance: 0.11,
                canonicalReferenceIndex: 0,
                referenceCorpusPageCount: 2
            ),
            ReferenceNearestMatch(
                outputIndex: 2,
                referenceIndex: 13,
                distance: 0.1,
                canonicalReferenceIndex: 1,
                referenceCorpusPageCount: 2
            )
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 28, nearestMatches: matches, threshold: 0.2)
        XCTAssertEqual(metrics.referencePageCount, 2)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.duplicateExtraCount, 1)
        XCTAssertEqual(metrics.duplicateRate, 1.0 / 3.0, accuracy: 0.000001)
    }

    func testNegativeReferenceDominanceRejectsOutput() {
        let matches = [
            ReferenceNearestMatch(
                outputIndex: 0,
                referenceIndex: 7,
                distance: 0.12,
                canonicalReferenceIndex: 0,
                referenceCorpusPageCount: 1,
                nearestNegativeReferenceIndex: 1,
                nearestNegativeDistance: 0.08
            )
        ]
        let metrics = ReferenceAlignment.evaluate(referencePageCount: 28, nearestMatches: matches, threshold: 0.2)
        XCTAssertEqual(metrics.pageRecall, 0, accuracy: 0.000001)
        XCTAssertEqual(metrics.unmatchedOutputCount, 1)
    }

    func testReferenceCorpusManifestFailsClosedOnIncompleteCoverage() {
        let sha = String(repeating: "a", count: 64)
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: sha,
            referencePDFPageCount: 4,
            negativeReferencePageNumbers: [1],
            groups: [
                .init(id: "g1", referencePageNumbers: [2]),
                .init(id: "g2", referencePageNumbers: [4])
            ]
        )
        XCTAssertThrowsError(try manifest.validate(actualPDFPageCount: 4, actualPDFSHA256: sha))
    }

    func testReferenceCorpusManifestFailsClosedOnWrongPDFSHA() {
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: String(repeating: "a", count: 64),
            referencePDFPageCount: 2,
            negativeReferencePageNumbers: [],
            groups: [
                .init(id: "g1", referencePageNumbers: [1]),
                .init(id: "g2", referencePageNumbers: [2])
            ]
        )
        XCTAssertThrowsError(
            try manifest.validate(
                actualPDFPageCount: 2,
                actualPDFSHA256: String(repeating: "b", count: 64)
            )
        )
    }
}
