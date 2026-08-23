import Foundation

public enum ReviewSource: String, Codable, Sendable {
    case pageAudit
    case ocr
    case stageFailure
}

public enum ReviewDecision: String, Codable, Sendable {
    case retry
    case reOCR
    case recapture
    case deferred = "defer"
    case exclude
    case accept
}

public struct ReviewItem: Codable, Hashable, Sendable {
    public let reviewID: String
    public let bookID: String
    public let pageID: String
    public let source: ReviewSource
    public let reason: String
    public let confidence: Double?
    public let originalImageRef: String?
    public let sourceTimeMS: Int?

    public init(bookID: String,
                pageID: String,
                source: ReviewSource,
                reason: String,
                confidence: Double? = nil,
                originalImageRef: String? = nil,
                sourceTimeMS: Int? = nil) {
        self.bookID = bookID
        self.pageID = pageID
        self.source = source
        self.reason = reason
        self.confidence = confidence
        self.originalImageRef = originalImageRef
        self.sourceTimeMS = sourceTimeMS
        self.reviewID = Self.stableID(bookID: bookID, pageID: pageID, source: source, reason: reason)
    }

    private static func stableID(bookID: String, pageID: String, source: ReviewSource, reason: String) -> String {
        let normalized = reason.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return [bookID, pageID, source.rawValue, normalized].joined(separator: "|")
    }
}

public struct ReviewResolution: Codable, Hashable, Sendable {
    public let reviewID: String
    public let decision: ReviewDecision
    public let replacementPageID: String?
    public let note: String?

    public init(reviewID: String,
                decision: ReviewDecision,
                replacementPageID: String? = nil,
                note: String? = nil) {
        self.reviewID = reviewID
        self.decision = decision
        self.replacementPageID = replacementPageID
        self.note = note
    }
}

public struct ReviewQueueSnapshot: Codable, Sendable {
    public var pending: [ReviewItem]
    public var resolutions: [String: ReviewResolution]

    public init(pending: [ReviewItem] = [], resolutions: [String: ReviewResolution] = [:]) {
        self.pending = pending
        self.resolutions = resolutions
    }
}

public struct ReviewQueue: Sendable {
    private(set) public var snapshot: ReviewQueueSnapshot

    public init(snapshot: ReviewQueueSnapshot = .init()) {
        self.snapshot = snapshot
    }

    public mutating func enqueue(_ item: ReviewItem) {
        guard snapshot.resolutions[item.reviewID] == nil else { return }
        guard !snapshot.pending.contains(where: { $0.reviewID == item.reviewID }) else { return }
        snapshot.pending.append(item)
        snapshot.pending.sort {
            if $0.sourceTimeMS != $1.sourceTimeMS {
                return ($0.sourceTimeMS ?? Int.max) < ($1.sourceTimeMS ?? Int.max)
            }
            return $0.pageID < $1.pageID
        }
    }

    @discardableResult
    public mutating func resolve(_ resolution: ReviewResolution) -> Bool {
        guard snapshot.resolutions[resolution.reviewID] == nil else { return false }
        guard snapshot.pending.contains(where: { $0.reviewID == resolution.reviewID }) else { return false }
        snapshot.pending.removeAll { $0.reviewID == resolution.reviewID }
        snapshot.resolutions[resolution.reviewID] = resolution
        return true
    }

    public func unresolvedPageIDs() -> [String] {
        Array(Set(snapshot.pending.map(\.pageID))).sorted()
    }
}
