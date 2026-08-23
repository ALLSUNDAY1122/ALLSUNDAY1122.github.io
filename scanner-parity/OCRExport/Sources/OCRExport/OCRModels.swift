import Foundation

public enum OCRLayout: String, Codable, Sendable, CaseIterable {
    case vertical
    case horizontal
    case mixed
    case unknown
}

public struct OCRRect: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct OCRBlock: Codable, Sendable, Equatable {
    public let text: String
    public let confidence: Double
    public let boundingBox: OCRRect
    public let sourceIndex: Int

    public init(text: String, confidence: Double, boundingBox: OCRRect, sourceIndex: Int) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.sourceIndex = sourceIndex
    }

    enum CodingKeys: String, CodingKey {
        case text
        case confidence
        case boundingBox = "bounding_box"
        case sourceIndex = "source_index"
    }
}

public struct OCRPage: Codable, Sendable, Equatable {
    public let pageID: String
    public let language: String
    public let layout: OCRLayout
    public let text: String
    public let blocks: [OCRBlock]
    public let ocrConfidence: Double
    public let engine: String
    public let engineVersion: String
    public let needsReview: Bool
    public let rotationDegrees: Int
    public let sourceTimeMS: Int64?

    public init(
        pageID: String,
        language: String = "ja-JP",
        layout: OCRLayout,
        text: String,
        blocks: [OCRBlock],
        ocrConfidence: Double,
        engine: String,
        engineVersion: String,
        needsReview: Bool,
        rotationDegrees: Int = 0,
        sourceTimeMS: Int64? = nil
    ) {
        self.pageID = pageID
        self.language = language
        self.layout = layout
        self.text = text
        self.blocks = blocks
        self.ocrConfidence = ocrConfidence
        self.engine = engine
        self.engineVersion = engineVersion
        self.needsReview = needsReview
        self.rotationDegrees = rotationDegrees
        self.sourceTimeMS = sourceTimeMS
    }

    enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
        case language
        case layout
        case text
        case blocks
        case ocrConfidence = "ocr_confidence"
        case engine
        case engineVersion = "engine_version"
        case needsReview = "needs_review"
        case rotationDegrees = "rotation_degrees"
        case sourceTimeMS = "source_time_ms"
    }
}

public struct OCRQuality: Sendable, Equatable {
    public let score: Double
    public let meanConfidence: Double
    public let japaneseRatio: Double
    public let noiseRatio: Double
    public let fragmentRatio: Double
    public let meaningfulLineRatio: Double
    public let needsReview: Bool

    public init(
        score: Double,
        meanConfidence: Double,
        japaneseRatio: Double,
        noiseRatio: Double,
        fragmentRatio: Double,
        meaningfulLineRatio: Double,
        needsReview: Bool
    ) {
        self.score = score
        self.meanConfidence = meanConfidence
        self.japaneseRatio = japaneseRatio
        self.noiseRatio = noiseRatio
        self.fragmentRatio = fragmentRatio
        self.meaningfulLineRatio = meaningfulLineRatio
        self.needsReview = needsReview
    }
}

public struct OCRPageArtifact: Sendable {
    public let sequence: Int
    public let imageURL: URL
    public let ocrPage: OCRPage

    public init(sequence: Int, imageURL: URL, ocrPage: OCRPage) {
        self.sequence = sequence
        self.imageURL = imageURL
        self.ocrPage = ocrPage
    }
}

public struct BookManifest: Codable, Sendable, Equatable {
    public struct Page: Codable, Sendable, Equatable {
        public let sequence: Int
        public let pageID: String
        public let imagePath: String
        public let textPath: String
        public let sourceTimeMS: Int64?
        public let ocrConfidence: Double
        public let needsReview: Bool
        public let engine: String
        public let layout: OCRLayout

        enum CodingKeys: String, CodingKey {
            case sequence
            case pageID = "page_id"
            case imagePath = "image_path"
            case textPath = "text_path"
            case sourceTimeMS = "source_time_ms"
            case ocrConfidence = "ocr_confidence"
            case needsReview = "needs_review"
            case engine
            case layout
        }
    }

    public let schemaVersion: Int
    public let bookID: String
    public let createdAt: String
    public let pages: [Page]

    public init(schemaVersion: Int, bookID: String, createdAt: String, pages: [Page]) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.createdAt = createdAt
        self.pages = pages
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case bookID = "book_id"
        case createdAt = "created_at"
        case pages
    }
}
