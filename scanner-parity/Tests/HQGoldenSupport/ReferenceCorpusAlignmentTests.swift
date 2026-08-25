import XCTest
@testable import HQGoldenSupport

final class ReferenceCorpusAlignmentTests: XCTestCase {
    func testCanonicalGroupsReplaceRawPDFPageCountForRecallAndOrdering() {
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

        let metrics = ReferenceAlignment.evaluate(
            referencePageCount: 28,
            nearestMatches: matches,
            threshold: 0.2
        )
        XCTAssertEqual(metrics.referencePageCount, 3)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.orderingAccuracy, 1, accuracy: 0.000001)
    }

    func testMultipleRawReferenceCapturesOfOneCanonicalPageCountAsDuplicateOutput() {
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

        let metrics = ReferenceAlignment.evaluate(
            referencePageCount: 28,
            nearestMatches: matches,
            threshold: 0.2
        )
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.duplicateExtraCount, 1)
        XCTAssertEqual(metrics.duplicateRate, 1.0 / 3.0, accuracy: 0.000001)
    }

    func testNegativeReferenceDominanceRejectsFalsePositiveOutput() {
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

        let metrics = ReferenceAlignment.evaluate(
            referencePageCount: 28,
            nearestMatches: matches,
            threshold: 0.2
        )
        XCTAssertEqual(metrics.pageRecall, 0, accuracy: 0.000001)
        XCTAssertEqual(metrics.unmatchedOutputCount, 1)
    }

    func testInconsistentCorpusCountsFailClosedToRawReferenceCount() {
        let matches = [
            ReferenceNearestMatch(
                outputIndex: 0,
                referenceIndex: 0,
                distance: 0.1,
                canonicalReferenceIndex: 0,
                referenceCorpusPageCount: 2
            ),
            ReferenceNearestMatch(
                outputIndex: 1,
                referenceIndex: 1,
                distance: 0.1,
                canonicalReferenceIndex: 1,
                referenceCorpusPageCount: 3
            )
        ]

        let metrics = ReferenceAlignment.evaluate(
            referencePageCount: 28,
            nearestMatches: matches,
            threshold: 0.2
        )
        XCTAssertEqual(metrics.referencePageCount, 28)
        XCTAssertLessThan(metrics.pageRecall, 0.1)
    }
}
