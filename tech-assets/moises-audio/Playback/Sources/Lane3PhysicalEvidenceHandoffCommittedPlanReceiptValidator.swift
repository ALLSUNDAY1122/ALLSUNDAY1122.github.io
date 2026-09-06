import Foundation

public enum Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError: Error, Equatable, Sendable {
    case malformedReceipt
    case schemaShapeMismatch
    case unsupportedSchemaVersion
    case unexpectedEvidenceScope
    case receiptNotAccepted
    case parityPromotionRequested
    case invalidReceiptIntegrity
    case sourceArtifactsMismatch
}

/// Re-validates a persisted committed-plan receipt against the exact source artifacts that originally
/// produced it. This closes the persistence boundary where a structurally valid receipt could otherwise
/// be detached from its commitment/manifest/plan/bundle/resource-trace tuple before later HQ review.
///
/// This remains NON_PARITY evidence. The SHA-256 fields are tamper-evident bindings, not signatures.
public enum Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator {
    private static let supportedReceiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_COMMITTED_PLAN_HANDOFF_RECEIPT_V1_NON_PARITY"
    private static let expectedKeys: Set<String> = [
        "schemaVersion",
        "evidenceScope",
        "sessionIdentifier",
        "appBuildCommitSHA",
        "expectedPlanCommitmentReceiptBindingSHA256",
        "handoffReceiptBindingSHA256",
        "acceptedForHQReview",
        "parityPromotionAllowed",
        "receiptBindingSHA256"
    ]

    public static func validate(
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt {
        try validateSchemaShape(receiptJSON)

        let persistedReceipt: Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt
        do {
            persistedReceipt = try JSONDecoder().decode(
                Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt.self,
                from: receiptJSON
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.malformedReceipt
        }

        guard persistedReceipt.schemaVersion == 1 else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.unsupportedSchemaVersion
        }
        guard persistedReceipt.evidenceScope == supportedReceiptScope else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.unexpectedEvidenceScope
        }
        guard persistedReceipt.acceptedForHQReview else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.receiptNotAccepted
        }
        guard !persistedReceipt.parityPromotionAllowed else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.parityPromotionRequested
        }
        guard persistedReceipt.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.invalidReceiptIntegrity
        }

        let reboundReceipt = try Lane3PhysicalEvidenceHandoffCommittedPlanHostValidator.validate(
            commitmentJSON: commitmentJSON,
            expectedPlan: expectedPlan,
            manifestJSON: manifestJSON,
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )

        guard persistedReceipt == reboundReceipt else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.sourceArtifactsMismatch
        }

        return persistedReceipt
    }

    public static func verify(
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Bool {
        do {
            let receipt = try validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            )
            return receipt.verifyIntegrity()
        } catch {
            return false
        }
    }

    private static func validateSchemaShape(_ data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.malformedReceipt
        }

        guard let dictionary = object as? [String: Any],
              Set(dictionary.keys) == expectedKeys else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError.schemaShapeMismatch
        }
    }
}
