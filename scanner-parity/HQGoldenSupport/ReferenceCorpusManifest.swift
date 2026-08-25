import Foundation

public struct ReferenceCorpusGroup: Codable, Equatable, Sendable {
    public let id: String
    public let referencePageNumbers: [Int]

    public init(id: String, referencePageNumbers: [Int]) {
        self.id = id
        self.referencePageNumbers = referencePageNumbers
    }
}

public struct ReferenceCorpusManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let datasetID: String
    public let referencePDFSHA256: String
    public let referencePDFPageCount: Int
    public let negativeReferencePageNumbers: [Int]
    public let groups: [ReferenceCorpusGroup]

    public init(
        schemaVersion: Int = 1,
        datasetID: String,
        referencePDFSHA256: String,
        referencePDFPageCount: Int,
        negativeReferencePageNumbers: [Int],
        groups: [ReferenceCorpusGroup]
    ) {
        self.schemaVersion = schemaVersion
        self.datasetID = datasetID
        self.referencePDFSHA256 = referencePDFSHA256
        self.referencePDFPageCount = referencePDFPageCount
        self.negativeReferencePageNumbers = negativeReferencePageNumbers
        self.groups = groups
    }

    public func validate(actualPDFPageCount: Int, actualPDFSHA256: String) throws {
        guard schemaVersion == 1 else {
            throw ReferenceCorpusManifestError.unsupportedSchema(schemaVersion)
        }
        guard !datasetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReferenceCorpusManifestError.emptyDatasetID
        }
        guard referencePDFPageCount > 0,
              referencePDFPageCount == actualPDFPageCount else {
            throw ReferenceCorpusManifestError.pageCountMismatch(
                expected: referencePDFPageCount,
                actual: actualPDFPageCount
            )
        }
        guard referencePDFSHA256.caseInsensitiveCompare(actualPDFSHA256) == .orderedSame else {
            throw ReferenceCorpusManifestError.pdfSHAMismatch(
                expected: referencePDFSHA256,
                actual: actualPDFSHA256
            )
        }
        guard !groups.isEmpty else { throw ReferenceCorpusManifestError.emptyGroups }

        var seenGroupIDs = Set<String>()
        var assignments: [Int: String] = [:]

        func assign(_ pageNumber: Int, owner: String) throws {
            guard pageNumber >= 1, pageNumber <= referencePDFPageCount else {
                throw ReferenceCorpusManifestError.pageOutOfRange(pageNumber)
            }
            if let existing = assignments[pageNumber] {
                throw ReferenceCorpusManifestError.pageAssignedMoreThanOnce(
                    pageNumber: pageNumber,
                    firstOwner: existing,
                    secondOwner: owner
                )
            }
            assignments[pageNumber] = owner
        }

        for pageNumber in negativeReferencePageNumbers {
            try assign(pageNumber, owner: "negative")
        }

        for group in groups {
            let trimmedID = group.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { throw ReferenceCorpusManifestError.emptyGroupID }
            guard seenGroupIDs.insert(trimmedID).inserted else {
                throw ReferenceCorpusManifestError.duplicateGroupID(trimmedID)
            }
            guard !group.referencePageNumbers.isEmpty else {
                throw ReferenceCorpusManifestError.emptyGroup(trimmedID)
            }
            for pageNumber in group.referencePageNumbers {
                try assign(pageNumber, owner: trimmedID)
            }
        }

        let expected = Set(1...referencePDFPageCount)
        let assigned = Set(assignments.keys)
        let missing = expected.subtracting(assigned).sorted()
        guard missing.isEmpty else {
            throw ReferenceCorpusManifestError.unassignedPages(missing)
        }
    }
}

public enum ReferenceCorpusManifestError: Error, LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case emptyDatasetID
    case pageCountMismatch(expected: Int, actual: Int)
    case pdfSHAMismatch(expected: String, actual: String)
    case emptyGroups
    case emptyGroupID
    case duplicateGroupID(String)
    case emptyGroup(String)
    case pageOutOfRange(Int)
    case pageAssignedMoreThanOnce(pageNumber: Int, firstOwner: String, secondOwner: String)
    case unassignedPages([Int])

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "Unsupported reference-corpus manifest schema: \(schema)."
        case .emptyDatasetID:
            return "Reference-corpus manifest datasetID is empty."
        case .pageCountMismatch(let expected, let actual):
            return "Reference-corpus PDF page-count mismatch: expected=\(expected), actual=\(actual)."
        case .pdfSHAMismatch(let expected, let actual):
            return "Reference-corpus PDF SHA mismatch: expected=\(expected), actual=\(actual)."
        case .emptyGroups:
            return "Reference-corpus manifest has no canonical groups."
        case .emptyGroupID:
            return "Reference-corpus manifest contains an empty group ID."
        case .duplicateGroupID(let id):
            return "Reference-corpus manifest repeats group ID: \(id)."
        case .emptyGroup(let id):
            return "Reference-corpus group \(id) has no source reference pages."
        case .pageOutOfRange(let pageNumber):
            return "Reference-corpus page number is out of range: \(pageNumber)."
        case .pageAssignedMoreThanOnce(let pageNumber, let firstOwner, let secondOwner):
            return "Reference-corpus page \(pageNumber) is assigned more than once: \(firstOwner), \(secondOwner)."
        case .unassignedPages(let pages):
            return "Reference-corpus manifest leaves PDF page(s) unassigned: \(pages.map(String.init).joined(separator: ","))."
        }
    }
}
