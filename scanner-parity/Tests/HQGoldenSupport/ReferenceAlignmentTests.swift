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
}
