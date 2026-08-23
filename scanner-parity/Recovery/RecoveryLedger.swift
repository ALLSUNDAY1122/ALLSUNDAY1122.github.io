import Foundation
import ReviewCore

public struct RecoveryCheckpoint: Codable, Hashable, Sendable {
    public let bookID: String
    public let completedPageIDs: Set<String>
    public let reviewSnapshot: ReviewQueueSnapshot
    public let lastSourceTimeMS: Int?

    public init(bookID: String,
                completedPageIDs: Set<String>,
                reviewSnapshot: ReviewQueueSnapshot,
                lastSourceTimeMS: Int?) {
        self.bookID = bookID
        self.completedPageIDs = completedPageIDs
        self.reviewSnapshot = reviewSnapshot
        self.lastSourceTimeMS = lastSourceTimeMS
    }
}

public struct RecoveryLedger: Sendable {
    private(set) public var completedPageIDs: Set<String>
    private(set) public var reviewQueue: ReviewQueue
    private(set) public var lastSourceTimeMS: Int?

    public init(checkpoint: RecoveryCheckpoint? = nil) {
        if let checkpoint {
            self.completedPageIDs = checkpoint.completedPageIDs
            self.reviewQueue = ReviewQueue(snapshot: checkpoint.reviewSnapshot)
            self.lastSourceTimeMS = checkpoint.lastSourceTimeMS
        } else {
            self.completedPageIDs = []
            self.reviewQueue = ReviewQueue()
            self.lastSourceTimeMS = nil
        }
    }

    public func shouldProcess(pageID: String) -> Bool {
        !completedPageIDs.contains(pageID) && !reviewQueue.containsPending(pageID: pageID)
    }

    public mutating func markCompleted(pageID: String, sourceTimeMS: Int?) {
        completedPageIDs.insert(pageID)
        if let sourceTimeMS {
            lastSourceTimeMS = max(lastSourceTimeMS ?? sourceTimeMS, sourceTimeMS)
        }
    }

    public mutating func isolate(_ item: ReviewItem) {
        reviewQueue.enqueue(item)
    }

    public mutating func apply(_ resolution: ReviewResolution) -> Bool {
        reviewQueue.resolve(resolution)
    }

    public func checkpoint(bookID: String) -> RecoveryCheckpoint {
        RecoveryCheckpoint(
            bookID: bookID,
            completedPageIDs: completedPageIDs,
            reviewSnapshot: reviewQueue.snapshot,
            lastSourceTimeMS: lastSourceTimeMS
        )
    }
}
