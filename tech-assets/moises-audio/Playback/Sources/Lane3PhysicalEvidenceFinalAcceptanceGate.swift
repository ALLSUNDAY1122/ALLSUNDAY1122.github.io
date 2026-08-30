import Foundation

public enum Lane3PhysicalEvidenceFinalAcceptanceIssueKind: String, Codable, Sendable {
    case strictCompletionNotReady
    case malformedManifest
    case schemaShapeMismatch
    case unsupportedSchemaVersion
    case unexpectedEvidenceScope
    case parityPromotionRequested
    case evidenceMismatch
}

public struct Lane3PhysicalEvidenceFinalAcceptanceIssue: Equatable, Codable, Sendable {
    public let kind: Lane3PhysicalEvidenceFinalAcceptanceIssueKind
    public let detail: String

    public init(kind: Lane3PhysicalEvidenceFinalAcceptanceIssueKind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

/// Final HQ-side acceptance boundary for Lane 3 physical evidence.
///
/// The AW51 strict completion report is necessary but no longer sufficient for final HQ review.
/// A caller must also present the serialized tamper-evident handoff manifest, which is decoded and
/// rebound by `Lane3PhysicalEvidenceHandoffHostValidator` to the exact plan, device bundle, and
/// resource traces. This keeps the legacy AW51 API compatible while making the cryptographic
/// handoff/host-receipt path explicit for final acceptance.
///
/// This gate is intentionally NON_PARITY. Passing it proves deterministic internal evidence binding,
/// not artifact authenticity, physical execution, current-Moises equivalence, or perceptual parity.
public struct Lane3PhysicalEvidenceFinalAcceptanceReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let strictCompletion: Lane3PhysicalEvidenceSessionCompletionGateReport
    public let handoffReceipt: Lane3PhysicalEvidenceHandoffHostReceipt?
    public let issues: [Lane3PhysicalEvidenceFinalAcceptanceIssue]
    public let readyForHQReview: Bool
    public let parityPromotionAllowed: Bool

    public init(
        strictCompletion: Lane3PhysicalEvidenceSessionCompletionGateReport,
        handoffReceipt: Lane3PhysicalEvidenceHandoffHostReceipt?,
        issues: [Lane3PhysicalEvidenceFinalAcceptanceIssue]
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_HQ_PHYSICAL_EVIDENCE_FINAL_ACCEPTANCE_V1_NON_PARITY"
        self.strictCompletion = strictCompletion
        self.handoffReceipt = handoffReceipt
        self.issues = issues
        self.readyForHQReview = strictCompletion.readyForHQReview
            && handoffReceipt?.acceptedForHQReview == true
            && handoffReceipt?.verifyIntegrity() == true
            && issues.isEmpty
        self.parityPromotionAllowed = false
    }
}

public enum Lane3PhysicalEvidenceFinalAcceptanceGate {
    public static func evaluate(
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Lane3PhysicalEvidenceFinalAcceptanceReport {
        let strictCompletion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )

        var issues: [Lane3PhysicalEvidenceFinalAcceptanceIssue] = []
        if !strictCompletion.readyForHQReview {
            issues.append(.init(
                kind: .strictCompletionNotReady,
                detail: "AW51 strict completion must be ready before final HQ acceptance"
            ))
        }

        let receipt: Lane3PhysicalEvidenceHandoffHostReceipt?
        do {
            receipt = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            )
        } catch let error as Lane3PhysicalEvidenceHandoffHostValidationError {
            receipt = nil
            issues.append(issue(for: error))
        } catch {
            receipt = nil
            issues.append(.init(
                kind: .evidenceMismatch,
                detail: "unexpected handoff validation failure"
            ))
        }

        return Lane3PhysicalEvidenceFinalAcceptanceReport(
            strictCompletion: strictCompletion,
            handoffReceipt: receipt,
            issues: issues
        )
    }

    private static func issue(
        for error: Lane3PhysicalEvidenceHandoffHostValidationError
    ) -> Lane3PhysicalEvidenceFinalAcceptanceIssue {
        switch error {
        case .malformedManifest:
            return .init(kind: .malformedManifest, detail: "serialized handoff manifest is malformed")
        case .schemaShapeMismatch:
            return .init(kind: .schemaShapeMismatch, detail: "handoff manifest schema shape does not match the frozen contract")
        case .unsupportedSchemaVersion:
            return .init(kind: .unsupportedSchemaVersion, detail: "handoff manifest schema version is unsupported")
        case .unexpectedEvidenceScope:
            return .init(kind: .unexpectedEvidenceScope, detail: "handoff manifest evidence scope is unexpected")
        case .parityPromotionRequested:
            return .init(kind: .parityPromotionRequested, detail: "handoff manifest attempted to request PARITY promotion")
        case .evidenceMismatch:
            return .init(kind: .evidenceMismatch, detail: "handoff manifest does not rebind to the supplied evidence set")
        }
    }
}
