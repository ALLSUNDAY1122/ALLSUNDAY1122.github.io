import Foundation

public struct FormalGoldenMachineInputs: Codable, Sendable, Equatable {
    public let videoSHAMatchesExpected: Bool?
    public let pdfSHAMatchesExpected: Bool?
    public let referenceMetrics: ReferenceAlignmentMetrics?
    public let correctionFailureCount: Int
    public let ocrFailureCount: Int
    public let packageIntegrityValid: Bool
    public let auditMissingSuspicionCount: Int
    public let auditReversalCount: Int
    public let auditDuplicateGroupCount: Int
    public let auditReviewCount: Int
    public let ocrNeedsReviewCount: Int
    public let ocrEmptyTextPageCount: Int
    public let searchablePDFTextlessPageCount: Int

    public init(
        videoSHAMatchesExpected: Bool?,
        pdfSHAMatchesExpected: Bool?,
        referenceMetrics: ReferenceAlignmentMetrics?,
        correctionFailureCount: Int,
        ocrFailureCount: Int,
        packageIntegrityValid: Bool,
        auditMissingSuspicionCount: Int,
        auditReversalCount: Int,
        auditDuplicateGroupCount: Int,
        auditReviewCount: Int,
        ocrNeedsReviewCount: Int,
        ocrEmptyTextPageCount: Int,
        searchablePDFTextlessPageCount: Int
    ) {
        self.videoSHAMatchesExpected = videoSHAMatchesExpected
        self.pdfSHAMatchesExpected = pdfSHAMatchesExpected
        self.referenceMetrics = referenceMetrics
        self.correctionFailureCount = correctionFailureCount
        self.ocrFailureCount = ocrFailureCount
        self.packageIntegrityValid = packageIntegrityValid
        self.auditMissingSuspicionCount = auditMissingSuspicionCount
        self.auditReversalCount = auditReversalCount
        self.auditDuplicateGroupCount = auditDuplicateGroupCount
        self.auditReviewCount = auditReviewCount
        self.ocrNeedsReviewCount = ocrNeedsReviewCount
        self.ocrEmptyTextPageCount = ocrEmptyTextPageCount
        self.searchablePDFTextlessPageCount = searchablePDFTextlessPageCount
    }
}

public struct FormalGoldenMachineAssessment: Codable, Sendable, Equatable {
    public let verdict: String
    public let blockingReasons: [String]
    public let humanReviewReasons: [String]

    public init(verdict: String, blockingReasons: [String], humanReviewReasons: [String]) {
        self.verdict = verdict
        self.blockingReasons = blockingReasons
        self.humanReviewReasons = humanReviewReasons
    }
}

public enum FormalGoldenMachineGate {
    public static let pendingIdentity = "PENDING_GOLDEN_IDENTITY_EXPECTATIONS"
    public static let pendingReferenceThreshold = "PENDING_REFERENCE_THRESHOLD_CALIBRATION"
    public static let machineFail = "MACHINE_GATES_FAIL"
    public static let machinePassHumanReviewPending = "MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING"

    public static func evaluate(_ input: FormalGoldenMachineInputs) -> FormalGoldenMachineAssessment {
        var blockers: [String] = []
        var humanReview: [String] = [
            "visual_correction_quality_requires_real_page_review",
            "ocr_semantic_accuracy_requires_real_page_review"
        ]

        guard input.videoSHAMatchesExpected != nil, input.pdfSHAMatchesExpected != nil else {
            return .init(
                verdict: pendingIdentity,
                blockingReasons: ["expected_golden_sha_not_supplied"],
                humanReviewReasons: humanReview
            )
        }

        if input.videoSHAMatchesExpected == false { blockers.append("video_sha_mismatch") }
        if input.pdfSHAMatchesExpected == false { blockers.append("pdf_sha_mismatch") }

        guard let metrics = input.referenceMetrics else {
            return .init(
                verdict: blockers.isEmpty ? pendingReferenceThreshold : machineFail,
                blockingReasons: blockers.isEmpty ? ["reference_match_threshold_not_calibrated"] : blockers,
                humanReviewReasons: humanReview
            )
        }

        if metrics.pageRecall < 0.99 { blockers.append("page_recall_below_0_99") }
        if metrics.unmatchedOutputCount != 0 { blockers.append("unmatched_output_present") }
        if metrics.duplicateRate > 0.005 { blockers.append("duplicate_rate_above_0_005") }
        if metrics.orderingAccuracy < 1.0 { blockers.append("ordering_accuracy_below_1_0") }
        if input.correctionFailureCount > 0 { blockers.append("image_correction_stage_failure") }
        if input.ocrFailureCount > 0 { blockers.append("ocr_engine_failure") }
        if !input.packageIntegrityValid { blockers.append("book_package_integrity_failure") }

        if input.auditMissingSuspicionCount > 0 { humanReview.append("page_audit_missing_suspicion_present") }
        if input.auditReversalCount > 0 { humanReview.append("page_audit_reversal_signal_present") }
        if input.auditDuplicateGroupCount > 0 { humanReview.append("page_audit_duplicate_signal_present") }
        if input.auditReviewCount > 0 { humanReview.append("page_audit_review_items_present") }
        if input.ocrNeedsReviewCount > 0 { humanReview.append("ocr_low_confidence_review_pages_present") }
        if input.ocrEmptyTextPageCount > 0 { humanReview.append("ocr_empty_text_pages_present") }
        if input.searchablePDFTextlessPageCount > 0 { humanReview.append("searchable_pdf_textless_pages_present") }

        return .init(
            verdict: blockers.isEmpty ? machinePassHumanReviewPending : machineFail,
            blockingReasons: blockers,
            humanReviewReasons: Array(Set(humanReview)).sorted()
        )
    }
}
