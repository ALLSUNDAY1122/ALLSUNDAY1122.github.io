import XCTest
@testable import GoldenEvaluation
import FrameExtraction
import ImageCorrection
import PageAudit

final class GoldenEvaluationTests: XCTestCase {
    private func candidate(_ id: String, time: Int64) -> PageCandidate {
        .init(
            candidateID: id,
            bookID: "book-fixture",
            sourceTimeMS: time,
            sourceRangeMS: .init(start: time - 50, end: time + 50),
            imageRef: "fixture://\(id)",
            stabilityScore: 0.99,
            sharpnessScore: 0.95,
            motionScore: 0.01
        )
    }

    private func corrected(_ pageID: String, candidateID: String) -> CorrectedPageMetadata {
        .init(
            pageID: pageID,
            candidateID: candidateID,
            cropQuad: .fullFrame,
            rotationDegrees: 0,
            perspectiveApplied: false,
            dewarpApplied: false,
            colorProfile: .reading,
            qualityScores: .init(
                boundaryConfidence: 0.99,
                perspectiveSeverity: 0,
                residualSkewDegrees: 0
            ),
            flags: []
        )
    }

    private func emptyAudit(order: [String]) -> PageAuditResult {
        .init(
            orderedPageIDs: order,
            pageNumberObservations: [],
            duplicateGroups: [],
            missingPageSuspicions: [],
            reversalEvents: [],
            autoFixes: [],
            reviewRequired: []
        )
    }

    func testPerfectFixtureMeetsAllMetricTargetsWithoutIssuingGoldenVerdict() {
        let candidates = [candidate("c1", time: 1_000), candidate("c2", time: 2_000), candidate("c3", time: 3_000)]
        let correctedPages = [
            corrected("p1", candidateID: "c1"),
            corrected("p2", candidateID: "c2"),
            corrected("p3", candidateID: "c3")
        ]
        let report = GoldenQualityEvaluator.evaluate(
            candidates: candidates,
            correctedPages: correctedPages,
            auditResult: emptyAudit(order: ["p1", "p2", "p3"]),
            groundTruth: .init(expectedPageIDs: ["p1", "p2", "p3"]),
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(report.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(report.transitionAcceptedCount, 0)
        XCTAssertEqual(report.duplicateRate, 0, accuracy: 0.000001)
        XCTAssertEqual(report.orderingAccuracy, 1, accuracy: 0.000001)
        XCTAssertTrue(report.metricEvaluations.allSatisfy(\.meetsTarget))
        XCTAssertEqual(report.workerGoldenVerdict, "NOT_ISSUED_HQ_GOLDEN_GATE_ONLY")
    }

    func testMissingAndMisorderedPagesMissRecallAndOrderingTargets() {
        let candidates = [candidate("c1", time: 1_000), candidate("c3", time: 3_000), candidate("c2", time: 2_000)]
        let correctedPages = [
            corrected("p1", candidateID: "c1"),
            corrected("p3", candidateID: "c3")
        ]
        let report = GoldenQualityEvaluator.evaluate(
            candidates: candidates,
            correctedPages: correctedPages,
            auditResult: emptyAudit(order: ["p3", "p1"]),
            groundTruth: .init(expectedPageIDs: ["p1", "p2", "p3"])
        )

        XCTAssertEqual(report.pageRecall, 2.0 / 3.0, accuracy: 0.000001)
        XCTAssertEqual(report.orderingAccuracy, 0, accuracy: 0.000001)
        XCTAssertFalse(report.metricEvaluations.first { $0.name == "page_recall" }!.meetsTarget)
        XCTAssertFalse(report.metricEvaluations.first { $0.name == "ordering_accuracy" }!.meetsTarget)
    }

    func testTransitionAcceptanceIsMeasuredFromCorrectedCandidateLineage() {
        let candidates = [candidate("stable", time: 1_000), candidate("turning", time: 1_500)]
        let correctedPages = [
            corrected("p1", candidateID: "stable"),
            corrected("p2", candidateID: "turning")
        ]
        let report = GoldenQualityEvaluator.evaluate(
            candidates: candidates,
            correctedPages: correctedPages,
            auditResult: emptyAudit(order: ["p1", "p2"]),
            groundTruth: .init(
                expectedPageIDs: ["p1", "p2"],
                transitionCandidateIDs: ["turning"]
            )
        )

        XCTAssertEqual(report.transitionAcceptedCount, 1)
        XCTAssertFalse(report.metricEvaluations.first { $0.name == "mid_transition_accepted" }!.meetsTarget)
    }

    func testDuplicateRateUsesAuditDuplicateGroups() {
        let duplicate = DuplicateGroup(
            pageIDs: ["p2", "p2-dup"],
            confidence: 0.99,
            evidence: [.imageSimilarity, .textSimilarity]
        )
        let audit = PageAuditResult(
            orderedPageIDs: ["p1", "p2"],
            pageNumberObservations: [],
            duplicateGroups: [duplicate],
            missingPageSuspicions: [],
            reversalEvents: [],
            autoFixes: [],
            reviewRequired: []
        )
        let candidates = [candidate("c1", time: 1_000), candidate("c2", time: 2_000), candidate("c2d", time: 2_100)]
        let correctedPages = [
            corrected("p1", candidateID: "c1"),
            corrected("p2", candidateID: "c2"),
            corrected("p2-dup", candidateID: "c2d")
        ]
        let report = GoldenQualityEvaluator.evaluate(
            candidates: candidates,
            correctedPages: correctedPages,
            auditResult: audit,
            groundTruth: .init(expectedPageIDs: ["p1", "p2"])
        )

        XCTAssertEqual(report.duplicateRate, 1.0 / 3.0, accuracy: 0.000001)
        XCTAssertFalse(report.metricEvaluations.first { $0.name == "duplicate_rate" }!.meetsTarget)
    }

    func testSHAMismatchIsRecordedButOwnedByHQ() {
        let report = GoldenQualityEvaluator.evaluate(
            candidates: [],
            correctedPages: [],
            auditResult: emptyAudit(order: []),
            groundTruth: .init(
                expectedPageIDs: [],
                expectedVideoSHA256: "expected-video",
                expectedPDFSHA256: "expected-pdf"
            ),
            observedHashes: .init(videoSHA256: "different-video", pdfSHA256: nil)
        )

        let video = report.shaObservations.first { $0.artifact == "video" }!
        XCTAssertEqual(video.matchesExpected, false)
        XCTAssertEqual(video.ownership, "HQ_ONLY")
        XCTAssertNil(report.shaObservations.first { $0.artifact == "pdf" }!.matchesExpected)
    }

    func testJSONAndMarkdownReportsContainNoFormalWorkerPassFail() throws {
        let report = GoldenQualityEvaluator.evaluate(
            candidates: [],
            correctedPages: [],
            auditResult: emptyAudit(order: []),
            groundTruth: .init(expectedPageIDs: [])
        )
        let json = String(decoding: try GoldenQualityEvaluator.jsonData(report), as: UTF8.self)
        let markdown = GoldenReportFormatter.markdown(report)

        XCTAssertTrue(json.contains("NOT_ISSUED_HQ_GOLDEN_GATE_ONLY"))
        XCTAssertTrue(markdown.contains("Formal Golden PASS/FAIL is owned by HQ_GOLDEN_GATE"))
    }
}
