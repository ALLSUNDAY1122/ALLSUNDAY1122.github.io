import Foundation
import ProductFlow
import Recovery
import ReviewCore

public enum RecoveryProductReviewWorkflowError: LocalizedError {
    case unknownReviewItem(String)
    case recoveryActionRequiresPipelineRerun(ProductReviewDecision)
    case recoveryDecisionRejected(String)

    public var errorDescription: String? {
        switch self {
        case .unknownReviewItem(let id): return "Unknown review item: \(id)"
        case .recoveryActionRequiresPipelineRerun(let decision): return "\(decision.rawValue) requires a pipeline rerun/recapture and cannot be marked complete by the review list alone."
        case .recoveryDecisionRejected(let id): return "Recovery core rejected duplicate or stale review decision: \(id)"
        }
    }
}

/// ProductFlow-facing adapter backed by Worker 4's ReviewCore/Recovery semantics.
/// Terminal Accept/Exclude decisions resolve through the canonical recovery
/// queue. Rerun/re-OCR/retake remain fail-closed until the orchestration layer
/// explicitly performs the requested work; the UI cannot falsely mark them done.
public actor RecoveryProductReviewWorkflow: ProductReviewWorkflow {
    private var adapter: AppShellReviewAdapter
    private var productItemsByID: [String: ProductReviewItem]
    private var reviewIDByProductID: [String: String]

    public init(items: [ProductReviewItem]) {
        var localAdapter = AppShellReviewAdapter()
        var itemMap: [String: ProductReviewItem] = [:]
        var reviewMap: [String: String] = [:]

        for item in items {
            itemMap[item.id] = item
            let displayPage = item.pageIDs.first ?? "book"
            let syntheticPageID = "\(displayPage)#\(item.id)"
            let source: ReviewSource = item.reason.localizedCaseInsensitiveContains("ocr") ? .ocr :
                (item.reason.localizedCaseInsensitiveContains("audit") || item.reason.localizedCaseInsensitiveContains("page") ? .pageAudit : .stageFailure)
            let reason = "product_id=\(item.id) | \(item.reason) | \(item.detail)"
            _ = localAdapter.ingest(.init(
                bookID: "product-flow",
                pageID: syntheticPageID,
                source: source,
                outcome: .lowConfidence,
                reason: reason,
                confidence: nil
            ))
            if let review = localAdapter.core.pendingReviewItems().first(where: { $0.pageID == syntheticPageID }) {
                reviewMap[item.id] = review.reviewID
            }
        }

        self.adapter = localAdapter
        self.productItemsByID = itemMap
        self.reviewIDByProductID = reviewMap
    }

    public func unresolvedItems() async -> [ProductReviewItem] {
        let pendingIDs = Set(adapter.core.pendingReviewItems().map(\.reviewID))
        return productItemsByID.values
            .filter { item in
                guard let reviewID = reviewIDByProductID[item.id] else { return false }
                return pendingIDs.contains(reviewID)
            }
            .sorted { lhs, rhs in
                let left = lhs.pageIDs.first ?? lhs.id
                let right = rhs.pageIDs.first ?? rhs.id
                return left == right ? lhs.id < rhs.id : left < right
            }
    }

    public func apply(decision: ProductReviewDecision, to itemID: String) async throws {
        guard productItemsByID[itemID] != nil,
              let reviewID = reviewIDByProductID[itemID] else {
            throw RecoveryProductReviewWorkflowError.unknownReviewItem(itemID)
        }

        switch decision {
        case .accept:
            guard adapter.decide(reviewID: reviewID, decision: .accept) != nil else {
                throw RecoveryProductReviewWorkflowError.recoveryDecisionRejected(itemID)
            }
        case .exclude:
            guard adapter.decide(reviewID: reviewID, decision: .exclude) != nil else {
                throw RecoveryProductReviewWorkflowError.recoveryDecisionRejected(itemID)
            }
        case .deferDecision:
            // Hold remains unresolved by design.
            return
        case .reprocess, .reocr, .retake:
            throw RecoveryProductReviewWorkflowError.recoveryActionRequiresPipelineRerun(decision)
        }
    }
}
