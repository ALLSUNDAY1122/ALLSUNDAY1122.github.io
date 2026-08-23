import Foundation

public enum FormalGoldenReviewDecision: String, Codable, Sendable {
    case pending = "PENDING"
    case pass = "PASS"
    case fail = "FAIL"
}

public struct FormalGoldenReviewPageDecision: Codable, Sendable, Equatable {
    public let sequence: Int
    public let visualCorrection: FormalGoldenReviewDecision
    public let ocrSemantic: FormalGoldenReviewDecision
    public let notes: String?

    public init(
        sequence: Int,
        visualCorrection: FormalGoldenReviewDecision,
        ocrSemantic: FormalGoldenReviewDecision,
        notes: String? = nil
    ) {
        self.sequence = sequence
        self.visualCorrection = visualCorrection
        self.ocrSemantic = ocrSemantic
        self.notes = notes
    }
}

public struct FormalGoldenHumanReview: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bookID: String
    public let executionReportSHA256: String
    public let videoSHA256: String
    public let pdfSHA256: String
    public let reviewer: String
    public let reviewedAt: String
    public let reviewComplete: Bool
    public let pages: [FormalGoldenReviewPageDecision]

    public init(
        schemaVersion: Int = 1,
        bookID: String,
        executionReportSHA256: String,
        videoSHA256: String,
        pdfSHA256: String,
        reviewer: String,
        reviewedAt: String,
        reviewComplete: Bool,
        pages: [FormalGoldenReviewPageDecision]
    ) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.executionReportSHA256 = executionReportSHA256
        self.videoSHA256 = videoSHA256
        self.pdfSHA256 = pdfSHA256
        self.reviewer = reviewer
        self.reviewedAt = reviewedAt
        self.reviewComplete = reviewComplete
        self.pages = pages
    }
}

/// Minimal, stable projection of hq-golden-execution.json needed to bind and finalize
/// the explicit human visual/OCR review. Extra fields in the execution report are
/// intentionally ignored by JSONDecoder.
public struct FormalGoldenExecutionSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bookID: String
    public let observedVideoSHA256: String
    public let observedPDFSHA256: String
    public let videoSHAMatchesExpected: Bool?
    public let pdfSHAMatchesExpected: Bool?
    public let outputPageCount: Int
    public let machineGateAssessment: FormalGoldenMachineAssessment
    public let formalGoldenVerdict: String

    public init(
        schemaVersion: Int,
        bookID: String,
        observedVideoSHA256: String,
        observedPDFSHA256: String,
        videoSHAMatchesExpected: Bool?,
        pdfSHAMatchesExpected: Bool?,
        outputPageCount: Int,
        machineGateAssessment: FormalGoldenMachineAssessment,
        formalGoldenVerdict: String
    ) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.observedVideoSHA256 = observedVideoSHA256
        self.observedPDFSHA256 = observedPDFSHA256
        self.videoSHAMatchesExpected = videoSHAMatchesExpected
        self.pdfSHAMatchesExpected = pdfSHAMatchesExpected
        self.outputPageCount = outputPageCount
        self.machineGateAssessment = machineGateAssessment
        self.formalGoldenVerdict = formalGoldenVerdict
    }
}

public struct FormalGoldenFinalAssessment: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bookID: String
    public let executionReportSHA256: String
    public let reviewer: String
    public let reviewedAt: String
    public let pageCount: Int
    public let visualPassCount: Int
    public let ocrPassCount: Int
    public let pendingPageSequences: [Int]
    public let failedPageSequences: [Int]
    public let blockingReasons: [String]
    public let verdict: String

    public init(
        schemaVersion: Int = 1,
        bookID: String,
        executionReportSHA256: String,
        reviewer: String,
        reviewedAt: String,
        pageCount: Int,
        visualPassCount: Int,
        ocrPassCount: Int,
        pendingPageSequences: [Int],
        failedPageSequences: [Int],
        blockingReasons: [String],
        verdict: String
    ) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.executionReportSHA256 = executionReportSHA256
        self.reviewer = reviewer
        self.reviewedAt = reviewedAt
        self.pageCount = pageCount
        self.visualPassCount = visualPassCount
        self.ocrPassCount = ocrPassCount
        self.pendingPageSequences = pendingPageSequences
        self.failedPageSequences = failedPageSequences
        self.blockingReasons = blockingReasons
        self.verdict = verdict
    }
}

public enum FormalGoldenReviewFinalizer {
    public static let preconditionNotMet = "FORMAL_GOLDEN_PRECONDITION_NOT_MET"
    public static let reviewBindingFail = "FORMAL_GOLDEN_FAIL_REVIEW_BINDING"
    public static let humanReviewPending = "PENDING_HUMAN_VISUAL_OCR_REVIEW"
    public static let humanReviewFail = "FORMAL_GOLDEN_FAIL_HUMAN_REVIEW"
    public static let formalGoldenPass = "FORMAL_GOLDEN_PASS"

    public static func makeTemplate(
        execution: FormalGoldenExecutionSnapshot,
        executionReportSHA256: String
    ) -> FormalGoldenHumanReview {
        FormalGoldenHumanReview(
            bookID: execution.bookID,
            executionReportSHA256: executionReportSHA256.lowercased(),
            videoSHA256: execution.observedVideoSHA256.lowercased(),
            pdfSHA256: execution.observedPDFSHA256.lowercased(),
            reviewer: "",
            reviewedAt: "",
            reviewComplete: false,
            pages: (1...max(0, execution.outputPageCount)).map {
                FormalGoldenReviewPageDecision(
                    sequence: $0,
                    visualCorrection: .pending,
                    ocrSemantic: .pending
                )
            }
        )
    }

    public static func evaluate(
        execution: FormalGoldenExecutionSnapshot,
        executionReportSHA256: String,
        review: FormalGoldenHumanReview
    ) -> FormalGoldenFinalAssessment {
        var bindingReasons: [String] = []
        var preconditionReasons: [String] = []

        if execution.schemaVersion < 5 { preconditionReasons.append("execution_report_schema_before_review_binding_v5") }
        if execution.formalGoldenVerdict != humanReviewPending {
            preconditionReasons.append("execution_report_not_waiting_for_human_review")
        }
        if execution.machineGateAssessment.verdict != FormalGoldenMachineGate.machinePassHumanReviewPending {
            preconditionReasons.append("machine_gate_not_passed")
        }
        if !execution.machineGateAssessment.blockingReasons.isEmpty {
            preconditionReasons.append("machine_gate_blocking_reasons_present")
        }
        if execution.videoSHAMatchesExpected != true { preconditionReasons.append("video_sha_not_verified") }
        if execution.pdfSHAMatchesExpected != true { preconditionReasons.append("pdf_sha_not_verified") }

        let reportSHA = executionReportSHA256.lowercased()
        if !isSHA256(reportSHA) { bindingReasons.append("invalid_execution_report_sha256") }
        if review.schemaVersion != 1 { bindingReasons.append("unsupported_review_schema") }
        if review.bookID != execution.bookID { bindingReasons.append("review_book_id_mismatch") }
        if review.executionReportSHA256.lowercased() != reportSHA { bindingReasons.append("review_execution_report_sha_mismatch") }
        if review.videoSHA256.lowercased() != execution.observedVideoSHA256.lowercased() { bindingReasons.append("review_video_sha_mismatch") }
        if review.pdfSHA256.lowercased() != execution.observedPDFSHA256.lowercased() { bindingReasons.append("review_pdf_sha_mismatch") }

        let sequences = review.pages.map(\.sequence)
        if Set(sequences).count != sequences.count { bindingReasons.append("duplicate_review_page_sequence") }
        if review.pages.count != execution.outputPageCount { bindingReasons.append("review_page_count_mismatch") }
        if sequences.sorted() != Array(1...max(0, execution.outputPageCount)) { bindingReasons.append("review_page_sequence_not_contiguous") }

        let visualPass = review.pages.filter { $0.visualCorrection == .pass }.count
        let ocrPass = review.pages.filter { $0.ocrSemantic == .pass }.count
        let pending = review.pages.filter {
            $0.visualCorrection == .pending || $0.ocrSemantic == .pending
        }.map(\.sequence).sorted()
        let failed = review.pages.filter {
            $0.visualCorrection == .fail || $0.ocrSemantic == .fail
        }.map(\.sequence).sorted()

        let verdict: String
        let blockers: [String]
        if !bindingReasons.isEmpty {
            verdict = reviewBindingFail
            blockers = bindingReasons.sorted()
        } else if !preconditionReasons.isEmpty {
            verdict = preconditionNotMet
            blockers = preconditionReasons.sorted()
        } else if !failed.isEmpty {
            verdict = humanReviewFail
            blockers = ["human_review_page_failure"]
        } else if !review.reviewComplete || review.reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isISO8601(review.reviewedAt) || !pending.isEmpty {
            verdict = humanReviewPending
            var reasons: [String] = []
            if !review.reviewComplete { reasons.append("review_complete_not_acknowledged") }
            if review.reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { reasons.append("reviewer_missing") }
            if !isISO8601(review.reviewedAt) { reasons.append("reviewed_at_missing_or_invalid") }
            if !pending.isEmpty { reasons.append("review_pages_pending") }
            blockers = reasons.sorted()
        } else if visualPass != execution.outputPageCount || ocrPass != execution.outputPageCount {
            verdict = humanReviewPending
            blockers = ["not_all_review_dimensions_passed"]
        } else {
            verdict = formalGoldenPass
            blockers = []
        }

        return FormalGoldenFinalAssessment(
            bookID: execution.bookID,
            executionReportSHA256: reportSHA,
            reviewer: review.reviewer,
            reviewedAt: review.reviewedAt,
            pageCount: execution.outputPageCount,
            visualPassCount: visualPass,
            ocrPassCount: ocrPass,
            pendingPageSequences: pending,
            failedPageSequences: failed,
            blockingReasons: blockers,
            verdict: verdict
        )
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            ($0.value >= 48 && $0.value <= 57) || ($0.value >= 97 && $0.value <= 102)
        }
    }

    private static func isISO8601(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return ISO8601DateFormatter().date(from: value) != nil
    }
}
