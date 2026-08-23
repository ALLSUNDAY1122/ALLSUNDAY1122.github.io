import Foundation

public enum PackageTextLayout: String, Codable, Sendable, CaseIterable {
    case vertical
    case horizontal
    case mixed
    case unknown
}

public struct PackageOCRQualityPage: Codable, Equatable, Sendable {
    public let pageID: String
    public let sequence: Int
    public let layout: PackageTextLayout
    public let text: String
    public let confidence: Double
    public let needsReview: Bool
    public let sourceTimeMS: Int64?

    public init(pageID: String, sequence: Int, layout: PackageTextLayout, text: String, confidence: Double, needsReview: Bool, sourceTimeMS: Int64?) {
        self.pageID = pageID
        self.sequence = sequence
        self.layout = layout
        self.text = text
        self.confidence = confidence
        self.needsReview = needsReview
        self.sourceTimeMS = sourceTimeMS
    }
}

public struct AIIngestionRecord: Codable, Equatable, Sendable {
    public let sequence: Int
    public let pageID: String
    public let imagePath: String
    public let textPath: String
    public let sourceTimeMS: Int64
    public let needsReview: Bool
}

public enum PackageQualitySeverity: String, Codable, Sendable {
    case warning
    case error
}

public enum PackageQualityIssueCode: String, Codable, Sendable {
    case integrityFailure
    case pdfTextLayerUnavailable
    case pdfTextLayerMissing
    case pdfTextOrderMismatch
    case markdownBoundaryMismatch
    case textBoundaryMismatch
    case ocrLowQualityUnreviewed
    case ocrReviewRequired
    case ocrUnknownLayoutUnreviewed
    case manifestLineageMissing
    case manifestSchemaUnsupported
}

public struct PackageQualityIssue: Codable, Equatable, Sendable {
    public let code: PackageQualityIssueCode
    public let severity: PackageQualitySeverity
    public let pageID: String?
    public let sequence: Int?
    public let detail: String

    public init(code: PackageQualityIssueCode, severity: PackageQualitySeverity = .error, pageID: String? = nil, sequence: Int? = nil, detail: String) {
        self.code = code
        self.severity = severity
        self.pageID = pageID
        self.sequence = sequence
        self.detail = detail
    }
}

public struct PackageQualityMetrics: Codable, Equatable, Sendable {
    public let pdfTextLayerCoverage: Double?
    public let pdfTextOrderAccuracy: Double?
    public let markdownBoundaryAccuracy: Double
    public let textBoundaryAccuracy: Double
    public let ocrReviewedOrAcceptedRatio: Double
    public let lineageCoverage: Double
}

public struct PackageQualityReport: Codable, Equatable, Sendable {
    public let bookID: String?
    public let valid: Bool
    public let metrics: PackageQualityMetrics
    public let issues: [PackageQualityIssue]
    public let ingestionRecords: [AIIngestionRecord]

    public init(bookID: String?, valid: Bool, metrics: PackageQualityMetrics, issues: [PackageQualityIssue], ingestionRecords: [AIIngestionRecord]) {
        self.bookID = bookID
        self.valid = valid
        self.metrics = metrics
        self.issues = issues
        self.ingestionRecords = ingestionRecords
    }
}

public protocol PDFTextLayerInspecting: Sendable {
    func pageTexts(at url: URL) throws -> [String]
}

public enum PDFTextLayerInspectorError: Error {
    case unsupported
    case unreadable
}
