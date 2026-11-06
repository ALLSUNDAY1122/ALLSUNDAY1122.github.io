import Foundation

public enum Lane3InteractiveContinuityInstrumentationValidationIssueKind: String, Codable, Sendable {
    case executedAcrossSlotGeneration
    case tokenBeforeIntent
    case backendCompletionBeforeToken
    case missingExternalAudibleMarker
    case audibleBeforeToken
    case invalidRequestedTarget
    case invalidAppliedTarget
    case targetMismatch
}

public struct Lane3InteractiveContinuityInstrumentationValidationIssue: Equatable, Codable, Sendable {
    public let kind: Lane3InteractiveContinuityInstrumentationValidationIssueKind
    public let detail: String

    public init(
        kind: Lane3InteractiveContinuityInstrumentationValidationIssueKind,
        detail: String
    ) {
        self.kind = kind
        self.detail = detail
    }
}

public struct Lane3InteractiveContinuityInstrumentationValidationReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let issues: [Lane3InteractiveContinuityInstrumentationValidationIssue]
    public let generationStable: Bool
    public let timingOrderValid: Bool
    public let targetMatched: Bool
    public let externalAudibleMarkerValid: Bool
    public let physicalMeasurementFieldsComplete: Bool
    public let parityPromotionAllowed: Bool

    public init(
        issues: [Lane3InteractiveContinuityInstrumentationValidationIssue],
        generationStable: Bool,
        timingOrderValid: Bool,
        targetMatched: Bool,
        externalAudibleMarkerValid: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW38_INSTRUMENTATION_VALIDATION_NON_PARITY"
        self.issues = issues
        self.generationStable = generationStable
        self.timingOrderValid = timingOrderValid
        self.targetMatched = targetMatched
        self.externalAudibleMarkerValid = externalAudibleMarkerValid
        self.physicalMeasurementFieldsComplete = issues.isEmpty
            && generationStable
            && timingOrderValid
            && targetMatched
            && externalAudibleMarkerValid
        self.parityPromotionAllowed = false
    }
}

public enum Lane3InteractiveContinuityInstrumentationValidator {
    public static func validate(
        _ observation: Lane3InteractiveContinuityInstrumentedObservation
    ) -> Lane3InteractiveContinuityInstrumentationValidationReport {
        var issues: [Lane3InteractiveContinuityInstrumentationValidationIssue] = []

        let generationStable = observation.slotGenerationAtIntent == observation.slotGenerationAtCompletion
        if !generationStable {
            issues.append(.init(
                kind: .executedAcrossSlotGeneration,
                detail: "executed observation crossed selected reconstruction slot generation"
            ))
        }

        var timingOrderValid = true
        if observation.tokenIssuedUptimeNanoseconds < observation.firstIntentUptimeNanoseconds {
            timingOrderValid = false
            issues.append(.init(kind: .tokenBeforeIntent, detail: "token timestamp precedes first intent"))
        }
        if observation.backendCompletedUptimeNanoseconds < observation.tokenIssuedUptimeNanoseconds {
            timingOrderValid = false
            issues.append(.init(kind: .backendCompletionBeforeToken, detail: "backend completion precedes token issuance"))
        }

        let audibleMarkerValid: Bool
        if let audible = observation.audibleResultUptimeNanoseconds,
           let source = observation.audibleTimestampSource,
           !source.isEmpty {
            if audible < observation.tokenIssuedUptimeNanoseconds {
                timingOrderValid = false
                audibleMarkerValid = false
                issues.append(.init(kind: .audibleBeforeToken, detail: "physical audible marker precedes token issuance"))
            } else {
                audibleMarkerValid = true
            }
        } else {
            audibleMarkerValid = false
            issues.append(.init(
                kind: .missingExternalAudibleMarker,
                detail: "physical audible result timestamp and source are both required"
            ))
        }

        if !observation.requestedTarget.isFiniteAndValid {
            issues.append(.init(kind: .invalidRequestedTarget, detail: "requested target is invalid"))
        }
        if !observation.appliedTarget.isFiniteAndValid {
            issues.append(.init(kind: .invalidAppliedTarget, detail: "backend-applied target is invalid"))
        }
        let targetMatched = observation.requestedTarget == observation.appliedTarget
        if !targetMatched {
            issues.append(.init(kind: .targetMismatch, detail: "requested and backend-applied targets differ"))
        }

        return Lane3InteractiveContinuityInstrumentationValidationReport(
            issues: issues,
            generationStable: generationStable,
            timingOrderValid: timingOrderValid,
            targetMatched: targetMatched,
            externalAudibleMarkerValid: audibleMarkerValid
        )
    }
}
