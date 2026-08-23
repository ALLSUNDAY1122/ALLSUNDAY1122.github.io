import Foundation

public enum PackageIntegritySeverity: String, Codable, Sendable {
    case warning
    case error
}

public enum PackageIntegrityIssueCode: String, Codable, Sendable {
    case manifestMissing
    case manifestUnreadable
    case emptyManifest
    case duplicateSequence
    case duplicatePageID
    case duplicateImagePath
    case duplicateTextPath
    case nonContiguousSequence
    case manifestOrderMismatch
    case unsafeRelativePath
    case missingImageFile
    case missingTextFile
    case unreadableTextFile
    case searchablePDFMissing
    case searchablePDFUnreadable
    case pdfPageCountMismatch
    case aggregateMarkdownMissing
    case aggregateTextMissing
}

public struct PackageIntegrityIssue: Codable, Equatable, Sendable {
    public let code: PackageIntegrityIssueCode
    public let severity: PackageIntegritySeverity
    public let pageID: String?
    public let sequence: Int?
    public let detail: String

    public init(code: PackageIntegrityIssueCode, severity: PackageIntegritySeverity = .error, pageID: String? = nil, sequence: Int? = nil, detail: String) {
        self.code = code
        self.severity = severity
        self.pageID = pageID
        self.sequence = sequence
        self.detail = detail
    }
}

public struct PackageManifestSnapshot: Codable, Equatable, Sendable {
    public struct Page: Codable, Equatable, Sendable {
        public let sequence: Int
        public let pageID: String
        public let imagePath: String
        public let textPath: String
        public let sourceTimeMS: Int64?
        public let needsReview: Bool

        public init(sequence: Int, pageID: String, imagePath: String, textPath: String, sourceTimeMS: Int64?, needsReview: Bool) {
            self.sequence = sequence
            self.pageID = pageID
            self.imagePath = imagePath
            self.textPath = textPath
            self.sourceTimeMS = sourceTimeMS
            self.needsReview = needsReview
        }

        enum CodingKeys: String, CodingKey {
            case sequence
            case pageID = "page_id"
            case imagePath = "image_path"
            case textPath = "text_path"
            case sourceTimeMS = "source_time_ms"
            case needsReview = "needs_review"
        }
    }

    public let schemaVersion: Int
    public let bookID: String
    public let pages: [Page]

    public init(schemaVersion: Int, bookID: String, pages: [Page]) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.pages = pages
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case bookID = "book_id"
        case pages
    }
}

public struct PackageIntegritySummary: Codable, Equatable, Sendable {
    public let manifestPageCount: Int
    public let imageReferenceCount: Int
    public let textReferenceCount: Int
    public let pdfPageCount: Int?
    public let errorCount: Int
    public let warningCount: Int
    public let reviewPageIDs: [String]

    public init(manifestPageCount: Int, imageReferenceCount: Int, textReferenceCount: Int, pdfPageCount: Int?, errorCount: Int, warningCount: Int, reviewPageIDs: [String]) {
        self.manifestPageCount = manifestPageCount
        self.imageReferenceCount = imageReferenceCount
        self.textReferenceCount = textReferenceCount
        self.pdfPageCount = pdfPageCount
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.reviewPageIDs = reviewPageIDs
    }
}

public struct PackageIntegrityReport: Codable, Equatable, Sendable {
    public let bookID: String?
    public let valid: Bool
    public let summary: PackageIntegritySummary
    public let issues: [PackageIntegrityIssue]

    public init(bookID: String?, valid: Bool, summary: PackageIntegritySummary, issues: [PackageIntegrityIssue]) {
        self.bookID = bookID
        self.valid = valid
        self.summary = summary
        self.issues = issues
    }
}

public protocol PackagePDFInspecting: Sendable {
    func pageCount(at url: URL) throws -> Int
}

public enum PackagePDFInspectorError: Error {
    case unsupported
    case unreadable
}
