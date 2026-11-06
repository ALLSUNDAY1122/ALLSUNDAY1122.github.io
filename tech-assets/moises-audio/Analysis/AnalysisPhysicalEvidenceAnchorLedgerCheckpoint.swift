import Foundation

public enum AnalysisPhysicalEvidenceLedgerCheckpointStatus: String, Codable, Sendable {
    case verifiedAgainstExternalLedgerCheckpointNonParity = "VERIFIED_AGAINST_EXTERNAL_LEDGER_CHECKPOINT_NON_PARITY"
}

public struct AnalysisPhysicalEvidenceLedgerCheckpointExpectation: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let checkpointID: String
    public let checkpointSequence: UInt64
    public let authority: String
    public let approvalReference: String
    public let expectedLedgerID: String
    public let expectedAnchorID: String
    public let minimumLedgerSequence: UInt64
    public let expectedLatestLedgerSequence: UInt64
    public let expectedLatestAnchorReceiptRootSHA256: String
    public let expectedLedgerRootSHA256: String
    public let expectedPredecessorCheckpointCertificateRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        checkpointID: String,
        checkpointSequence: UInt64,
        authority: String,
        approvalReference: String,
        expectedLedgerID: String,
        expectedAnchorID: String,
        minimumLedgerSequence: UInt64,
        expectedLatestLedgerSequence: UInt64,
        expectedLatestAnchorReceiptRootSHA256: String,
        expectedLedgerRootSHA256: String,
        expectedPredecessorCheckpointCertificateRootSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.checkpointID = checkpointID
        self.checkpointSequence = checkpointSequence
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedLedgerID = expectedLedgerID
        self.expectedAnchorID = expectedAnchorID
        self.minimumLedgerSequence = minimumLedgerSequence
        self.expectedLatestLedgerSequence = expectedLatestLedgerSequence
        self.expectedLatestAnchorReceiptRootSHA256 = expectedLatestAnchorReceiptRootSHA256.lowercased()
        self.expectedLedgerRootSHA256 = expectedLedgerRootSHA256.lowercased()
        self.expectedPredecessorCheckpointCertificateRootSHA256 = expectedPredecessorCheckpointCertificateRootSHA256?.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceLedgerCheckpointCertificate: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalEvidenceLedgerCheckpointStatus
    public let checkpointID: String
    public let checkpointSequence: UInt64
    public let checkpointExpectationRootSHA256: String
    public let ledgerID: String
    public let anchorID: String
    public let expectedMinimumLedgerSequence: UInt64
    public let expectedLatestLedgerSequence: UInt64
    public let observedLatestLedgerSequence: UInt64
    public let expectedLatestAnchorReceiptRootSHA256: String
    public let observedLatestAnchorReceiptRootSHA256: String
    public let expectedLedgerRootSHA256: String
    public let observedLedgerRootSHA256: String
    public let observedLatestCertificateRootSHA256: String
    public let observedLatestRecordRootSHA256: String
    public let recordCount: UInt64
    public let predecessorCheckpointCertificateRootSHA256: String?
    public let limitations: [String]
    public let declaredCertificateRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalEvidenceLedgerCheckpointStatus,
        checkpointID: String,
        checkpointSequence: UInt64,
        checkpointExpectationRootSHA256: String,
        ledgerID: String,
        anchorID: String,
        expectedMinimumLedgerSequence: UInt64,
        expectedLatestLedgerSequence: UInt64,
        observedLatestLedgerSequence: UInt64,
        expectedLatestAnchorReceiptRootSHA256: String,
        observedLatestAnchorReceiptRootSHA256: String,
        expectedLedgerRootSHA256: String,
        observedLedgerRootSHA256: String,
        observedLatestCertificateRootSHA256: String,
        observedLatestRecordRootSHA256: String,
        recordCount: UInt64,
        predecessorCheckpointCertificateRootSHA256: String?,
        limitations: [String],
        declaredCertificateRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.checkpointID = checkpointID
        self.checkpointSequence = checkpointSequence
        self.checkpointExpectationRootSHA256 = checkpointExpectationRootSHA256.lowercased()
        self.ledgerID = ledgerID
        self.anchorID = anchorID
        self.expectedMinimumLedgerSequence = expectedMinimumLedgerSequence
        self.expectedLatestLedgerSequence = expectedLatestLedgerSequence
        self.observedLatestLedgerSequence = observedLatestLedgerSequence
        self.expectedLatestAnchorReceiptRootSHA256 = expectedLatestAnchorReceiptRootSHA256.lowercased()
        self.observedLatestAnchorReceiptRootSHA256 = observedLatestAnchorReceiptRootSHA256.lowercased()
        self.expectedLedgerRootSHA256 = expectedLedgerRootSHA256.lowercased()
        self.observedLedgerRootSHA256 = observedLedgerRootSHA256.lowercased()
        self.observedLatestCertificateRootSHA256 = observedLatestCertificateRootSHA256.lowercased()
        self.observedLatestRecordRootSHA256 = observedLatestRecordRootSHA256.lowercased()
        self.recordCount = recordCount
        self.predecessorCheckpointCertificateRootSHA256 = predecessorCheckpointCertificateRootSHA256?.lowercased()
        self.limitations = limitations
        self.declaredCertificateRootSHA256 = declaredCertificateRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalEvidenceLedgerCheckpointError: Error, Equatable, Sendable {
    case invalidExpectation
    case ledgerReopenFailed
    case invalidLedgerSnapshot
    case ledgerIdentityMismatch
    case anchorIdentityMismatch
    case staleLedgerSequence
    case ledgerSequenceMismatch
    case latestAnchorReceiptRootMismatch
    case ledgerRootMismatch
    case expectationRootMismatch
    case invalidCertificate
    case checkpointIdentityMismatch
    case predecessorCheckpointMismatch
    case certificateRootMismatch
    case currentLedgerCertificateMismatch
}

public enum AnalysisPhysicalEvidenceLedgerCheckpointExpectationRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let checkpointID: String
        let checkpointSequence: UInt64
        let authority: String
        let approvalReference: String
        let expectedLedgerID: String
        let expectedAnchorID: String
        let minimumLedgerSequence: UInt64
        let expectedLatestLedgerSequence: UInt64
        let expectedLatestAnchorReceiptRootSHA256: String
        let expectedLedgerRootSHA256: String
        let expectedPredecessorCheckpointCertificateRootSHA256: String?
    }

    public static func compute(_ value: AnalysisPhysicalEvidenceLedgerCheckpointExpectation) throws -> String {
        let payload = Payload(
            schemaVersion: value.schemaVersion,
            checkpointID: value.checkpointID,
            checkpointSequence: value.checkpointSequence,
            authority: value.authority,
            approvalReference: value.approvalReference,
            expectedLedgerID: value.expectedLedgerID,
            expectedAnchorID: value.expectedAnchorID,
            minimumLedgerSequence: value.minimumLedgerSequence,
            expectedLatestLedgerSequence: value.expectedLatestLedgerSequence,
            expectedLatestAnchorReceiptRootSHA256: value.expectedLatestAnchorReceiptRootSHA256.lowercased(),
            expectedLedgerRootSHA256: value.expectedLedgerRootSHA256.lowercased(),
            expectedPredecessorCheckpointCertificateRootSHA256: value.expectedPredecessorCheckpointCertificateRootSHA256?.lowercased()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceLedgerCheckpointCertificateRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let status: AnalysisPhysicalEvidenceLedgerCheckpointStatus
        let checkpointID: String
        let checkpointSequence: UInt64
        let checkpointExpectationRootSHA256: String
        let ledgerID: String
        let anchorID: String
        let expectedMinimumLedgerSequence: UInt64
        let expectedLatestLedgerSequence: UInt64
        let observedLatestLedgerSequence: UInt64
        let expectedLatestAnchorReceiptRootSHA256: String
        let observedLatestAnchorReceiptRootSHA256: String
        let expectedLedgerRootSHA256: String
        let observedLedgerRootSHA256: String
        let observedLatestCertificateRootSHA256: String
        let observedLatestRecordRootSHA256: String
        let recordCount: UInt64
        let predecessorCheckpointCertificateRootSHA256: String?
        let limitations: [String]
    }

    public static func compute(_ value: AnalysisPhysicalEvidenceLedgerCheckpointCertificate) throws -> String {
        let payload = Payload(
            schemaVersion: value.schemaVersion,
            status: value.status,
            checkpointID: value.checkpointID,
            checkpointSequence: value.checkpointSequence,
            checkpointExpectationRootSHA256: value.checkpointExpectationRootSHA256.lowercased(),
            ledgerID: value.ledgerID,
            anchorID: value.anchorID,
            expectedMinimumLedgerSequence: value.expectedMinimumLedgerSequence,
            expectedLatestLedgerSequence: value.expectedLatestLedgerSequence,
            observedLatestLedgerSequence: value.observedLatestLedgerSequence,
            expectedLatestAnchorReceiptRootSHA256: value.expectedLatestAnchorReceiptRootSHA256.lowercased(),
            observedLatestAnchorReceiptRootSHA256: value.observedLatestAnchorReceiptRootSHA256.lowercased(),
            expectedLedgerRootSHA256: value.expectedLedgerRootSHA256.lowercased(),
            observedLedgerRootSHA256: value.observedLedgerRootSHA256.lowercased(),
            observedLatestCertificateRootSHA256: value.observedLatestCertificateRootSHA256.lowercased(),
            observedLatestRecordRootSHA256: value.observedLatestRecordRootSHA256.lowercased(),
            recordCount: value.recordCount,
            predecessorCheckpointCertificateRootSHA256: value.predecessorCheckpointCertificateRootSHA256?.lowercased(),
            limitations: value.limitations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceLedgerCheckpointVerifier {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: this certificate proves one W43 ledger reopened consistently with a caller-supplied external checkpoint; it does not establish product parity.",
        "Whole-ledger rollback detection depends on preserving the current checkpoint expectation outside the ledger being verified.",
        "Checkpoint and certificate roots are SHA-256 metadata commitments, not signatures, trusted timestamps, Secure Enclave proofs or Apple attestation.",
        "A compromised authority that replaces both the local ledger and the externally preserved expectation can still present an older internally consistent state."
    ]

    public static func validateExpectation(_ value: AnalysisPhysicalEvidenceLedgerCheckpointExpectation) -> Bool {
        let predecessorIsValid = value.expectedPredecessorCheckpointCertificateRootSHA256.map {
            AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0)
        } ?? true
        let checkpointChainIsValid = value.checkpointSequence == 1
            ? value.expectedPredecessorCheckpointCertificateRootSHA256 == nil
            : value.expectedPredecessorCheckpointCertificateRootSHA256 != nil
        return value.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.checkpointID)
            && value.checkpointSequence > 0
            && value.authority == requiredAuthority
            && !value.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.expectedLedgerID)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.expectedAnchorID)
            && value.minimumLedgerSequence > 0
            && value.expectedLatestLedgerSequence >= value.minimumLedgerSequence
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.expectedLatestAnchorReceiptRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.expectedLedgerRootSHA256)
            && predecessorIsValid
            && checkpointChainIsValid
    }

    public static func verifyLedger(
        rootURL: URL,
        expectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceLedgerCheckpointCertificate {
        guard validateExpectation(expectation) else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidExpectation
        }
        let snapshot: AnalysisPhysicalEvidenceAnchorLedgerSnapshot
        do {
            snapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(
                ledgerID: expectation.expectedLedgerID,
                rootURL: rootURL,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerReopenFailed
        }
        return try verifyAlreadyValidatedSnapshot(snapshot, expectation: expectation)
    }

    /// XCTest seam. Production callers use `verifyLedger`, which reopens and
    /// fully revalidates the W43 ledger instead of accepting a cached snapshot.
    static func verifyAlreadyValidatedSnapshot(
        _ snapshot: AnalysisPhysicalEvidenceAnchorLedgerSnapshot,
        expectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation
    ) throws -> AnalysisPhysicalEvidenceLedgerCheckpointCertificate {
        guard validateExpectation(expectation) else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidExpectation
        }
        let sortedRecords = snapshot.records.sorted { $0.sequence < $1.sequence }
        let sequencesAreUnique = Set(sortedRecords.map(\.sequence)).count == sortedRecords.count
        let pathsAreUnique = Set(sortedRecords.map(\.relativePath)).count == sortedRecords.count
        let recordsAreSequential = sortedRecords.enumerated().allSatisfy { pair in
            pair.element.sequence == UInt64(pair.offset + 1)
        }
        let recordsAreWellFormed = sortedRecords.allSatisfy { record in
            AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(record.relativePath)
                && record.relativePath.hasPrefix("records/")
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.anchorReceiptRootSHA256)
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.certificateRootSHA256)
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.recordRootSHA256)
                && (record.predecessorLedgerRecordRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true)
        }
        guard snapshot.schemaVersion == 1,
              !sortedRecords.isEmpty,
              snapshot.records == sortedRecords,
              sequencesAreUnique,
              pathsAreUnique,
              recordsAreSequential,
              recordsAreWellFormed,
              snapshot.limitations == AnalysisPhysicalEvidenceAnchorLedgerStore.limitations,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(snapshot.declaredLedgerRootSHA256) else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidLedgerSnapshot
        }
        guard snapshot.ledgerID == expectation.expectedLedgerID else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerIdentityMismatch
        }
        guard snapshot.anchorID == expectation.expectedAnchorID else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.anchorIdentityMismatch
        }
        guard let latest = sortedRecords.last else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidLedgerSnapshot
        }
        guard latest.sequence >= expectation.minimumLedgerSequence else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.staleLedgerSequence
        }
        guard latest.sequence == expectation.expectedLatestLedgerSequence,
              UInt64(sortedRecords.count) == expectation.expectedLatestLedgerSequence else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerSequenceMismatch
        }
        guard latest.anchorReceiptRootSHA256.lowercased()
                == expectation.expectedLatestAnchorReceiptRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.latestAnchorReceiptRootMismatch
        }
        guard snapshot.declaredLedgerRootSHA256.lowercased()
                == expectation.expectedLedgerRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerRootMismatch
        }

        let expectationRoot = try AnalysisPhysicalEvidenceLedgerCheckpointExpectationRoot.compute(expectation)
        let provisional = AnalysisPhysicalEvidenceLedgerCheckpointCertificate(
            status: .verifiedAgainstExternalLedgerCheckpointNonParity,
            checkpointID: expectation.checkpointID,
            checkpointSequence: expectation.checkpointSequence,
            checkpointExpectationRootSHA256: expectationRoot,
            ledgerID: snapshot.ledgerID,
            anchorID: snapshot.anchorID,
            expectedMinimumLedgerSequence: expectation.minimumLedgerSequence,
            expectedLatestLedgerSequence: expectation.expectedLatestLedgerSequence,
            observedLatestLedgerSequence: latest.sequence,
            expectedLatestAnchorReceiptRootSHA256: expectation.expectedLatestAnchorReceiptRootSHA256,
            observedLatestAnchorReceiptRootSHA256: latest.anchorReceiptRootSHA256,
            expectedLedgerRootSHA256: expectation.expectedLedgerRootSHA256,
            observedLedgerRootSHA256: snapshot.declaredLedgerRootSHA256,
            observedLatestCertificateRootSHA256: latest.certificateRootSHA256,
            observedLatestRecordRootSHA256: latest.recordRootSHA256,
            recordCount: UInt64(sortedRecords.count),
            predecessorCheckpointCertificateRootSHA256: expectation.expectedPredecessorCheckpointCertificateRootSHA256,
            limitations: limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let certificateRoot = try AnalysisPhysicalEvidenceLedgerCheckpointCertificateRoot.compute(provisional)
        return .init(
            status: provisional.status,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointExpectationRootSHA256: provisional.checkpointExpectationRootSHA256,
            ledgerID: provisional.ledgerID,
            anchorID: provisional.anchorID,
            expectedMinimumLedgerSequence: provisional.expectedMinimumLedgerSequence,
            expectedLatestLedgerSequence: provisional.expectedLatestLedgerSequence,
            observedLatestLedgerSequence: provisional.observedLatestLedgerSequence,
            expectedLatestAnchorReceiptRootSHA256: provisional.expectedLatestAnchorReceiptRootSHA256,
            observedLatestAnchorReceiptRootSHA256: provisional.observedLatestAnchorReceiptRootSHA256,
            expectedLedgerRootSHA256: provisional.expectedLedgerRootSHA256,
            observedLedgerRootSHA256: provisional.observedLedgerRootSHA256,
            observedLatestCertificateRootSHA256: provisional.observedLatestCertificateRootSHA256,
            observedLatestRecordRootSHA256: provisional.observedLatestRecordRootSHA256,
            recordCount: provisional.recordCount,
            predecessorCheckpointCertificateRootSHA256: provisional.predecessorCheckpointCertificateRootSHA256,
            limitations: provisional.limitations,
            declaredCertificateRootSHA256: certificateRoot
        )
    }

    public static func validateCertificate(
        _ certificate: AnalysisPhysicalEvidenceLedgerCheckpointCertificate,
        expectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation
    ) throws {
        guard validateExpectation(expectation) else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidExpectation
        }
        let expectationRoot = try AnalysisPhysicalEvidenceLedgerCheckpointExpectationRoot.compute(expectation)
        guard certificate.schemaVersion == 1,
              certificate.status == .verifiedAgainstExternalLedgerCheckpointNonParity,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.checkpointExpectationRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.expectedLatestAnchorReceiptRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.observedLatestAnchorReceiptRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.expectedLedgerRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.observedLedgerRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.observedLatestCertificateRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.observedLatestRecordRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.declaredCertificateRootSHA256),
              certificate.limitations == limitations else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.invalidCertificate
        }
        guard certificate.checkpointExpectationRootSHA256.lowercased() == expectationRoot.lowercased() else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.expectationRootMismatch
        }
        guard certificate.checkpointID == expectation.checkpointID,
              certificate.checkpointSequence == expectation.checkpointSequence else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.checkpointIdentityMismatch
        }
        guard certificate.ledgerID == expectation.expectedLedgerID else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerIdentityMismatch
        }
        guard certificate.anchorID == expectation.expectedAnchorID else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.anchorIdentityMismatch
        }
        guard certificate.expectedMinimumLedgerSequence == expectation.minimumLedgerSequence,
              certificate.expectedLatestLedgerSequence == expectation.expectedLatestLedgerSequence,
              certificate.observedLatestLedgerSequence == expectation.expectedLatestLedgerSequence,
              certificate.recordCount == expectation.expectedLatestLedgerSequence else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerSequenceMismatch
        }
        guard certificate.expectedLatestAnchorReceiptRootSHA256 == expectation.expectedLatestAnchorReceiptRootSHA256,
              certificate.observedLatestAnchorReceiptRootSHA256 == expectation.expectedLatestAnchorReceiptRootSHA256 else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.latestAnchorReceiptRootMismatch
        }
        guard certificate.expectedLedgerRootSHA256 == expectation.expectedLedgerRootSHA256,
              certificate.observedLedgerRootSHA256 == expectation.expectedLedgerRootSHA256 else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.ledgerRootMismatch
        }
        guard certificate.predecessorCheckpointCertificateRootSHA256
                == expectation.expectedPredecessorCheckpointCertificateRootSHA256 else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.predecessorCheckpointMismatch
        }
        let computed = try AnalysisPhysicalEvidenceLedgerCheckpointCertificateRoot.compute(certificate)
        guard computed == certificate.declaredCertificateRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.certificateRootMismatch
        }
    }

    public static func verifyCertificateAgainstCurrentLedger(
        _ certificate: AnalysisPhysicalEvidenceLedgerCheckpointCertificate,
        rootURL: URL,
        expectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation,
        fileManager: FileManager = .default
    ) throws {
        try validateCertificate(certificate, expectation: expectation)
        let current = try verifyLedger(rootURL: rootURL, expectation: expectation, fileManager: fileManager)
        guard current == certificate else {
            throw AnalysisPhysicalEvidenceLedgerCheckpointError.currentLedgerCertificateMismatch
        }
    }
}

public enum AnalysisPhysicalEvidenceLedgerCheckpointCodec {
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func encodeExpectation(_ value: AnalysisPhysicalEvidenceLedgerCheckpointExpectation) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeExpectation(_ data: Data) throws -> AnalysisPhysicalEvidenceLedgerCheckpointExpectation {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceLedgerCheckpointExpectation.self, from: data)
    }

    public static func encodeCertificate(_ value: AnalysisPhysicalEvidenceLedgerCheckpointCertificate) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeCertificate(_ data: Data) throws -> AnalysisPhysicalEvidenceLedgerCheckpointCertificate {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceLedgerCheckpointCertificate.self, from: data)
    }
}
