import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionCustody: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let custodyID: String

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        custodyID: String
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.custodyID = custodyID
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let sequence: UInt64
    public let bridgeID: String
    public let bridgeCertificateRootSHA256: String
    public let w47PackageRootSHA256: String
    public let w46AdjudicationReportRootSHA256: String
    public let expectationRootSHA256: String
    public let custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody
    public let predecessorRecordRootSHA256: String?
    public let declaredRecordRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        sequence: UInt64,
        bridgeID: String,
        bridgeCertificateRootSHA256: String,
        w47PackageRootSHA256: String,
        w46AdjudicationReportRootSHA256: String,
        expectationRootSHA256: String,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        predecessorRecordRootSHA256: String?,
        declaredRecordRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.sequence = sequence
        self.bridgeID = bridgeID
        self.bridgeCertificateRootSHA256 = bridgeCertificateRootSHA256.lowercased()
        self.w47PackageRootSHA256 = w47PackageRootSHA256.lowercased()
        self.w46AdjudicationReportRootSHA256 = w46AdjudicationReportRootSHA256.lowercased()
        self.expectationRootSHA256 = expectationRootSHA256.lowercased()
        self.custody = custody
        self.predecessorRecordRootSHA256 = predecessorRecordRootSHA256?.lowercased()
        self.declaredRecordRootSHA256 = declaredRecordRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let relativePath: String
    public let bridgeID: String
    public let bridgeCertificateRootSHA256: String
    public let w47PackageRootSHA256: String
    public let w46AdjudicationReportRootSHA256: String
    public let predecessorRecordRootSHA256: String?
    public let recordRootSHA256: String

    public init(
        sequence: UInt64,
        relativePath: String,
        bridgeID: String,
        bridgeCertificateRootSHA256: String,
        w47PackageRootSHA256: String,
        w46AdjudicationReportRootSHA256: String,
        predecessorRecordRootSHA256: String?,
        recordRootSHA256: String
    ) {
        self.sequence = sequence
        self.relativePath = relativePath
        self.bridgeID = bridgeID
        self.bridgeCertificateRootSHA256 = bridgeCertificateRootSHA256.lowercased()
        self.w47PackageRootSHA256 = w47PackageRootSHA256.lowercased()
        self.w46AdjudicationReportRootSHA256 = w46AdjudicationReportRootSHA256.lowercased()
        self.predecessorRecordRootSHA256 = predecessorRecordRootSHA256?.lowercased()
        self.recordRootSHA256 = recordRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let records: [AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary]
    public let latestSequence: UInt64
    public let latestRecordRootSHA256: String
    public let declaredLedgerRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        records: [AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary],
        latestSequence: UInt64,
        latestRecordRootSHA256: String,
        declaredLedgerRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.records = records.sorted { $0.sequence < $1.sequence }
        self.latestSequence = latestSequence
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.declaredLedgerRootSHA256 = declaredLedgerRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let candidateRecord: AnalysisPhysicalRealAudioBridgeConsumptionRecord
    public let candidateRelativePath: String
    public let previousLedgerRootSHA256: String?
    public let previousLatestRecordRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        candidateRecord: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
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

public enum AnalysisPhysicalRealAudioBridgeConsumptionLedgerError: Error, Equatable, Sendable {
    case unsafeLedgerID
    case invalidCustody
    case invalidBridgeCertificate
    case duplicateBridgeID
    case duplicateW47PackageRoot
    case duplicateBridgeCertificateRoot
    case corruptedLedger
    case forkedHistory
    case ambiguousRecoveryState
    case existingRecordCollision
    case writeFailed
    case readBackFailed
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionRecordRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let sequence: UInt64
        let bridgeID: String
        let bridgeCertificateRootSHA256: String
        let w47PackageRootSHA256: String
        let w46AdjudicationReportRootSHA256: String
        let expectationRootSHA256: String
        let custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody
        let predecessorRecordRootSHA256: String?
    }

    public static func compute(_ value: AnalysisPhysicalRealAudioBridgeConsumptionRecord) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            ledgerID: value.ledgerID,
            sequence: value.sequence,
            bridgeID: value.bridgeID,
            bridgeCertificateRootSHA256: value.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: value.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: value.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: value.expectationRootSHA256,
            custody: value.custody,
            predecessorRecordRootSHA256: value.predecessorRecordRootSHA256
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let records: [AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary]
    }

    public static func compute(
        ledgerID: String,
        records: [AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary]
    ) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: 1,
            ledgerID: ledgerID,
            records: records.sorted { $0.sequence < $1.sequence }
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec {
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func encodeRecord(_ value: AnalysisPhysicalRealAudioBridgeConsumptionRecord) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeRecord(_ data: Data) throws -> AnalysisPhysicalRealAudioBridgeConsumptionRecord {
        try JSONDecoder().decode(AnalysisPhysicalRealAudioBridgeConsumptionRecord.self, from: data)
    }

    public static func encodeHead(_ value: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeHead(_ data: Data) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try JSONDecoder().decode(AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead.self, from: data)
    }

    public static func encodePending(_ value: AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodePending(_ data: Data) throws -> AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend {
        try JSONDecoder().decode(AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend.self, from: data)
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let headFileName = "W49_CONSUMPTION_LEDGER_HEAD.json"
    public static let pendingFileName = ".W49_PENDING.json"
    public static let limitations = [
        "NON_PARITY: the W49 ledger records consumption continuity for W48 bridge certificates; it does not promote any Analysis PARITY row.",
        "The ledger is a local SHA-256 hash chain with atomic-file recovery markers, not a signature, trusted timestamp, Secure Enclave proof or Apple attestation.",
        "Rollback and fork resistance become externally authoritative only when HQ preserves the latest checkpoint/handoff root outside the ledger directory.",
        "A compromised authority that replaces both the local ledger and all external checkpoints can still present an older internally consistent history."
    ]

    @discardableResult
    public static func append(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.unsafeLedgerID }
        guard validateCustody(custody) else { throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.invalidCustody }
        guard AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.invalidBridgeCertificate
        }

        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let oldHead = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        if let oldHead {
            if oldHead.records.contains(where: { $0.bridgeID == certificate.bridgeID }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.duplicateBridgeID
            }
            if oldHead.records.contains(where: { $0.w47PackageRootSHA256 == certificate.w47PackageRootSHA256 }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.duplicateW47PackageRoot
            }
            if oldHead.records.contains(where: { $0.bridgeCertificateRootSHA256 == certificate.declaredCertificateRootSHA256 }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.duplicateBridgeCertificateRoot
            }
        }

        let sequence = (oldHead?.latestSequence ?? 0) + 1
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionRecord(
            ledgerID: ledgerID,
            sequence: sequence,
            bridgeID: certificate.bridgeID,
            bridgeCertificateRootSHA256: certificate.declaredCertificateRootSHA256,
            w47PackageRootSHA256: certificate.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: certificate.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: certificate.expectationRootSHA256,
            custody: custody,
            predecessorRecordRootSHA256: oldHead?.latestRecordRootSHA256,
            declaredRecordRootSHA256: String(repeating: "0", count: 64)
        )
        let recordRoot = try AnalysisPhysicalRealAudioBridgeConsumptionRecordRoot.compute(provisional)
        let record = AnalysisPhysicalRealAudioBridgeConsumptionRecord(
            ledgerID: provisional.ledgerID,
            sequence: provisional.sequence,
            bridgeID: provisional.bridgeID,
            bridgeCertificateRootSHA256: provisional.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: provisional.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: provisional.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: provisional.expectationRootSHA256,
            custody: provisional.custody,
            predecessorRecordRootSHA256: provisional.predecessorRecordRootSHA256,
            declaredRecordRootSHA256: recordRoot
        )
        let relativePath = recordRelativePath(record)
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        let pending = AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: relativePath,
            previousLedgerRootSHA256: oldHead?.declaredLedgerRootSHA256,
            previousLatestRecordRootSHA256: oldHead?.latestRecordRootSHA256
        )

        do {
            try fileManager.createDirectory(at: ledgerURL.appendingPathComponent("records", isDirectory: true), withIntermediateDirectories: true)
            try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodePending(pending).write(
                to: ledgerURL.appendingPathComponent(pendingFileName), options: .atomic
            )
            try writeRecord(record, relativePath: relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
            let newHead = try makeHead(previous: oldHead, record: record, relativePath: relativePath)
            try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(newHead).write(
                to: ledgerURL.appendingPathComponent(headFileName), options: .atomic
            )
            try fileManager.removeItem(at: ledgerURL.appendingPathComponent(pendingFileName))
            guard let verified = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager),
                  verified == newHead else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.readBackFailed
            }
            return verified
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionLedgerError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.writeFailed
        }
    }

    public static func consumedW47PackageRootSHA256s(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> [String] {
        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        return try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)?
            .records.map(\.w47PackageRootSHA256).sorted() ?? []
    }

    public static func loadValidatedHead(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead? {
        try loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            allowedPendingRelativePath: nil
        )
    }

    @discardableResult
    public static func recoverIfNeeded(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.unsafeLedgerID }
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: ledgerURL.path, isDirectory: &isDirectory) else { return false }
        guard isDirectory.boolValue else { throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger }
        let pendingURL = ledgerURL.appendingPathComponent(pendingFileName)
        guard fileManager.fileExists(atPath: pendingURL.path) else {
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return false
        }

        let pending: AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend
        do {
            pending = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodePending(try Data(contentsOf: pendingURL))
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.ambiguousRecoveryState
        }
        guard pending.schemaVersion == 1,
              pending.ledgerID == ledgerID,
              validateRecord(pending.candidateRecord),
              pending.candidateRelativePath == recordRelativePath(pending.candidateRecord),
              pending.previousLedgerRootSHA256.map(isSHA256) ?? true,
              pending.previousLatestRecordRootSHA256.map(isSHA256) ?? true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.ambiguousRecoveryState
        }

        let head = try loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            allowedPendingRelativePath: pending.candidateRelativePath
        )
        let recordURL = ledgerURL.appendingPathComponent(pending.candidateRelativePath)
        let recordExists = fileManager.fileExists(atPath: recordURL.path)

        if let head, head.latestSequence == pending.candidateRecord.sequence {
            guard head.latestRecordRootSHA256 == pending.candidateRecord.declaredRecordRootSHA256,
                  recordExists,
                  try readRecord(relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL) == pending.candidateRecord else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.ambiguousRecoveryState
            }
            try fileManager.removeItem(at: pendingURL)
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return true
        }

        let expectedSequence = (head?.latestSequence ?? 0) + 1
        guard pending.candidateRecord.sequence == expectedSequence,
              pending.previousLedgerRootSHA256 == head?.declaredLedgerRootSHA256,
              pending.previousLatestRecordRootSHA256 == head?.latestRecordRootSHA256,
              pending.candidateRecord.predecessorRecordRootSHA256 == head?.latestRecordRootSHA256 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.ambiguousRecoveryState
        }

        if !recordExists {
            try fileManager.removeItem(at: pendingURL)
            return true
        }
        guard try readRecord(relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL) == pending.candidateRecord else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.ambiguousRecoveryState
        }
        let repaired = try makeHead(previous: head, record: pending.candidateRecord, relativePath: pending.candidateRelativePath)
        try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(repaired).write(
            to: ledgerURL.appendingPathComponent(headFileName), options: .atomic
        )
        try fileManager.removeItem(at: pendingURL)
        guard try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager) == repaired else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.readBackFailed
        }
        return true
    }

    static func validateCustody(_ value: AnalysisPhysicalRealAudioBridgeConsumptionCustody) -> Bool {
        value.schemaVersion == 1
            && value.authority == requiredAuthority
            && !value.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && safeComponent(value.custodyID)
    }

    static func validateRecord(_ value: AnalysisPhysicalRealAudioBridgeConsumptionRecord) -> Bool {
        value.schemaVersion == 1
            && safeComponent(value.ledgerID)
            && value.sequence > 0
            && safeComponent(value.bridgeID)
            && isSHA256(value.bridgeCertificateRootSHA256)
            && isSHA256(value.w47PackageRootSHA256)
            && isSHA256(value.w46AdjudicationReportRootSHA256)
            && isSHA256(value.expectationRootSHA256)
            && validateCustody(value.custody)
            && (value.predecessorRecordRootSHA256.map(isSHA256) ?? true)
            && isSHA256(value.declaredRecordRootSHA256)
            && (try? AnalysisPhysicalRealAudioBridgeConsumptionRecordRoot.compute(value)) == value.declaredRecordRootSHA256
    }

    static func safeComponent(_ value: String) -> Bool {
        AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value)
    }

    static func isSHA256(_ value: String) -> Bool {
        AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value)
    }

    private static func ledgerDirectoryURL(ledgerID: String, rootURL: URL) -> URL {
        rootURL.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
            .appendingPathComponent(ledgerID, isDirectory: true)
    }

    private static func recordRelativePath(_ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord) -> String {
        String(format: "records/%012llu-%@.json", record.sequence, record.declaredRecordRootSHA256)
    }

    private static func writeRecord(
        _ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws {
        let url = ledgerURL.appendingPathComponent(relativePath)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.existingRecordCollision
        }
        try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeRecord(record).write(to: url, options: .atomic)
        guard try readRecord(relativePath: relativePath, ledgerURL: ledgerURL) == record else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.readBackFailed
        }
    }

    private static func readRecord(
        relativePath: String,
        ledgerURL: URL
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionRecord {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath.hasPrefix("records/") else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger
        }
        return try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeRecord(
            Data(contentsOf: ledgerURL.appendingPathComponent(relativePath))
        )
    }

    private static func makeHead(
        previous: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead?,
        record: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
        relativePath: String
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        let summary = AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary(
            sequence: record.sequence,
            relativePath: relativePath,
            bridgeID: record.bridgeID,
            bridgeCertificateRootSHA256: record.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: record.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: record.w46AdjudicationReportRootSHA256,
            predecessorRecordRootSHA256: record.predecessorRecordRootSHA256,
            recordRootSHA256: record.declaredRecordRootSHA256
        )
        let records = (previous?.records ?? []) + [summary]
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(ledgerID: record.ledgerID, records: records)
        return .init(
            ledgerID: record.ledgerID,
            records: records,
            latestSequence: record.sequence,
            latestRecordRootSHA256: record.declaredRecordRootSHA256,
            declaredLedgerRootSHA256: root
        )
    }

    private static func loadValidatedHead(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager,
        allowedPendingRelativePath: String?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead? {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.unsafeLedgerID }
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        let headURL = ledgerURL.appendingPathComponent(headFileName)
        guard fileManager.fileExists(atPath: headURL.path) else {
            let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
            if fileManager.fileExists(atPath: recordsURL.path) {
                let names = try fileManager.contentsOfDirectory(atPath: recordsURL.path)
                let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
                if names.contains(where: { $0 != allowedName }) {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.forkedHistory
                }
            }
            return nil
        }
        let head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
        do {
            head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeHead(Data(contentsOf: headURL))
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger
        }
        guard head.schemaVersion == 1,
              head.ledgerID == ledgerID,
              !head.records.isEmpty,
              head.records == head.records.sorted(by: { $0.sequence < $1.sequence }),
              head.latestSequence == UInt64(head.records.count),
              head.records.last?.sequence == head.latestSequence,
              head.latestRecordRootSHA256 == head.records.last?.recordRootSHA256,
              isSHA256(head.latestRecordRootSHA256),
              isSHA256(head.declaredLedgerRootSHA256),
              (try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(ledgerID: ledgerID, records: head.records)) == head.declaredLedgerRootSHA256 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger
        }
        guard Set(head.records.map(\.bridgeID)).count == head.records.count,
              Set(head.records.map(\.w47PackageRootSHA256)).count == head.records.count,
              Set(head.records.map(\.bridgeCertificateRootSHA256)).count == head.records.count else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.forkedHistory
        }

        var previousRoot: String? = nil
        for (index, summary) in head.records.enumerated() {
            guard summary.sequence == UInt64(index + 1),
                  safeComponent(summary.bridgeID),
                  AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(summary.relativePath),
                  isSHA256(summary.bridgeCertificateRootSHA256),
                  isSHA256(summary.w47PackageRootSHA256),
                  isSHA256(summary.w46AdjudicationReportRootSHA256),
                  isSHA256(summary.recordRootSHA256),
                  summary.predecessorRecordRootSHA256 == previousRoot else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger
            }
            let record = try readRecord(relativePath: summary.relativePath, ledgerURL: ledgerURL)
            guard validateRecord(record),
                  record.sequence == summary.sequence,
                  record.bridgeID == summary.bridgeID,
                  record.bridgeCertificateRootSHA256 == summary.bridgeCertificateRootSHA256,
                  record.w47PackageRootSHA256 == summary.w47PackageRootSHA256,
                  record.w46AdjudicationReportRootSHA256 == summary.w46AdjudicationReportRootSHA256,
                  record.predecessorRecordRootSHA256 == summary.predecessorRecordRootSHA256,
                  record.declaredRecordRootSHA256 == summary.recordRootSHA256 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.corruptedLedger
            }
            previousRoot = summary.recordRootSHA256
        }

        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        let expectedNames = Set(head.records.map { URL(fileURLWithPath: $0.relativePath).lastPathComponent })
        let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let observedNames = Set((try? fileManager.contentsOfDirectory(atPath: recordsURL.path)) ?? [])
        let allowedNames = allowedName.map { expectedNames.union([$0]) } ?? expectedNames
        guard observedNames == expectedNames || observedNames == allowedNames else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLedgerError.forkedHistory
        }
        return head
    }
}
