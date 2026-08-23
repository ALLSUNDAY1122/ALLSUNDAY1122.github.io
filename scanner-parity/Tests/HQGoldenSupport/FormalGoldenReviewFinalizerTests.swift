import XCTest
@testable import HQGoldenSupport

final class FormalGoldenReviewFinalizerTests: XCTestCase {
    private let reportSHA = String(repeating: "a", count: 64)
    private let videoSHA = String(repeating: "b", count: 64)
    private let pdfSHA = String(repeating: "c", count: 64)

    func testTemplateBindsExactExecutionAndStartsPending() {
        let execution = makeExecution()
        let template = FormalGoldenReviewFinalizer.makeTemplate(
            execution: execution,
            executionReportSHA256: reportSHA.uppercased()
        )
        XCTAssertEqual(template.bookID, execution.bookID)
        XCTAssertEqual(template.executionReportSHA256, reportSHA)
        XCTAssertEqual(template.videoSHA256, videoSHA)
        XCTAssertEqual(template.pdfSHA256, pdfSHA)
        XCTAssertFalse(template.reviewComplete)
        XCTAssertEqual(template.pages.map(\.sequence), [1, 2])
        XCTAssertTrue(template.pages.allSatisfy { $0.visualCorrection == .pending && $0.ocrSemantic == .pending })
    }

    func testAllExplicitHumanPassesCanIssueFormalGoldenPass() {
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: makeExecution(),
            executionReportSHA256: reportSHA,
            review: makeReview()
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.formalGoldenPass)
        XCTAssertEqual(assessment.visualPassCount, 2)
        XCTAssertEqual(assessment.ocrPassCount, 2)
        XCTAssertTrue(assessment.blockingReasons.isEmpty)
    }

    func testIncompleteReviewCannotPass() {
        let review = makeReview(
            complete: false,
            pages: [
                .init(sequence: 1, visualCorrection: .pass, ocrSemantic: .pass),
                .init(sequence: 2, visualCorrection: .pending, ocrSemantic: .pass)
            ]
        )
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: makeExecution(),
            executionReportSHA256: reportSHA,
            review: review
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.humanReviewPending)
        XCTAssertEqual(assessment.pendingPageSequences, [2])
        XCTAssertTrue(assessment.blockingReasons.contains("review_complete_not_acknowledged"))
    }

    func testExplicitHumanFailureFailsFormalGolden() {
        let review = makeReview(pages: [
            .init(sequence: 1, visualCorrection: .pass, ocrSemantic: .fail),
            .init(sequence: 2, visualCorrection: .pass, ocrSemantic: .pass)
        ])
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: makeExecution(),
            executionReportSHA256: reportSHA,
            review: review
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.humanReviewFail)
        XCTAssertEqual(assessment.failedPageSequences, [1])
    }

    func testReviewCannotBeReusedAgainstDifferentExecutionReport() {
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: makeExecution(),
            executionReportSHA256: String(repeating: "d", count: 64),
            review: makeReview()
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.reviewBindingFail)
        XCTAssertTrue(assessment.blockingReasons.contains("review_execution_report_sha_mismatch"))
    }

    func testMissingReviewPageFailsBinding() {
        let review = makeReview(pages: [
            .init(sequence: 1, visualCorrection: .pass, ocrSemantic: .pass)
        ])
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: makeExecution(),
            executionReportSHA256: reportSHA,
            review: review
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.reviewBindingFail)
        XCTAssertTrue(assessment.blockingReasons.contains("review_page_count_mismatch"))
    }

    func testMachineGateMustAlreadyBePassed() {
        let execution = makeExecution(
            machineVerdict: FormalGoldenMachineGate.machineFail,
            machineBlockers: ["page_recall_below_0_99"],
            formalVerdict: "FORMAL_GOLDEN_FAIL_MACHINE_GATE"
        )
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: execution,
            executionReportSHA256: reportSHA,
            review: makeReview()
        )
        XCTAssertEqual(assessment.verdict, FormalGoldenReviewFinalizer.preconditionNotMet)
        XCTAssertTrue(assessment.blockingReasons.contains("machine_gate_not_passed"))
    }

    private func makeExecution(
        machineVerdict: String = FormalGoldenMachineGate.machinePassHumanReviewPending,
        machineBlockers: [String] = [],
        formalVerdict: String = FormalGoldenReviewFinalizer.humanReviewPending
    ) -> FormalGoldenExecutionSnapshot {
        .init(
            schemaVersion: 4,
            bookID: "golden-v2-current-project-20260823",
            observedVideoSHA256: videoSHA,
            observedPDFSHA256: pdfSHA,
            videoSHAMatchesExpected: true,
            pdfSHAMatchesExpected: true,
            outputPageCount: 2,
            machineGateAssessment: .init(
                verdict: machineVerdict,
                blockingReasons: machineBlockers,
                humanReviewReasons: [
                    "visual_correction_quality_requires_real_page_review",
                    "ocr_semantic_accuracy_requires_real_page_review"
                ]
            ),
            formalGoldenVerdict: formalVerdict
        )
    }

    private func makeReview(
        complete: Bool = true,
        pages: [FormalGoldenReviewPageDecision]? = nil
    ) -> FormalGoldenHumanReview {
        .init(
            bookID: "golden-v2-current-project-20260823",
            executionReportSHA256: reportSHA,
            videoSHA256: videoSHA,
            pdfSHA256: pdfSHA,
            reviewer: "HQ",
            reviewedAt: "2026-08-24T03:00:00+09:00",
            reviewComplete: complete,
            pages: pages ?? [
                .init(sequence: 1, visualCorrection: .pass, ocrSemantic: .pass),
                .init(sequence: 2, visualCorrection: .pass, ocrSemantic: .pass)
            ]
        )
    }
}
