import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let normalizationReceiptRootSHA256: String
    public let snapshotRootSHA256: String
    public let checkpointRootSHA256: String
    public let handoffRootSHA256: String
    public let custodyReceiptRootSHA256: String
    public let declaredCertificateRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        normalizationReceiptRootSHA256: String,
        snapshotRootSHA256: String,
        checkpointRootSHA256: String,
        handoffRootSHA256: String,
        custodyReceiptRootSHA256: String,
        declaredCertificateRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.normalizationReceiptRootSHA256 = normalizationReceiptRootSHA256.lowercased()
        self.snapshotRootSHA256 = snapshotRootSHA256.lowercased()
        self.checkpointRootSHA256 = checkpointRootSHA256.lowercased()
        self.handoffRootSHA256 = handoffRootSHA256.lowercased()
        self.custodyReceiptRootSHA256 = custodyReceiptRootSHA256.lowercased()
        self.declaredCertificateRootSHA256 = declaredCertificateRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionCertifiedNormalizedCustodyBundle: Codable, Equatable, Sendable {
    public let bundle: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle
    public let certificate: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate

    public init(
        bundle: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle,
        certificate: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate
    ) {
        self.bundle = bundle
        self.certificate = certificate
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let normalizationReceiptRootSHA256: String
        let snapshotRootSHA256: String
        let checkpointRootSHA256: String
        let handoffRootSHA256: String
        let custodyReceiptRootSHA256: String
    }

    public static func compute(
        _ value: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate
    ) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            ledgerID: value.ledgerID,
            normalizationReceiptRootSHA256: value.normalizationReceiptRootSHA256,
            snapshotRootSHA256: value.snapshotRootSHA256,
            checkpointRootSHA256: value.checkpointRootSHA256,
            handoffRootSHA256: value.handoffRootSHA256,
            custodyReceiptRootSHA256: value.custodyReceiptRootSHA256
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator {
    public static func make(
        bundle: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate {
        let custody = bundle.custodyBundle
        guard AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
            custody.receipt,
            snapshot: custody.snapshot,
            checkpoint: custody.checkpoint,
            handoff: custody.handoff
        ), normalizationMatchesSnapshot(bundle.normalizationReceipt, snapshot: custody.snapshot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
        }
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate(
            ledgerID: custody.snapshot.ledgerID,
            normalizationReceiptRootSHA256: bundle.normalizationReceipt.declaredReceiptRootSHA256,
            snapshotRootSHA256: custody.snapshot.declaredSnapshotRootSHA256,
            checkpointRootSHA256: custody.checkpoint.declaredCheckpointRootSHA256,
            handoffRootSHA256: custody.handoff.declaredHandoffRootSHA256,
            custodyReceiptRootSHA256: custody.receipt.declaredReceiptRootSHA256,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateRoot.compute(provisional)
        return .init(
            ledgerID: provisional.ledgerID,
            normalizationReceiptRootSHA256: provisional.normalizationReceiptRootSHA256,
            snapshotRootSHA256: provisional.snapshotRootSHA256,
            checkpointRootSHA256: provisional.checkpointRootSHA256,
            handoffRootSHA256: provisional.handoffRootSHA256,
            custodyReceiptRootSHA256: provisional.custodyReceiptRootSHA256,
            declaredCertificateRootSHA256: root
        )
    }

    public static func validate(
        _ certificate: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate,
        bundle: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle
    ) -> Bool {
        let custody = bundle.custodyBundle
        guard certificate.schemaVersion == 1,
              certificate.ledgerID == custody.snapshot.ledgerID,
              certificate.normalizationReceiptRootSHA256 == bundle.normalizationReceipt.declaredReceiptRootSHA256,
              certificate.snapshotRootSHA256 == custody.snapshot.declaredSnapshotRootSHA256,
              certificate.checkpointRootSHA256 == custody.checkpoint.declaredCheckpointRootSHA256,
              certificate.handoffRootSHA256 == custody.handoff.declaredHandoffRootSHA256,
              certificate.custodyReceiptRootSHA256 == custody.receipt.declaredReceiptRootSHA256,
              [
                certificate.normalizationReceiptRootSHA256,
                certificate.snapshotRootSHA256,
                certificate.checkpointRootSHA256,
                certificate.handoffRootSHA256,
                certificate.custodyReceiptRootSHA256,
                certificate.declaredCertificateRootSHA256
              ].allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256),
              normalizationMatchesSnapshot(bundle.normalizationReceipt, snapshot: custody.snapshot),
              AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
                custody.receipt,
                snapshot: custody.snapshot,
                checkpoint: custody.checkpoint,
                handoff: custody.handoff
              ),
              (try? AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateRoot.compute(certificate)) == certificate.declaredCertificateRootSHA256 else {
            return false
        }
        return true
    }

    private static func normalizationMatchesSnapshot(
        _ receipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt,
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) -> Bool {
        receipt.ledgerID == snapshot.ledgerID
            && receipt.latestSequence == snapshot.latestSequence
            && receipt.ledgerRootSHA256 == snapshot.ledgerRootSHA256
            && receipt.latestRecordRootSHA256 == snapshot.latestRecordRootSHA256
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.declaredReceiptRootSHA256)
            && (try? AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceiptRoot.compute(receipt)) == receipt.declaredReceiptRootSHA256
    }
}

public extension AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager {
    static func makeCertifiedCustodyBundle(
        ledgerID: String,
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        transactionID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        checkpointApprovalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        handoffID: String,
        handoffApprovalReference: String,
        previousHandoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCertifiedNormalizedCustodyBundle {
        let bundle = try makeCustodyBundle(
            ledgerID: ledgerID,
            expectedSnapshot: expectedSnapshot,
            transactionID: transactionID,
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            checkpointApprovalReference: checkpointApprovalReference,
            previousCheckpoint: previousCheckpoint,
            handoffID: handoffID,
            handoffApprovalReference: handoffApprovalReference,
            previousHandoff: previousHandoff,
            rootURL: rootURL,
            fileManager: fileManager
        )
        let certificate = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator.make(
            bundle: bundle
        )
        guard AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator.validate(
            certificate,
            bundle: bundle
        ) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
        }
        return .init(bundle: bundle, certificate: certificate)
    }
}
