import Foundation

public enum Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentError: Error, Equatable, Sendable {
    case invalidPlanEnvelope
}

/// Persistable, tamper-evident commitment to the exact Lane 3 physical-evidence plan HQ selected
/// before evidence collection begins.
///
/// This artifact is intentionally NON_PARITY. Its SHA-256 binding detects mutation or accidental
/// substitution after the commitment is retained separately, but it is not a signature and does not
/// establish who created the plan or protect against an actor that can replace both the plan and its
/// commitment artifact.
public struct Lane3PhysicalEvidenceHandoffExpectedPlanCommitment: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let fixtureID: String
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let expectedPlanBindingSHA256: String
    public let parityPromotionAllowed: Bool
    public let commitmentBindingSHA256: String

    fileprivate static let commitmentScope = "LANE3_HQ_PHYSICAL_EVIDENCE_EXPECTED_PLAN_COMMITMENT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.commitmentScope,
              !parityPromotionAllowed,
              Self.isLowercaseHex(expectedPlanBindingSHA256, length: 64),
              Self.isLowercaseHex(commitmentBindingSHA256, length: 64) else {
            return false
        }

        return commitmentBindingSHA256 == Self.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: deviceModel,
            osVersion: osVersion,
            audioRoute: audioRoute,
            fixtureID: fixtureID,
            currentMoisesReferenceSnapshotID: currentMoisesReferenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
            expectedPlanBindingSHA256: expectedPlanBindingSHA256,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        fixtureID: String,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        expectedPlanBindingSHA256: String,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_EXPECTED_PLAN_COMMITMENT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            deviceModel,
            osVersion,
            audioRoute.rawValue,
            fixtureID,
            currentMoisesReferenceSnapshotID,
            currentMoisesVersion,
            expectedPlanBindingSHA256,
            parityPromotionAllowed ? "1" : "0"
        ])
    }

    fileprivate static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.unicodeScalars.allSatisfy {
            ($0.value >= 48 && $0.value <= 57) || ($0.value >= 97 && $0.value <= 102)
        }
    }
}

public enum Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder {
    private static let supportedPlanScope = "LANE3_AW51_PHYSICAL_DEVICE_SESSION_PLAN_NON_PARITY"

    public static func make(
        expectedPlan: Lane3PhysicalEvidenceSessionPlan
    ) throws -> Lane3PhysicalEvidenceHandoffExpectedPlanCommitment {
        guard expectedPlan.schemaVersion == 1,
              expectedPlan.evidenceScope == supportedPlanScope,
              expectedPlan.sessionStartAllowed,
              expectedPlan.preflightIssues.isEmpty,
              !expectedPlan.parityPromotionAllowed,
              !expectedPlan.steps.isEmpty,
              !expectedPlan.targetedParityRows.isEmpty,
              !expectedPlan.sessionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isLowercaseHex(expectedPlan.appBuildCommitSHA, length: 40),
              !expectedPlan.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !expectedPlan.currentMoisesReferenceSnapshotID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !expectedPlan.currentMoisesVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentError.invalidPlanEnvelope
        }

        let planBinding = computeExpectedPlanBinding(expectedPlan)
        let schemaVersion = 1
        let evidenceScope = Lane3PhysicalEvidenceHandoffExpectedPlanCommitment.commitmentScope
        let parityPromotionAllowed = false
        let commitmentBinding = Lane3PhysicalEvidenceHandoffExpectedPlanCommitment.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: expectedPlan.sessionIdentifier,
            appBuildCommitSHA: expectedPlan.appBuildCommitSHA,
            deviceModel: expectedPlan.deviceModel,
            osVersion: expectedPlan.osVersion,
            audioRoute: expectedPlan.audioRoute,
            fixtureID: expectedPlan.fixtureID,
            currentMoisesReferenceSnapshotID: expectedPlan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: expectedPlan.currentMoisesVersion,
            expectedPlanBindingSHA256: planBinding,
            parityPromotionAllowed: parityPromotionAllowed
        )

        return Lane3PhysicalEvidenceHandoffExpectedPlanCommitment(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: expectedPlan.sessionIdentifier,
            appBuildCommitSHA: expectedPlan.appBuildCommitSHA,
            deviceModel: expectedPlan.deviceModel,
            osVersion: expectedPlan.osVersion,
            audioRoute: expectedPlan.audioRoute,
            fixtureID: expectedPlan.fixtureID,
            currentMoisesReferenceSnapshotID: expectedPlan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: expectedPlan.currentMoisesVersion,
            expectedPlanBindingSHA256: planBinding,
            parityPromotionAllowed: parityPromotionAllowed,
            commitmentBindingSHA256: commitmentBinding
        )
    }

    public static func verify(
        _ commitment: Lane3PhysicalEvidenceHandoffExpectedPlanCommitment,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan
    ) -> Bool {
        guard commitment.verifyIntegrity() else { return false }
        do {
            return try make(expectedPlan: expectedPlan) == commitment
        } catch {
            return false
        }
    }

    private static func computeExpectedPlanBinding(
        _ plan: Lane3PhysicalEvidenceSessionPlan
    ) -> String {
        var fields = [
            "LANE3_HQ_PHYSICAL_EVIDENCE_EXPECTED_PLAN_BINDING_V1",
            String(plan.schemaVersion),
            plan.evidenceScope,
            plan.sessionIdentifier,
            plan.appBuildCommitSHA,
            plan.deviceModel,
            plan.osVersion,
            plan.audioRoute.rawValue,
            plan.currentMoisesReferenceSnapshotID,
            plan.currentMoisesVersion,
            plan.fixtureID,
            plan.sessionStartAllowed ? "1" : "0",
            plan.parityPromotionAllowed ? "1" : "0"
        ]

        appendStringArray(plan.targetedParityRows, label: "targetedParityRows", to: &fields)

        fields.append("preflightIssues.count=\(plan.preflightIssues.count)")
        for (index, issue) in plan.preflightIssues.enumerated() {
            fields.append("preflightIssue.index=\(index)")
            fields.append(issue.kind.rawValue)
            fields.append(issue.scenario?.rawValue ?? "<none>")
            fields.append(issue.detail)
        }

        fields.append("steps.count=\(plan.steps.count)")
        for (index, step) in plan.steps.enumerated() {
            fields.append("step.index=\(index)")
            fields.append(String(step.ordinal))
            fields.append(step.kind.rawValue)
            fields.append(step.scenario?.rawValue ?? "<none>")
            fields.append(String(step.minimumRepetitions))
            fields.append(String(step.minimumDurationSeconds.bitPattern))
            appendStringArray(step.targetedParityRows, label: "stepTargetedRows", to: &fields)
            appendStringArray(step.requiredArtifactRoles, label: "requiredArtifactRoles", to: &fields)
        }

        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }

    private static func appendStringArray(
        _ values: [String],
        label: String,
        to fields: inout [String]
    ) {
        fields.append("\(label).count=\(values.count)")
        for (index, value) in values.enumerated() {
            fields.append("\(label).index=\(index)")
            fields.append(value)
        }
    }

    private static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.unicodeScalars.allSatisfy {
            ($0.value >= 48 && $0.value <= 57) || ($0.value >= 97 && $0.value <= 102)
        }
    }
}

public enum Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError: Error, Equatable, Sendable {
    case malformedCommitment
    case schemaShapeMismatch
    case unsupportedSchemaVersion
    case unexpectedEvidenceScope
    case parityPromotionRequested
    case invalidCommitmentIntegrity
    case expectedPlanMismatch
}

public struct Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let expectedPlanBindingSHA256: String
    public let commitmentBindingSHA256: String
    public let acceptedForExpectedPlanUse: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    fileprivate static let receiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_EXPECTED_PLAN_COMMITMENT_HOST_RECEIPT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.receiptScope,
              acceptedForExpectedPlanUse,
              !parityPromotionAllowed else {
            return false
        }
        return receiptBindingSHA256 == Self.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            expectedPlanBindingSHA256: expectedPlanBindingSHA256,
            commitmentBindingSHA256: commitmentBindingSHA256,
            acceptedForExpectedPlanUse: acceptedForExpectedPlanUse,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func make(
        commitment: Lane3PhysicalEvidenceHandoffExpectedPlanCommitment
    ) -> Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt {
        let schemaVersion = 1
        let evidenceScope = receiptScope
        let accepted = true
        let parity = false
        let binding = computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: commitment.sessionIdentifier,
            appBuildCommitSHA: commitment.appBuildCommitSHA,
            expectedPlanBindingSHA256: commitment.expectedPlanBindingSHA256,
            commitmentBindingSHA256: commitment.commitmentBindingSHA256,
            acceptedForExpectedPlanUse: accepted,
            parityPromotionAllowed: parity
        )
        return Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: commitment.sessionIdentifier,
            appBuildCommitSHA: commitment.appBuildCommitSHA,
            expectedPlanBindingSHA256: commitment.expectedPlanBindingSHA256,
            commitmentBindingSHA256: commitment.commitmentBindingSHA256,
            acceptedForExpectedPlanUse: accepted,
            parityPromotionAllowed: parity,
            receiptBindingSHA256: binding
        )
    }

    fileprivate static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        expectedPlanBindingSHA256: String,
        commitmentBindingSHA256: String,
        acceptedForExpectedPlanUse: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_EXPECTED_PLAN_COMMITMENT_HOST_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            expectedPlanBindingSHA256,
            commitmentBindingSHA256,
            acceptedForExpectedPlanUse ? "1" : "0",
            parityPromotionAllowed ? "1" : "0"
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator {
    private static let expectedKeys: Set<String> = [
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
        "expectedPlanBindingSHA256",
        "parityPromotionAllowed",
        "commitmentBindingSHA256"
    ]

    public static func validate(
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan
    ) throws -> Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt {
        try validateSchemaShape(commitmentJSON)

        let commitment: Lane3PhysicalEvidenceHandoffExpectedPlanCommitment
        do {
            commitment = try JSONDecoder().decode(
                Lane3PhysicalEvidenceHandoffExpectedPlanCommitment.self,
                from: commitmentJSON
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.malformedCommitment
        }

        guard commitment.schemaVersion == 1 else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.unsupportedSchemaVersion
        }
        guard commitment.evidenceScope == Lane3PhysicalEvidenceHandoffExpectedPlanCommitment.commitmentScope else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.unexpectedEvidenceScope
        }
        guard !commitment.parityPromotionAllowed else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.parityPromotionRequested
        }
        guard commitment.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.invalidCommitmentIntegrity
        }
        guard Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.verify(
            commitment,
            expectedPlan: expectedPlan
        ) else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.expectedPlanMismatch
        }

        return Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt.make(commitment: commitment)
    }

    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan
    ) -> Bool {
        do {
            let rebound = try validate(commitmentJSON: commitmentJSON, expectedPlan: expectedPlan)
            return rebound == receipt && rebound.verifyIntegrity()
        } catch {
            return false
        }
    }

    private static func validateSchemaShape(_ data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.malformedCommitment
        }
        guard let dictionary = object as? [String: Any],
              Set(dictionary.keys) == expectedKeys else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError.schemaShapeMismatch
        }
    }
}

/// End-to-end HQ admission that first proves the persisted pre-capture expected-plan commitment,
/// then applies the existing exact-plan handoff validator to the completed physical-evidence tuple.
public enum Lane3PhysicalEvidenceHandoffCommittedPlanHostValidationError: Error, Equatable, Sendable {
    case planBindingMismatch
}

public struct Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let expectedPlanCommitmentReceiptBindingSHA256: String
    public let handoffReceiptBindingSHA256: String
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    private static let receiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_COMMITTED_PLAN_HANDOFF_RECEIPT_V1_NON_PARITY"

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
            expectedPlanCommitmentReceiptBindingSHA256: expectedPlanCommitmentReceiptBindingSHA256,
            handoffReceiptBindingSHA256: handoffReceiptBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func make(
        commitmentReceipt: Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostReceipt,
        handoffReceipt: Lane3PhysicalEvidenceHandoffHostReceipt
    ) -> Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt {
        let schemaVersion = 1
        let evidenceScope = receiptScope
        let accepted = true
        let parity = false
        let binding = computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: handoffReceipt.sessionIdentifier,
            appBuildCommitSHA: handoffReceipt.appBuildCommitSHA,
            expectedPlanCommitmentReceiptBindingSHA256: commitmentReceipt.receiptBindingSHA256,
            handoffReceiptBindingSHA256: handoffReceipt.receiptBindingSHA256,
            acceptedForHQReview: accepted,
            parityPromotionAllowed: parity
        )
        return Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: handoffReceipt.sessionIdentifier,
            appBuildCommitSHA: handoffReceipt.appBuildCommitSHA,
            expectedPlanCommitmentReceiptBindingSHA256: commitmentReceipt.receiptBindingSHA256,
            handoffReceiptBindingSHA256: handoffReceipt.receiptBindingSHA256,
            acceptedForHQReview: accepted,
            parityPromotionAllowed: parity,
            receiptBindingSHA256: binding
        )
    }

    private static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        expectedPlanCommitmentReceiptBindingSHA256: String,
        handoffReceiptBindingSHA256: String,
        acceptedForHQReview: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_COMMITTED_PLAN_HANDOFF_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            expectedPlanCommitmentReceiptBindingSHA256,
            handoffReceiptBindingSHA256,
            acceptedForHQReview ? "1" : "0",
            parityPromotionAllowed ? "1" : "0"
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffCommittedPlanHostValidator {
    public static func validate(
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt {
        let commitmentReceipt = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
            commitmentJSON: commitmentJSON,
            expectedPlan: expectedPlan
        )
        let handoffReceipt = try Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator.validate(
            expectedPlan: expectedPlan,
            manifestJSON: manifestJSON,
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )

        guard commitmentReceipt.sessionIdentifier == handoffReceipt.sessionIdentifier,
              commitmentReceipt.appBuildCommitSHA == handoffReceipt.appBuildCommitSHA else {
            throw Lane3PhysicalEvidenceHandoffCommittedPlanHostValidationError.planBindingMismatch
        }

        return Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt.make(
            commitmentReceipt: commitmentReceipt,
            handoffReceipt: handoffReceipt
        )
    }
}
