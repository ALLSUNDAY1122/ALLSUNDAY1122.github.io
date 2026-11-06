import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAppendResult: Codable, Equatable, Sendable {
    public let head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
    public let predecessorNormalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt

    public init(
        head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead,
        predecessorNormalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        self.head = head
        self.predecessorNormalizationReceipt = predecessorNormalizationReceipt
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore {
    public static let limitations = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.limitations + [
        "W55 normalized concurrent entrypoints supersede manual W51 bootstrap/GC/recovery sequencing for production custody operations while preserving W51 CAS semantics.",
        "The returned normalization receipt describes the exact predecessor ledger state observed under the same writer lease before append authorization is checked."
    ]

    public static func observeAppendCAS(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> (
        cas: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: false
        ) { _, state in
            (makeCAS(ledgerID: ledgerID, head: state.head), state.receipt)
        }
    }

    @discardableResult
    public static func append(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        expectedCAS: AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAppendResult {
        guard expectedCAS.ledgerID == ledgerID,
              AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.validateCAS(expectedCAS) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.invalidCAS
        }
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: expectedCAS.expectedLatestSequence > 0
        ) { lease, state in
            let actualCAS = makeCAS(ledgerID: ledgerID, head: state.head)
            guard actualCAS == expectedCAS else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.staleWriterCAS
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
                ledgerID: ledgerID,
                certificate: certificate,
                custody: custody,
                rootURL: rootURL,
                fileManager: fileManager
            )
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            guard verifiesCommit(predecessorCAS: expectedCAS, head: head, certificate: certificate),
                  let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                    ledgerID: ledgerID,
                    rootURL: rootURL,
                    fileManager: fileManager
                  ), reopened == head else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError.postCommitVerificationFailed
            }
            return .init(head: head, predecessorNormalizationReceipt: state.receipt)
        }
    }

    public static func consumedW47PackageRootSHA256s(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> (
        roots: [String],
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: false
        ) { _, state in
            (state.head?.records.map(\.w47PackageRootSHA256).sorted() ?? [], state.receipt)
        }
    }

    public static func expectationUsingNormalizedConsumedInventory(
        base: AnalysisPhysicalRealAudioParityBridgeExpectation,
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> (
        expectation: AnalysisPhysicalRealAudioParityBridgeExpectation,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        let observed = try consumedW47PackageRootSHA256s(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        let expectation = AnalysisPhysicalRealAudioParityBridgeExpectation(
            schemaVersion: base.schemaVersion,
            authority: base.authority,
            approvalReference: base.approvalReference,
            bridgeID: base.bridgeID,
            expectedW47PackageRootSHA256: base.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: base.expectedW47PackageBytesSHA256,
            expectedManifestID: base.expectedManifestID,
            expectedManifestSHA256: base.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: base.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: base.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: base.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: base.expectedW46BindingSHA256,
            previouslyConsumedW47PackageRootSHA256s: observed.roots
        )
        return (expectation, observed.normalizationReceipt)
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
