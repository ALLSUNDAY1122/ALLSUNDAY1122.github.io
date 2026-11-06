import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let expectedLatestSequence: UInt64
    public let expectedLedgerRootSHA256: String?
    public let expectedLatestRecordRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        expectedLatestSequence: UInt64,
        expectedLedgerRootSHA256: String?,
        expectedLatestRecordRootSHA256: String?
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.expectedLatestSequence = expectedLatestSequence
        self.expectedLedgerRootSHA256 = expectedLedgerRootSHA256?.lowercased()
        self.expectedLatestRecordRootSHA256 = expectedLatestRecordRootSHA256?.lowercased()
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError: Error, Equatable, Sendable {
    case invalidCAS
    case staleWriterCAS
    case postCommitVerificationFailed
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore {
    public static let limitations = [
        "NON_PARITY: W51 serializes W50 bridge-consumption writers and rejects stale predecessor views; it does not promote any Analysis PARITY row.",
        "W56 marks the W51 public entrypoints as migration-only. Debug compatibility calls route through W55 normalized access; Release production calls fail closed because their legacy return shapes cannot carry W55 normalization evidence.",
        "Same-process NSLock plus OS advisory flock serialize cooperating writers. The lock file is persistent by design so process termination releases the kernel lock without requiring stale-file deletion.",
        "The append CAS binds the exact predecessor sequence, ledger root and latest record root observed before publication. A writer whose view became stale fails closed before publishing a second candidate for that sequence."
    ]

    @available(*, deprecated, message: "Migration-only W51 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS so W55 normalization evidence is retained.")
    public static func observeAppendCAS(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.concurrentObserveAppendCAS)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ).cas
    }

    @discardableResult
    @available(*, deprecated, message: "Migration-only W51 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append so the predecessor normalization receipt is retained.")
    public static func append(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        expectedCAS: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.concurrentAppend)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append(
            ledgerID: ledgerID,
            certificate: certificate,
            custody: custody,
            expectedCAS: expectedCAS,
            rootURL: rootURL,
            fileManager: fileManager
        ).head
    }

    @discardableResult
    static func appendForTesting(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        expectedCAS: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        rootURL: URL,
        fileManager: FileManager = .default,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try appendInternal(
            ledgerID: ledgerID,
            certificate: certificate,
            custody: custody,
            expectedCAS: expectedCAS,
            rootURL: rootURL,
            fileManager: fileManager,
            injectedFault: injectedFault
        )
    }

    @available(*, deprecated, message: "Migration-only W51 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.consumedW47PackageRootSHA256s so W55 normalization evidence is retained.")
    public static func consumedW47PackageRootSHA256s(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> [String] {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.concurrentConsumedInventory)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.consumedW47PackageRootSHA256s(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ).roots
    }

    @available(*, deprecated, message: "Migration-only W51 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.expectationUsingNormalizedConsumedInventory so W55 normalization evidence is retained.")
    public static func expectationUsingSerializedConsumedInventory(
        base: AnalysisPhysicalRealAudioParityBridgeExpectation,
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioParityBridgeExpectation {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.concurrentExpectation)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.expectationUsingNormalizedConsumedInventory(
            base: base,
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ).expectation
    }

    static func validateCAS(_ value: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS) -> Bool {
        guard value.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.ledgerID) else { return false }
        if value.expectedLatestSequence == 0 {
            return value.expectedLedgerRootSHA256 == nil && value.expectedLatestRecordRootSHA256 == nil
        }
        return value.expectedLedgerRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) == true
            && value.expectedLatestRecordRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) == true
    }

    private static func appendInternal(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        expectedCAS: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        rootURL: URL,
        fileManager: FileManager,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        guard expectedCAS.ledgerID == ledgerID, validateCAS(expectedCAS) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.invalidCAS
        }
        return try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: ledgerID,
            rootURL: rootURL
        ) { lease in
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            )
            _ = try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.garbageCollectInterruptedPublicationTemps(
                ledgerID: ledgerID,
                rootURL: rootURL,
                lease: lease,
                fileManager: fileManager
            )
            _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            )
            let predecessor = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            )
            let actualCAS = makeCAS(ledgerID: ledgerID, head: predecessor)
            guard actualCAS == expectedCAS else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.staleWriterCAS
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)

            let newHead: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
            if let injectedFault {
                newHead = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
                    ledgerID: ledgerID,
                    certificate: certificate,
                    custody: custody,
                    rootURL: rootURL,
                    fileManager: fileManager,
                    injectedFault: injectedFault
                )
            } else {
                newHead = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
                    ledgerID: ledgerID,
                    certificate: certificate,
                    custody: custody,
                    rootURL: rootURL,
                    fileManager: fileManager
                )
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            guard verifiesCommit(predecessorCAS: expectedCAS, head: newHead, certificate: certificate) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.postCommitVerificationFailed
            }
            guard let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            ), reopened == newHead else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.postCommitVerificationFailed
            }
            return newHead
        }
    }

    private static func makeCAS(
        ledgerID: String,
        head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead?
    ) -> AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS {
        guard let head else {
            return .init(
                ledgerID: ledgerID,
                expectedLatestSequence: 0,
                expectedLedgerRootSHA256: nil,
                expectedLatestRecordRootSHA256: nil
            )
        }
        return .init(
            ledgerID: ledgerID,
            expectedLatestSequence: head.latestSequence,
            expectedLedgerRootSHA256: head.declaredLedgerRootSHA256,
            expectedLatestRecordRootSHA256: head.latestRecordRootSHA256
        )
    }

    private static func verifiesCommit(
        predecessorCAS: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate
    ) -> Bool {
        guard head.ledgerID == predecessorCAS.ledgerID,
              head.latestSequence == predecessorCAS.expectedLatestSequence + 1,
              head.records.count == Int(head.latestSequence),
              let last = head.records.last,
              last.sequence == head.latestSequence,
              last.bridgeID == certificate.bridgeID,
              last.bridgeCertificateRootSHA256 == certificate.declaredCertificateRootSHA256,
              last.w47PackageRootSHA256 == certificate.w47PackageRootSHA256,
              last.w46AdjudicationReportRootSHA256 == certificate.w46AdjudicationReportRootSHA256 else {
            return false
        }
        let prefix = Array(head.records.dropLast())
        if predecessorCAS.expectedLatestSequence == 0 {
            return prefix.isEmpty && last.predecessorRecordRootSHA256 == nil
        }
        guard prefix.count == Int(predecessorCAS.expectedLatestSequence),
              prefix.last?.recordRootSHA256 == predecessorCAS.expectedLatestRecordRootSHA256,
              last.predecessorRecordRootSHA256 == predecessorCAS.expectedLatestRecordRootSHA256,
              let root = try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: head.ledgerID,
                records: prefix
              ), root == predecessorCAS.expectedLedgerRootSHA256 else {
            return false
        }
        return true
    }
}
