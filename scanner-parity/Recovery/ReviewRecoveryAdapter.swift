import Foundation

public struct RecoveryPageEvent: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable { case completed, lowConfidence, failed }
    public let bookID: String
    public let pageID: String
    public let sourceTimeMS: Int?
    public let originalImageRef: String?
    public let source: ReviewSource
    public let outcome: Outcome
    public let reason: String?
    public let confidence: Double?

    public init(bookID: String, pageID: String, sourceTimeMS: Int? = nil, originalImageRef: String? = nil, source: ReviewSource, outcome: Outcome, reason: String? = nil, confidence: Double? = nil) {
        self.bookID = bookID; self.pageID = pageID; self.sourceTimeMS = sourceTimeMS; self.originalImageRef = originalImageRef; self.source = source; self.outcome = outcome; self.reason = reason; self.confidence = confidence
    }
}

public struct ReviewRecoveryAdapter: Sendable {
    private(set) public var ledger: RecoveryLedger

    public init(checkpoint: RecoveryCheckpoint? = nil) { self.ledger = RecoveryLedger(checkpoint: checkpoint) }

    @discardableResult
    public mutating func consume(_ event: RecoveryPageEvent) -> Bool {
        guard ledger.shouldProcess(pageID: event.pageID) else { return false }
        switch event.outcome {
        case .completed:
            ledger.markCompleted(pageID: event.pageID, sourceTimeMS: event.sourceTimeMS)
        case .lowConfidence, .failed:
            let item = ReviewItem(bookID: event.bookID, pageID: event.pageID, source: event.source, reason: event.reason ?? event.outcome.rawValue, confidence: event.confidence, originalImageRef: event.originalImageRef, sourceTimeMS: event.sourceTimeMS)
            ledger.isolate(item)
        }
        return true
    }

    @discardableResult
    public mutating func apply(reviewID: String, decision: ReviewDecision, replacementPageID: String? = nil, note: String? = nil) -> Bool {
        let accepted = ledger.apply(.init(reviewID: reviewID, decision: decision, replacementPageID: replacementPageID, note: note))
        guard accepted else { return false }
        if decision == .accept, let pendingPage = ledger.reviewQueue.snapshot.resolutions[reviewID]?.replacementPageID ?? replacementPageID {
            ledger.markCompleted(pageID: pendingPage, sourceTimeMS: nil)
        }
        return true
    }

    public func pendingReviewItems() -> [ReviewItem] { ledger.reviewQueue.snapshot.pending }
    public func checkpoint(bookID: String) -> RecoveryCheckpoint { ledger.checkpoint(bookID: bookID) }
}
