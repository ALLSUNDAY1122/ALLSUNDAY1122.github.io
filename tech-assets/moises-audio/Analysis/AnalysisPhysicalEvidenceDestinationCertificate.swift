import Foundation

public enum AnalysisPhysicalEvidenceDestinationVerificationStatus: String, Codable, Sendable {
    case verifiedAgainstExternalAnchorNonParity = "VERIFIED_AGAINST_EXTERNAL_ANCHOR_NON_PARITY"
}

public struct AnalysisPhysicalEvidenceDestinationVerificationCertificate: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalEvidenceDestinationVerificationStatus
    public let anchorID: String
    public let anchorSequence: UInt64
    public let anchorReceiptRootSHA256: String
    public let publicationID: String
    public let transferID: String
    public let expectedW27RootSHA256: String
    public let expectedW38RootSHA256: String
    public let expectedW40RootSHA256: String
    public let expectedW41RootSHA256: String
    public let destinationW27RootSHA256: String
    public let destinationW38RootSHA256: String
    public let destinationW40RootSHA256: String
    public let destinationW41RootSHA256: String
    public let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let limitations: [String]
    public let declaredCertificateRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalEvidenceDestinationVerificationStatus,
        anchorID: String,
        anchorSequence: UInt64,
        anchorReceiptRootSHA256: String,
        publicationID: String,
        transferID: String,
        expectedW27RootSHA256: String,
        expectedW38RootSHA256: String,
        expectedW40RootSHA256: String,
        expectedW41RootSHA256: String,
        destinationW27RootSHA256: String,
        destinationW38RootSHA256: String,
        destinationW40RootSHA256: String,
        destinationW41RootSHA256: String,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary],
        limitations: [String],
        declaredCertificateRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.anchorID = anchorID
        self.anchorSequence = anchorSequence
        self.anchorReceiptRootSHA256 = anchorReceiptRootSHA256.lowercased()
        self.publicationID = publicationID
        self.transferID = transferID
        self.expectedW27RootSHA256 = expectedW27RootSHA256.lowercased()
        self.expectedW38RootSHA256 = expectedW38RootSHA256.lowercased()
        self.expectedW40RootSHA256 = expectedW40RootSHA256.lowercased()
        self.expectedW41RootSHA256 = expectedW41RootSHA256.lowercased()
        self.destinationW27RootSHA256 = destinationW27RootSHA256.lowercased()
        self.destinationW38RootSHA256 = destinationW38RootSHA256.lowercased()
        self.destinationW40RootSHA256 = destinationW40RootSHA256.lowercased()
        self.destinationW41RootSHA256 = destinationW41RootSHA256.lowercased()
        self.runs = runs.sorted { $0.runID < $1.runID }
        self.limitations = limitations
        self.declaredCertificateRootSHA256 = declaredCertificateRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalEvidenceAnchorReceiptValidator {
    public static func validate(
        _ receipt: AnalysisPhysicalEvidenceAnchorReceipt,
        expectation: AnalysisPhysicalEvidenceAnchorExpectation
    ) throws {
        guard validateExpectation(expectation) else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.invalidExpectation
        }
        guard receipt.schemaVersion == 1,
              AnalysisPhysicalEvidenceAnchorReceiptIssuer.validateAnchor(receipt.anchor),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.declaredAnchorReceiptRootSHA256) else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.invalidAnchorReceipt
        }
        let computed = try AnalysisPhysicalEvidenceAnchorReceiptRoot.compute(receipt.anchor)
        guard computed == receipt.declaredAnchorReceiptRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.anchorReceiptRootMismatch
        }
        guard receipt.anchor.anchorID == expectation.expectedAnchorID else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.anchorIdentityMismatch
        }
        guard receipt.anchor.anchorSequence >= expectation.minimumAnchorSequence else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.staleAnchorSequence
        }
        guard receipt.declaredAnchorReceiptRootSHA256.lowercased() == expectation.expectedAnchorReceiptRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.staleAnchorReceipt
        }
        guard receipt.anchor.publicationID == expectation.expectedPublicationID else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.publicationIdentityMismatch
        }
        guard receipt.anchor.transferID == expectation.expectedTransferID else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.transferIdentityMismatch
        }
        guard receipt.anchor.predecessorAnchorReceiptRootSHA256?.lowercased()
                == expectation.expectedPredecessorAnchorReceiptRootSHA256?.lowercased() else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.predecessorAnchorMismatch
        }
    }

    public static func validateExpectation(_ value: AnalysisPhysicalEvidenceAnchorExpectation) -> Bool {
        let predecessorIsValid = value.expectedPredecessorAnchorReceiptRootSHA256.map {
            AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0)
        } ?? true
        return value.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.expectedAnchorID)
            && value.minimumAnchorSequence > 0
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.expectedAnchorReceiptRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.expectedPublicationID)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.expectedTransferID)
            && predecessorIsValid
    }
}

public enum AnalysisPhysicalEvidenceDestinationCertificateRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let status: AnalysisPhysicalEvidenceDestinationVerificationStatus
        let anchorID: String
        let anchorSequence: UInt64
        let anchorReceiptRootSHA256: String
        let publicationID: String
        let transferID: String
        let expectedW27RootSHA256: String
        let expectedW38RootSHA256: String
        let expectedW40RootSHA256: String
        let expectedW41RootSHA256: String
        let destinationW27RootSHA256: String
        let destinationW38RootSHA256: String
        let destinationW40RootSHA256: String
        let destinationW41RootSHA256: String
        let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
        let limitations: [String]
    }

    public static func compute(_ certificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate) throws -> String {
        let payload = Payload(
            schemaVersion: certificate.schemaVersion,
            status: certificate.status,
            anchorID: certificate.anchorID,
            anchorSequence: certificate.anchorSequence,
            anchorReceiptRootSHA256: certificate.anchorReceiptRootSHA256.lowercased(),
            publicationID: certificate.publicationID,
            transferID: certificate.transferID,
            expectedW27RootSHA256: certificate.expectedW27RootSHA256.lowercased(),
            expectedW38RootSHA256: certificate.expectedW38RootSHA256.lowercased(),
            expectedW40RootSHA256: certificate.expectedW40RootSHA256.lowercased(),
            expectedW41RootSHA256: certificate.expectedW41RootSHA256.lowercased(),
            destinationW27RootSHA256: certificate.destinationW27RootSHA256.lowercased(),
            destinationW38RootSHA256: certificate.destinationW38RootSHA256.lowercased(),
            destinationW40RootSHA256: certificate.destinationW40RootSHA256.lowercased(),
            destinationW41RootSHA256: certificate.destinationW41RootSHA256.lowercased(),
            runs: certificate.runs.sorted { $0.runID < $1.runID },
            limitations: certificate.limitations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceDestinationAnchorVerifier {
    public static let limitations = [
        "NON_PARITY: successful verification proves package integrity against a caller-supplied external root anchor, not product parity.",
        "The anchor receipt and certificate are SHA-256 metadata commitments, not signatures, trusted timestamps, Secure Enclave proofs or Apple attestation.",
        "Trust depends on HQ preserving the expectation/receipt root independently from the W41 package.",
        "An identical byte-for-byte re-copy of the currently anchored package is intentionally accepted; replay substitution with a stale or different package is rejected by identity/root/sequence checks."
    ]

    public static func verifyDestination(
        transferDirectoryURL: URL,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        expectation: AnalysisPhysicalEvidenceAnchorExpectation,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceDestinationVerificationCertificate {
        try AnalysisPhysicalEvidenceAnchorReceiptValidator.validate(anchorReceipt, expectation: expectation)
        let manifest: AnalysisPhysicalEvidenceTransferManifest
        do {
            manifest = try AnalysisPhysicalEvidenceTransferVerifier.verify(
                transferDirectoryURL: transferDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisPhysicalEvidenceExternalAnchorError.destinationTransferVerificationFailed
        }
        return try verifyAlreadyValidatedTransfer(
            manifest,
            anchorReceipt: anchorReceipt,
            expectation: expectation
        )
    }

    /// Internal seam for adversarial XCTest. Production callers use
    /// `verifyDestination`, which first executes the full W41 destination verifier.
    static func verifyAlreadyValidatedTransfer(
        _ manifest: AnalysisPhysicalEvidenceTransferManifest,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        expectation: AnalysisPhysicalEvidenceAnchorExpectation
    ) throws -> AnalysisPhysicalEvidenceDestinationVerificationCertificate {
        try AnalysisPhysicalEvidenceAnchorReceiptValidator.validate(anchorReceipt, expectation: expectation)
        let anchor = anchorReceipt.anchor
        guard manifest.publicationID == anchor.publicationID else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.publicationIdentityMismatch
        }
        guard manifest.transferID == anchor.transferID else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.transferIdentityMismatch
        }
        guard manifest.runs == anchor.runs else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.runInventoryMismatch
        }
        guard manifest.w27RootSHA256.lowercased() == anchor.w27RootSHA256,
              manifest.w38RootSHA256.lowercased() == anchor.w38RootSHA256,
              manifest.w40RootSHA256.lowercased() == anchor.w40RootSHA256,
              manifest.declaredTransferRootSHA256.lowercased() == anchor.w41RootSHA256 else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.rootSetMismatch
        }

        let provisional = AnalysisPhysicalEvidenceDestinationVerificationCertificate(
            status: .verifiedAgainstExternalAnchorNonParity,
            anchorID: anchor.anchorID,
            anchorSequence: anchor.anchorSequence,
            anchorReceiptRootSHA256: anchorReceipt.declaredAnchorReceiptRootSHA256,
            publicationID: manifest.publicationID,
            transferID: manifest.transferID,
            expectedW27RootSHA256: anchor.w27RootSHA256,
            expectedW38RootSHA256: anchor.w38RootSHA256,
            expectedW40RootSHA256: anchor.w40RootSHA256,
            expectedW41RootSHA256: anchor.w41RootSHA256,
            destinationW27RootSHA256: manifest.w27RootSHA256,
            destinationW38RootSHA256: manifest.w38RootSHA256,
            destinationW40RootSHA256: manifest.w40RootSHA256,
            destinationW41RootSHA256: manifest.declaredTransferRootSHA256,
            runs: manifest.runs,
            limitations: limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root: String
        do {
            root = try AnalysisPhysicalEvidenceDestinationCertificateRoot.compute(provisional)
        } catch {
            throw AnalysisPhysicalEvidenceExternalAnchorError.certificateRootFailure
        }
        return .init(
            status: provisional.status,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            publicationID: provisional.publicationID,
            transferID: provisional.transferID,
            expectedW27RootSHA256: provisional.expectedW27RootSHA256,
            expectedW38RootSHA256: provisional.expectedW38RootSHA256,
            expectedW40RootSHA256: provisional.expectedW40RootSHA256,
            expectedW41RootSHA256: provisional.expectedW41RootSHA256,
            destinationW27RootSHA256: provisional.destinationW27RootSHA256,
            destinationW38RootSHA256: provisional.destinationW38RootSHA256,
            destinationW40RootSHA256: provisional.destinationW40RootSHA256,
            destinationW41RootSHA256: provisional.destinationW41RootSHA256,
            runs: provisional.runs,
            limitations: provisional.limitations,
            declaredCertificateRootSHA256: root
        )
    }
}

public enum AnalysisPhysicalEvidenceDestinationCertificateCodec {
    public static func encode(_ value: AnalysisPhysicalEvidenceDestinationVerificationCertificate) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decode(_ data: Data) throws -> AnalysisPhysicalEvidenceDestinationVerificationCertificate {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceDestinationVerificationCertificate.self, from: data)
    }
}
