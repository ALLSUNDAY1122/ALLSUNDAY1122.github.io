import Foundation

public enum PageAuditEvidenceSource: String, Codable, Sendable {
    case pageNumberOCR
    case imageSimilarity
    case textSimilarity
    case sourceTimeline
}

public struct NormalizedRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

public struct PageNumberObservation: Codable, Equatable, Sendable {
    public var pageID: String
    public var value: Int
    public var confidence: Double
    public var rawText: String
    public var boundingBox: NormalizedRect
    public var rotationDegrees: Int
    public var score: Double

    public init(pageID: String, value: Int, confidence: Double, rawText: String, boundingBox: NormalizedRect, rotationDegrees: Int = 0, score: Double) {
        self.pageID = pageID
        self.value = value
        self.confidence = confidence
        self.rawText = rawText
        self.boundingBox = boundingBox
        self.rotationDegrees = rotationDegrees
        self.score = score
    }
}

public struct PageAuditInput: Codable, Equatable, Sendable {
    public var pageID: String
    public var sourceTimeMs: Int64
    public var pageNumber: PageNumberObservation?
    public var perceptualHash: UInt64?
    public var text: String?

    public init(pageID: String, sourceTimeMs: Int64, pageNumber: PageNumberObservation? = nil, perceptualHash: UInt64? = nil, text: String? = nil) {
        self.pageID = pageID
        self.sourceTimeMs = sourceTimeMs
        self.pageNumber = pageNumber
        self.perceptualHash = perceptualHash
        self.text = text
    }
}

public struct DuplicateGroup: Codable, Equatable, Sendable {
    public var pageIDs: [String]
    public var confidence: Double
    public var evidence: [PageAuditEvidenceSource]
}

public struct MissingPageSuspicion: Codable, Equatable, Sendable {
    public var afterPageID: String
    public var beforePageID: String
    public var expectedPageNumbers: [Int]
    public var confidence: Double
    public var evidence: [PageAuditEvidenceSource]
}

public struct ReversalEvent: Codable, Equatable, Sendable {
    public var leftPageID: String
    public var rightPageID: String
    public var observedNumbers: [Int]
    public var confidence: Double
    public var evidence: [PageAuditEvidenceSource]
}

public enum PageAutoFixKind: String, Codable, Sendable {
    case removeDuplicate
    case swapAdjacentPages
}

public struct PageAutoFix: Codable, Equatable, Sendable {
    public var kind: PageAutoFixKind
    public var pageIDs: [String]
    public var confidence: Double
    public var rationale: String
}

public enum PageReviewReason: String, Codable, Sendable {
    case lowConfidencePageNumber
    case missingPage
    case possibleDuplicate
    case possibleReversal
    case conflictingEvidence
}

public struct PageReviewItem: Codable, Equatable, Sendable {
    public var pageIDs: [String]
    public var reason: PageReviewReason
    public var confidence: Double
    public var detail: String
}

public struct PageAuditResult: Codable, Equatable, Sendable {
    public var orderedPageIDs: [String]
    public var pageNumberObservations: [PageNumberObservation]
    public var duplicateGroups: [DuplicateGroup]
    public var missingPageSuspicions: [MissingPageSuspicion]
    public var reversalEvents: [ReversalEvent]
    public var autoFixes: [PageAutoFix]
    public var reviewRequired: [PageReviewItem]

    public init(orderedPageIDs: [String], pageNumberObservations: [PageNumberObservation], duplicateGroups: [DuplicateGroup], missingPageSuspicions: [MissingPageSuspicion], reversalEvents: [ReversalEvent], autoFixes: [PageAutoFix], reviewRequired: [PageReviewItem]) {
        self.orderedPageIDs = orderedPageIDs
        self.pageNumberObservations = pageNumberObservations
        self.duplicateGroups = duplicateGroups
        self.missingPageSuspicions = missingPageSuspicions
        self.reversalEvents = reversalEvents
        self.autoFixes = autoFixes
        self.reviewRequired = reviewRequired
    }
}
