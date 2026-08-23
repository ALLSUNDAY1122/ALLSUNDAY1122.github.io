import Foundation
import ReviewCore

public enum ReviewRecoveryAction: Codable, Hashable, Sendable {
    case retryStage(pageID: String)
    case rerunOCR(pageID: String)
    case requestRecapture(pageID: String, originalImageRef: String?)
    case keepDeferred(pageID: String)
    case exclude(pageID: String)
    case acceptCurrent(pageID: String)
}

public struct ReviewRecoveryViewState: Codable, Hashable, Sendable {
    public let pendingCount: Int
    public let current: ReviewItem?
    public let completedPageCount: Int
    public let lastSourceTimeMS: Int?
}

public struct AppShellReviewAdapter: Sendable {
    private(set) public var core: ReviewRecoveryAdapter

    public init(checkpoint: RecoveryCheckpoint? = nil) {
        self.core = ReviewRecoveryAdapter(checkpoint: checkpoint)
    }

    public var viewState: ReviewRecoveryViewState {
        ReviewRecoveryViewState(
            pendingCount: core.pendingReviewItems().count,
            current: core.pendingReviewItems().first,
            completedPageCount: core.ledger.completedPageIDs.count,
            lastSourceTimeMS: core.ledger.lastSourceTimeMS
        )
    }

    @discardableResult
    public mutating func ingest(_ event: RecoveryPageEvent) -> Bool {
        core.consume(event)
    }

    @discardableResult
    public mutating func decide(reviewID: String, decision: ReviewDecision, replacementPageID: String? = nil, note: String? = nil) -> ReviewRecoveryAction? {
        guard let item = core.pendingReviewItems().first(where: { $0.reviewID == reviewID }) else { return nil }
        guard core.apply(reviewID: reviewID, decision: decision, replacementPageID: replacementPageID, note: note) else { return nil }
        switch decision {
        case .retry: return .retryStage(pageID: item.pageID)
        case .reOCR: return .rerunOCR(pageID: item.pageID)
        case .recapture: return .requestRecapture(pageID: item.pageID, originalImageRef: item.originalImageRef)
        case .deferred: return .keepDeferred(pageID: item.pageID)
        case .exclude: return .exclude(pageID: item.pageID)
        case .accept: return .acceptCurrent(pageID: item.pageID)
        }
    }

    public func checkpoint(bookID: String) -> RecoveryCheckpoint { core.checkpoint(bookID: bookID) }
}
