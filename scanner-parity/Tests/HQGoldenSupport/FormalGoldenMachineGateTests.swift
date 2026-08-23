import XCTest
@testable import HQGoldenSupport

final class FormalGoldenMachineGateTests: XCTestCase {
    private func passingMetrics() -> ReferenceAlignmentMetrics {
        .init(
            referencePageCount: 28,
            outputPageCount: 28,
            matchedReferencePageCount: 28,
            pageRecall: 1,
            unmatchedOutputCount: 0,
            duplicateExtraCount: 0,
            duplicateRate: 0,
            orderingAccuracy: 1,
            threshold: 0.42
        )
    }

    private func input(
        videoSHA: Bool? = true,
        pdfSHA: Bool? = true,
        metrics: ReferenceAlignmentMetrics? = nil,
        correctionFailures: Int = 0,
        ocrFailures: Int = 0,
        packageValid: Bool = true,
        auditReviews: Int = 0,
        ocrReviews: Int = 0,
        emptyOCR: Int = 0,
        textlessPDF: Int = 0
    ) -> FormalGoldenMachineInputs {
        .init(
            videoSHAMatchesExpected: videoSHA,
            pdfSHAMatchesExpected: pdfSHA,
            referenceMetrics: metrics,
            correctionFailureCount: correctionFailures,
            ocrFailureCount: ocrFailures,
            packageIntegrityValid: packageValid,
            auditMissingSuspicionCount: 0,
            auditReversalCount: 0,
            auditDuplicateGroupCount: 0,
            auditReviewCount: auditReviews,
            ocrNeedsReviewCount: ocrReviews,
            ocrEmptyTextPageCount: emptyOCR,
            searchablePDFTextlessPageCount: textlessPDF
        )
    }

    func testExpectedSHAIsRequiredBeforeMachineGate() {
        let result = FormalGoldenMachineGate.evaluate(input(videoSHA: nil, pdfSHA: nil))
        XCTAssertEqual(result.verdict, FormalGoldenMachineGate.pendingIdentity)
        XCTAssertTrue(result.blockingReasons.contains("expected_golden_sha_not_supplied"))
    }

    func testThresholdCalibrationIsRequired() {
        let result = FormalGoldenMachineGate.evaluate(input())
        XCTAssertEqual(result.verdict, FormalGoldenMachineGate.pendingReferenceThreshold)
        XCTAssertTrue(result.blockingReasons.contains("reference_match_threshold_not_calibrated"))
    }

    func testHardMachineFailuresFailClosed() {
        var failing = passingMetrics()
        failing = .init(
            referencePageCount: failing.referencePageCount,
            outputPageCount: 29,
            matchedReferencePageCount: 27,
            pageRecall: 27.0 / 28.0,
            unmatchedOutputCount: 1,
            duplicateExtraCount: 1,
            duplicateRate: 1.0 / 29.0,
            orderingAccuracy: 0.95,
            threshold: failing.threshold
        )
        let result = FormalGoldenMachineGate.evaluate(input(
            videoSHA: false,
            metrics: failing,
            correctionFailures: 1,
            ocrFailures: 1,
            packageValid: false
        ))
        XCTAssertEqual(result.verdict, FormalGoldenMachineGate.machineFail)
        XCTAssertTrue(result.blockingReasons.contains("video_sha_mismatch"))
        XCTAssertTrue(result.blockingReasons.contains("page_recall_below_0_99"))
        XCTAssertTrue(result.blockingReasons.contains("unmatched_output_present"))
        XCTAssertTrue(result.blockingReasons.contains("duplicate_rate_above_0_005"))
        XCTAssertTrue(result.blockingReasons.contains("ordering_accuracy_below_1_0"))
        XCTAssertTrue(result.blockingReasons.contains("image_correction_stage_failure"))
        XCTAssertTrue(result.blockingReasons.contains("ocr_engine_failure"))
        XCTAssertTrue(result.blockingReasons.contains("book_package_integrity_failure"))
    }

    func testMachinePassStillRequiresRealVisualAndOCRReview() {
        let result = FormalGoldenMachineGate.evaluate(input(
            metrics: passingMetrics(),
            auditReviews: 2,
            ocrReviews: 1,
            emptyOCR: 1,
            textlessPDF: 1
        ))
        XCTAssertEqual(result.verdict, FormalGoldenMachineGate.machinePassHumanReviewPending)
        XCTAssertTrue(result.blockingReasons.isEmpty)
        XCTAssertTrue(result.humanReviewReasons.contains("visual_correction_quality_requires_real_page_review"))
        XCTAssertTrue(result.humanReviewReasons.contains("ocr_semantic_accuracy_requires_real_page_review"))
        XCTAssertTrue(result.humanReviewReasons.contains("page_audit_review_items_present"))
        XCTAssertTrue(result.humanReviewReasons.contains("ocr_low_confidence_review_pages_present"))
        XCTAssertTrue(result.humanReviewReasons.contains("ocr_empty_text_pages_present"))
        XCTAssertTrue(result.humanReviewReasons.contains("searchable_pdf_textless_pages_present"))
        XCTAssertFalse(result.verdict.contains("FORMAL_GOLDEN_PASS"))
    }
}
