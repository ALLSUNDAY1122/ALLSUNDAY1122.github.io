import Foundation

public enum AnalysisPhysicalEvidenceAnchorLedgerAppendStatus: String, Codable, Sendable {
    case appended = "APPENDED"
    case recoveredInterruptedAppend = "RECOVERED_INTERRUPTED_APPEND"
    case exactDuplicateAccepted = "EXACT_DUPLICATE_ACCEPTED"
}

public struct AnalysisPhysicalEvidenceAnchorLedgerRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let anchorID: String
    public let sequence: UInt64
    public let anchorReceiptRootSHA256: String
    public let certificateRootSHA256: String
    public let predecessorLedgerRecordRootSHA256: String?
    public let anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt
    public let destinationCertificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate
    public let declaredRecordRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        anchorID: String,
        sequence: UInt64,
        anchorReceiptRootSHA256: String,
        certificateRootSHA256: String,
        predecessorLedgerRecordRootSHA256: String?,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        destinationCertificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate,
        declaredRecordRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.anchorID = anchorID
        self.sequence = sequence
        self.anchorReceiptRootSHA256 = anchorReceiptRootSHA256.lowercased()
        self.certificateRootSHA256 = certificateRootSHA256.lowercased()
        self.predecessorLedgerRecordRootSHA256 = predecessorLedgerRecordRootSHA256?.lowercased()
        self.anchorReceipt = anchorReceipt
        self.destinationCertificate = destinationCertificate
        self.declaredRecordRootSHA256 = declaredRecordRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceAnchorLedgerRecordSummary: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let relativePath: String
    public let anchorReceiptRootSHA256: String
    public let certificateRootSHA256: String
    public let predecessorLedgerRecordRootSHA256: String?
    public let recordRootSHA256: String

    public init(
        sequence: UInt64,
        relativePath: String,
        anchorReceiptRootSHA256: String,
        certificateRootSHA256: String,
        predecessorLedgerRecordRootSHA256: String?,
        recordRootSHA256: String
    ) {
        self.sequence = sequence
        self.relativePath = relativePath
        self.anchorReceiptRootSHA256 = anchorReceiptRootSHA256.lowercased()
        self.certificateRootSHA256 = certificateRootSHA256.lowercased()
        self.predecessorLedgerRecordRootSHA256 = predecessorLedgerRecordRootSHA256?.lowercased()
        self.recordRootSHA256 = recordRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceAnchorLedgerHead: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let anchorID: String
    public let records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary]
    public let latestSequence: UInt64
    public let latestAnchorReceiptRootSHA256: String
    public let latestCertificateRootSHA256: String
    public let latestRecordRootSHA256: String
    public let declaredLedgerRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        anchorID: String,
        records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary],
        latestSequence: UInt64,
        latestAnchorReceiptRootSHA256: String,
        latestCertificateRootSHA256: String,
        latestRecordRootSHA256: String,
        declaredLedgerRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.anchorID = anchorID
        self.records = records.sorted { $0.sequence < $1.sequence }
        self.latestSequence = latestSequence
        self.latestAnchorReceiptRootSHA256 = latestAnchorReceiptRootSHA256.lowercased()
        self.latestCertificateRootSHA256 = latestCertificateRootSHA256.lowercased()
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.declaredLedgerRootSHA256 = declaredLedgerRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceAnchorLedgerSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let anchorID: String
    public let records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary]
    public let declaredLedgerRootSHA256: String
    public let limitations: [String]

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        anchorID: String,
        records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary],
        declaredLedgerRootSHA256: String,
        limitations: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.anchorID = anchorID
        self.records = records.sorted { $0.sequence < $1.sequence }
        self.declaredLedgerRootSHA256 = declaredLedgerRootSHA256.lowercased()
        self.limitations = limitations
    }
}

public struct AnalysisPhysicalEvidenceAnchorLedgerAppendReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalEvidenceAnchorLedgerAppendStatus
    public let ledgerID: String
    public let anchorID: String
    public let sequence: UInt64
    public let anchorReceiptRootSHA256: String
    public let certificateRootSHA256: String
    public let recordRootSHA256: String
    public let ledgerRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalEvidenceAnchorLedgerAppendStatus,
        ledgerID: String,
        anchorID: String,
        sequence: UInt64,
        anchorReceiptRootSHA256: String,
        certificateRootSHA256: String,
        recordRootSHA256: String,
        ledgerRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.ledgerID = ledgerID
        self.anchorID = anchorID
        self.sequence = sequence
        self.anchorReceiptRootSHA256 = anchorReceiptRootSHA256.lowercased()
        self.certificateRootSHA256 = certificateRootSHA256.lowercased()
        self.recordRootSHA256 = recordRootSHA256.lowercased()
        self.ledgerRootSHA256 = ledgerRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceAnchorLedgerPendingAppend: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let candidateRecord: AnalysisPhysicalEvidenceAnchorLedgerRecord
    public let candidateRelativePath: String
    public let previousLedgerRootSHA256: String?
    public let previousLatestRecordRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        candidateRecord: AnalysisPhysicalEvidenceAnchorLedgerRecord,
        candidateRelativePath: String,
        previousLedgerRootSHA256: String?,
        previousLatestRecordRootSHA256: String?
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.candidateRecord = candidateRecord
        self.candidateRelativePath = candidateRelativePath
        self.previousLedgerRootSHA256 = previousLedgerRootSHA256?.lowercased()
        self.previousLatestRecordRootSHA256 = previousLatestRecordRootSHA256?.lowercased()
    }
}

public enum AnalysisPhysicalEvidenceAnchorLedgerInterruptedCheckpoint: String, Codable, Sendable {
    case pendingMarkerOnly = "PENDING_MARKER_ONLY"
    case recordWrittenBeforeHead = "RECORD_WRITTEN_BEFORE_HEAD"
}

public enum AnalysisPhysicalEvidenceAnchorLedgerError: Error, Equatable, Sendable {
    case unsafeLedgerID
    case invalidReceiptOrCertificate
    case ledgerAnchorMismatch
    case rollbackImport
    case sequenceGap
    case sequenceReuseDifferentRoots
    case predecessorReceiptMismatch
    case predecessorRecordMismatch
    case corruptedLedger
    case ambiguousRecoveryState
    case existingRecordCollision
    case writeFailed
    case readBackFailed
}
