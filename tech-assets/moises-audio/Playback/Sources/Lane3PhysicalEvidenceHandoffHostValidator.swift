import Foundation

public enum Lane3PhysicalEvidenceHandoffHostValidationError: Error, Equatable, Sendable {
    case malformedManifest
    case schemaShapeMismatch
    case unsupportedSchemaVersion
    case unexpectedEvidenceScope
    case parityPromotionRequested
    case evidenceMismatch
}

/// Host/HQ-side receipt emitted only after a serialized Lane 3 physical-evidence handoff manifest
/// is decoded and rebound to the exact session plan, device evidence bundle, and resource traces.
///
/// This receipt is intentionally NON_PARITY. It is a deterministic tamper-evident acceptance record,
/// not a signature, provenance proof, physical-device execution result, or PARITY promotion.
public struct Lane3PhysicalEvidenceHandoffHostReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let manifestBindingSHA256: String
    public let planBindingSHA256: String
    public let deviceBundleBindingSHA256: String
    public let resourceTraceSetBindingSHA256: String
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    fileprivate static let receiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_HOST_RECEIPT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.receiptScope,
              acceptedForHQReview,
              !parityPromotionAllowed else {
            return false
        }

        return receiptBindingSHA256 == Self.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            manifestBindingSHA256: manifestBindingSHA256,
            planBindingSHA256: planBindingSHA256,
            deviceBundleBindingSHA256: deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256: resourceTraceSetBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func make(
        manifest: Lane3PhysicalEvidenceHandoffManifest
    ) -> Lane3PhysicalEvidenceHandoffHostReceipt {
        let schemaVersion = 1
        let evidenceScope = receiptScope
        let acceptedForHQReview = true
        let parityPromotionAllowed = false
        let binding = computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: manifest.sessionIdentifier,
            appBuildCommitSHA: manifest.appBuildCommitSHA,
            manifestBindingSHA256: manifest.manifestBindingSHA256,
            planBindingSHA256: manifest.planBindingSHA256,
            deviceBundleBindingSHA256: manifest.deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256: manifest.resourceTraceSetBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )

        return Lane3PhysicalEvidenceHandoffHostReceipt(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: manifest.sessionIdentifier,
            appBuildCommitSHA: manifest.appBuildCommitSHA,
            manifestBindingSHA256: manifest.manifestBindingSHA256,
            planBindingSHA256: manifest.planBindingSHA256,
            deviceBundleBindingSHA256: manifest.deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256: manifest.resourceTraceSetBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed,
            receiptBindingSHA256: binding
        )
    }

    private static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        manifestBindingSHA256: String,
        planBindingSHA256: String,
        deviceBundleBindingSHA256: String,
        resourceTraceSetBindingSHA256: String,
        acceptedForHQReview: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_HOST_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            manifestBindingSHA256,
            planBindingSHA256,
            deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256,
            acceptedForHQReview ? "true" : "false",
            parityPromotionAllowed ? "true" : "false"
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffHostValidator {
    private static let supportedManifestScope = "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_MANIFEST_V1_NON_PARITY"
    private static let expectedManifestKeys: Set<String> = [
        "schemaVersion",
        "evidenceScope",
        "sessionIdentifier",
        "appBuildCommitSHA",
        "deviceModel",
        "osVersion",
        "audioRoute",
        "fixtureID",
        "currentMoisesReferenceSnapshotID",
        "currentMoisesVersion",
        "planBindingSHA256",
        "deviceBundleBindingSHA256",
        "resourceTraceSetBindingSHA256",
        "manifestBindingSHA256",
        "parityPromotionAllowed"
    ]

    /// Validates the serialized handoff boundary rather than trusting a caller-constructed manifest.
    /// Unknown/missing top-level fields, unsupported schema/scope, PARITY promotion requests, digest
    /// mutations, and substitution of any bound evidence input all fail closed.
    public static func validate(
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Lane3PhysicalEvidenceHandoffHostReceipt {
        try validateSchemaShape(manifestJSON)

        let manifest: Lane3PhysicalEvidenceHandoffManifest
        do {
            manifest = try JSONDecoder().decode(
                Lane3PhysicalEvidenceHandoffManifest.self,
                from: manifestJSON
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.malformedManifest
        }

        guard manifest.schemaVersion == 1 else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.unsupportedSchemaVersion
        }
        guard manifest.evidenceScope == supportedManifestScope else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.unexpectedEvidenceScope
        }
        guard !manifest.parityPromotionAllowed else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.parityPromotionRequested
        }
        guard manifest.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.evidenceMismatch
        }

        let verified: Bool
        do {
            verified = try Lane3PhysicalEvidenceHandoffManifestBuilder.verify(
                manifest,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.evidenceMismatch
        }
        guard verified else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.evidenceMismatch
        }

        let receipt = Lane3PhysicalEvidenceHandoffHostReceipt.make(manifest: manifest)
        guard receipt.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.evidenceMismatch
        }
        return receipt
    }

    /// Replays host validation and requires byte-decoded evidence to yield the exact prior receipt.
    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffHostReceipt,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Bool {
        guard receipt.verifyIntegrity() else { return false }
        do {
            return try validate(
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            ) == receipt
        } catch {
            return false
        }
    }

    private static func validateSchemaShape(_ manifestJSON: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: manifestJSON)
        } catch {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.malformedManifest
        }
        guard let dictionary = object as? [String: Any] else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.malformedManifest
        }
        guard Set(dictionary.keys) == expectedManifestKeys else {
            throw Lane3PhysicalEvidenceHandoffHostValidationError.schemaShapeMismatch
        }
    }
}
