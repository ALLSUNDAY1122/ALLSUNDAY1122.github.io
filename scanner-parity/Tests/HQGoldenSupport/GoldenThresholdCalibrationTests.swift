import XCTest
@testable import HQGoldenSupport

final class GoldenThresholdCalibrationTests: XCTestCase {
    private let executionSHA = String(repeating: "a", count: 64)
    private let evidenceSHA = String(repeating: "b", count: 64)

    private var matches: [ReferenceNearestMatch] {
        [
            .init(outputIndex: 0, referenceIndex: 0, distance: 0.10, secondBestDistance: 0.42),
            .init(outputIndex: 1, referenceIndex: 1, distance: 0.12, secondBestDistance: 0.40),
            .init(outputIndex: 2, referenceIndex: 2, distance: 0.14, secondBestDistance: 0.39),
            .init(outputIndex: 3, referenceIndex: 2, distance: 0.80, secondBestDistance: 0.92)
        ]
    }

    private func evidence() throws -> GoldenThresholdCalibrationEvidence {
        try GoldenThresholdCalibration.analyze(
            executionReportSHA256: executionSHA,
            bookID: "golden-book",
            observedVideoSHA256: String(repeating: "c", count: 64),
            observedPDFSHA256: String(repeating: "d", count: 64),
            referencePageCount: 3,
            nearestMatches: matches
        )
    }

    func testAnalysisProducesDistributionAndSweepButNeverRecommendation() throws {
        let result = try evidence()
        XCTAssertEqual(result.verdict, GoldenThresholdCalibration.evidenceVerdict)
        XCTAssertNil(result.recommendedThreshold)
        XCTAssertEqual(result.outputPageCount, 4)
        XCTAssertEqual(result.nearestDistanceDistribution.count, 4)
        XCTAssertEqual(result.nearestDistanceDistribution.minimum, 0.10, accuracy: 0.0001)
        XCTAssertEqual(result.nearestDistanceDistribution.maximum, 0.80, accuracy: 0.0001)
        XCTAssertEqual(result.secondBestDistanceDistribution?.count, 4)
        XCTAssertEqual(result.nearestVsSecondBestMarginDistribution?.count, 4)
        XCTAssertFalse(result.thresholdSweep.isEmpty)
        XCTAssertEqual(result.thresholdSweep.first?.threshold, 0)
        let largest = try XCTUnwrap(result.largestNearestDistanceGaps.first)
        XCTAssertEqual(largest.lowerDistance, 0.14, accuracy: 0.0001)
        XCTAssertEqual(largest.upperDistance, 0.80, accuracy: 0.0001)
        XCTAssertEqual(largest.acceptedOutputCountBelowGap, 3)
    }

    func testDecisionTemplateBindsBothSourceAndCalibrationEvidenceAndStartsIncomplete() throws {
        let result = try evidence()
        let template = try GoldenThresholdCalibration.makeDecisionTemplate(
            evidence: result,
            calibrationEvidenceSHA256: evidenceSHA
        )
        XCTAssertEqual(template.executionReportSHA256, executionSHA)
        XCTAssertEqual(template.calibrationEvidenceSHA256, evidenceSHA)
        XCTAssertNil(template.threshold)
        XCTAssertTrue(template.rationale.isEmpty)
        XCTAssertTrue(template.reviewer.isEmpty)
        XCTAssertTrue(template.decidedAt.isEmpty)
    }

    func testExplicitBoundDecisionBecomesValidForRerunWithoutBecomingGoldenPass() throws {
        let result = try evidence()
        let decision = GoldenThresholdDecision(
            schemaVersion: 1,
            executionReportSHA256: executionSHA,
            calibrationEvidenceSHA256: evidenceSHA,
            bookID: result.bookID,
            observedVideoSHA256: result.observedVideoSHA256,
            observedPDFSHA256: result.observedPDFSHA256,
            threshold: 0.14,
            rationale: "Largest observed separation before the distant extra output; inspect review bundle before use.",
            reviewer: "HQ",
            decidedAt: "2026-08-24T05:00:00+09:00"
        )
        let assessment = GoldenThresholdCalibration.validateDecision(
            evidence: result,
            calibrationEvidenceSHA256: evidenceSHA,
            decision: decision,
            nearestMatches: matches
        )
        XCTAssertEqual(assessment.verdict, GoldenThresholdCalibration.decisionValid)
        XCTAssertTrue(assessment.blockingReasons.isEmpty)
        let threshold = try XCTUnwrap(assessment.threshold)
        XCTAssertEqual(threshold, 0.14, accuracy: 0.000001)
        let metrics = try XCTUnwrap(assessment.selectedMetrics)
        XCTAssertEqual(metrics.pageRecall, 1, accuracy: 0.000001)
        XCTAssertEqual(metrics.unmatchedOutputCount, 1)
        XCTAssertFalse(assessment.verdict.contains("FORMAL_GOLDEN_PASS"))
    }

    func testDecisionCannotBeReusedAgainstDifferentExecutionReport() throws {
        let result = try evidence()
        let decision = GoldenThresholdDecision(
            schemaVersion: 1,
            executionReportSHA256: String(repeating: "e", count: 64),
            calibrationEvidenceSHA256: evidenceSHA,
            bookID: result.bookID,
            observedVideoSHA256: result.observedVideoSHA256,
            observedPDFSHA256: result.observedPDFSHA256,
            threshold: 0.14,
            rationale: "Reviewed",
            reviewer: "HQ",
            decidedAt: "2026-08-24T05:00:00+09:00"
        )
        let assessment = GoldenThresholdCalibration.validateDecision(
            evidence: result,
            calibrationEvidenceSHA256: evidenceSHA,
            decision: decision,
            nearestMatches: matches
        )
        XCTAssertEqual(assessment.verdict, GoldenThresholdCalibration.decisionInvalid)
        XCTAssertTrue(assessment.blockingReasons.contains { $0.contains("execution-report SHA") })
    }

    func testDecisionCannotBeReusedAfterCalibrationEvidenceChanges() throws {
        let result = try evidence()
        let decision = GoldenThresholdDecision(
            schemaVersion: 1,
            executionReportSHA256: executionSHA,
            calibrationEvidenceSHA256: String(repeating: "e", count: 64),
            bookID: result.bookID,
            observedVideoSHA256: result.observedVideoSHA256,
            observedPDFSHA256: result.observedPDFSHA256,
            threshold: 0.14,
            rationale: "Reviewed",
            reviewer: "HQ",
            decidedAt: "2026-08-24T05:00:00+09:00"
        )
        let assessment = GoldenThresholdCalibration.validateDecision(
            evidence: result,
            calibrationEvidenceSHA256: evidenceSHA,
            decision: decision,
            nearestMatches: matches
        )
        XCTAssertEqual(assessment.verdict, GoldenThresholdCalibration.decisionInvalid)
        XCTAssertTrue(assessment.blockingReasons.contains { $0.contains("calibration-evidence SHA") })
    }

    func testNumericThresholdAloneIsNotAValidDecision() throws {
        let result = try evidence()
        let decision = GoldenThresholdDecision(
            schemaVersion: 1,
            executionReportSHA256: executionSHA,
            calibrationEvidenceSHA256: evidenceSHA,
            bookID: result.bookID,
            observedVideoSHA256: result.observedVideoSHA256,
            observedPDFSHA256: result.observedPDFSHA256,
            threshold: 0.14,
            rationale: "",
            reviewer: "",
            decidedAt: ""
        )
        let assessment = GoldenThresholdCalibration.validateDecision(
            evidence: result,
            calibrationEvidenceSHA256: evidenceSHA,
            decision: decision,
            nearestMatches: matches
        )
        XCTAssertEqual(assessment.verdict, GoldenThresholdCalibration.decisionInvalid)
        XCTAssertGreaterThanOrEqual(assessment.blockingReasons.count, 3)
    }
}
