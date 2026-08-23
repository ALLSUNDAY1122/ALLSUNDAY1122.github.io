import Foundation

/// Signals produced by the page-recognition layer. Keeping these optional allows
/// the E2E bridge to preserve a page even when OCR/hash extraction failed.
public struct PipelineAuditSignals: Codable, Equatable, Sendable {
    public var pageNumber: PageNumberObservation?
    public var perceptualHash: UInt64?
    public var text: String?

    public init(
        pageNumber: PageNumberObservation? = nil,
        perceptualHash: UInt64? = nil,
        text: String? = nil
    ) {
        self.pageNumber = pageNumber
        self.perceptualHash = perceptualHash
        self.text = text
    }
}

/// One page as it moves from frame extraction through correction into audit.
/// The source PageCandidate remains attached so source-time and source flags
/// cannot silently disappear at stage boundaries.
public struct PipelinePageRecord: Sendable, Equatable {
    public var pageID: String
    public var candidate: PageCandidate
    public var correction: CorrectedPageMetadata?
    public var correctedImageRef: String?
    public var auditSignals: PipelineAuditSignals
    public var stageFailure: String?

    public init(
        pageID: String,
        candidate: PageCandidate,
        correction: CorrectedPageMetadata?,
        correctedImageRef: String? = nil,
        auditSignals: PipelineAuditSignals = .init(),
        stageFailure: String? = nil
    ) {
        self.pageID = pageID
        self.candidate = candidate
        self.correction = correction
        self.correctedImageRef = correctedImageRef
        self.auditSignals = auditSignals
        self.stageFailure = stageFailure
    }
}

public struct PipelinePageLineage: Codable, Equatable, Sendable {
    public var pageID: String
    public var candidateID: String
    public var bookID: String
    public var sourceTimeMS: Int64
    public var sourceRangeMS: SourceRangeMS
    public var sourceFlags: [String]
    public var correctionFlags: [String]
    public var correctedImageRef: String?
    public var stageFailure: String?

    public init(
        pageID: String,
        candidateID: String,
        bookID: String,
        sourceTimeMS: Int64,
        sourceRangeMS: SourceRangeMS,
        sourceFlags: [String],
        correctionFlags: [String],
        correctedImageRef: String?,
        stageFailure: String?
    ) {
        self.pageID = pageID
        self.candidateID = candidateID
        self.bookID = bookID
        self.sourceTimeMS = sourceTimeMS
        self.sourceRangeMS = sourceRangeMS
        self.sourceFlags = sourceFlags
        self.correctionFlags = correctionFlags
        self.correctedImageRef = correctedImageRef
        self.stageFailure = stageFailure
    }
}

public struct PipelineBridgeResult: Sendable, Equatable {
    public var auditResult: PageAuditResult
    public var lineage: [PipelinePageLineage]

    public init(auditResult: PageAuditResult, lineage: [PipelinePageLineage]) {
        self.auditResult = auditResult
        self.lineage = lineage
    }
}

/// Adapter only: it does not redefine the Shared Contract or any stage model.
/// It connects the already-integrated public types and adds lineage/review
/// propagation required at stage boundaries.
public struct PipelineAuditBridge: Sendable {
    public var auditor: PageIntegrityAuditor
    public var lowBoundaryConfidenceThreshold: Double

    public init(
        auditor: PageIntegrityAuditor = .init(),
        lowBoundaryConfidenceThreshold: Double = 0.72
    ) {
        self.auditor = auditor
        self.lowBoundaryConfidenceThreshold = lowBoundaryConfidenceThreshold
    }

    public func makeAuditInput(from record: PipelinePageRecord) -> PageAuditInput {
        // A page-number observation belonging to a different page is conflicting
        // evidence. Never allow it to drive duplicate/order auto-fixes.
        let trustedPageNumber = record.auditSignals.pageNumber.flatMap { observation in
            observation.pageID == record.pageID ? observation : nil
        }
        return PageAuditInput(
            pageID: record.pageID,
            sourceTimeMs: record.candidate.sourceTimeMS,
            pageNumber: trustedPageNumber,
            perceptualHash: record.auditSignals.perceptualHash,
            text: record.auditSignals.text
        )
    }

    public func makeLineage(from record: PipelinePageRecord) -> PipelinePageLineage {
        PipelinePageLineage(
            pageID: record.pageID,
            candidateID: record.candidate.candidateID,
            bookID: record.candidate.bookID,
            sourceTimeMS: record.candidate.sourceTimeMS,
            sourceRangeMS: record.candidate.sourceRangeMS,
            sourceFlags: record.candidate.flags,
            correctionFlags: record.correction?.flags.map(\.rawValue) ?? [],
            correctedImageRef: record.correctedImageRef,
            stageFailure: record.stageFailure
        )
    }

    public func audit(_ records: [PipelinePageRecord]) -> PipelineBridgeResult {
        let inputs = records.map(makeAuditInput)
        var result = auditor.audit(inputs)
        var propagatedReview = result.reviewRequired

        for record in records {
            propagatedReview.append(contentsOf: bridgeReviewItems(for: record))
        }

        result.reviewRequired = Self.deduplicatedReview(propagatedReview)
        return PipelineBridgeResult(
            auditResult: result,
            lineage: records.map(makeLineage)
        )
    }

    private func bridgeReviewItems(for record: PipelinePageRecord) -> [PageReviewItem] {
        var items: [PageReviewItem] = []

        if let failure = record.stageFailure, !failure.isEmpty {
            items.append(PageReviewItem(
                pageIDs: [record.pageID],
                reason: .conflictingEvidence,
                confidence: 1,
                detail: "stage_failure: \(failure)"
            ))
        }

        if let observation = record.auditSignals.pageNumber,
           observation.pageID != record.pageID {
            items.append(PageReviewItem(
                pageIDs: [record.pageID],
                reason: .conflictingEvidence,
                confidence: 1,
                detail: "contract_mismatch: page_number.page_id does not match pipeline page_id"
            ))
        }

        guard let correction = record.correction else {
            if record.stageFailure == nil {
                items.append(PageReviewItem(
                    pageIDs: [record.pageID],
                    reason: .conflictingEvidence,
                    confidence: 1,
                    detail: "stage_failure: correction_metadata_missing"
                ))
            }
            return items
        }

        if correction.pageID != record.pageID || correction.candidateID != record.candidate.candidateID {
            items.append(PageReviewItem(
                pageIDs: [record.pageID],
                reason: .conflictingEvidence,
                confidence: 1,
                detail: "contract_mismatch: page_id/candidate_id lineage mismatch"
            ))
        }

        if correction.flags.contains(.lowBoundaryConfidence)
            || correction.qualityScores.boundaryConfidence < lowBoundaryConfidenceThreshold {
            items.append(PageReviewItem(
                pageIDs: [record.pageID],
                reason: .conflictingEvidence,
                confidence: max(0, min(1, 1 - correction.qualityScores.boundaryConfidence)),
                detail: "low_confidence: page boundary requires review"
            ))
        }

        return items
    }

    private static func deduplicatedReview(_ items: [PageReviewItem]) -> [PageReviewItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = item.reason.rawValue + ":" + item.pageIDs.sorted().joined(separator: "|") + ":" + item.detail
            return seen.insert(key).inserted
        }
    }
}
