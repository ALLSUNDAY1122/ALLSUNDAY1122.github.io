import Foundation

public enum Lane3InteractiveContinuityMeasuredTarget: Equatable, Codable, Sendable {
    case seek(positionSeconds: Double)
    case loop(startSeconds: Double, endSeconds: Double)
    case loopDisabled

    public var isFiniteAndValid: Bool {
        switch self {
        case .seek(let positionSeconds):
            return positionSeconds.isFinite && positionSeconds >= 0
        case .loop(let startSeconds, let endSeconds):
            return startSeconds.isFinite && endSeconds.isFinite && startSeconds >= 0 && endSeconds > startSeconds
        case .loopDisabled:
            return true
        }
    }

    public init(appliedTarget: Lane3TransportAppliedTarget) {
        switch appliedTarget {
        case .seek(let positionSeconds):
            self = .seek(positionSeconds: positionSeconds)
        case .loop(let startSeconds, let endSeconds):
            self = .loop(startSeconds: startSeconds, endSeconds: endSeconds)
        case .loopDisabled:
            self = .loopDisabled
        }
    }

    fileprivate var legacyAW35Target: Lane3InteractiveContinuityTarget? {
        switch self {
        case .seek(let positionSeconds):
            return .seek(positionSeconds: positionSeconds)
        case .loop(let startSeconds, let endSeconds):
            return .loop(startSeconds: startSeconds, endSeconds: endSeconds)
        case .loopDisabled:
            // AW35 schema has no representation for setLoop(nil). Never encode disable as a fake
            // numeric loop range; AW38 keeps it in the versioned measured target instead.
            return nil
        }
    }
}

public enum Lane3InteractiveContinuityInstrumentationIssueKind: String, Codable, Sendable {
    case unsupportedTransportKind
    case missingTokenTiming
    case tokenReasonMismatch
    case tokenBeforeIntent
    case missingBackendCompletion
    case backendCompletionBeforeToken
    case missingAppliedTarget
    case appliedTargetInvalid
    case requestedTargetInvalid
    case targetShapeMismatch
    case audibleBeforeToken
    case legacyAW35CannotRepresentLoopDisabled
}

public struct Lane3InteractiveContinuityInstrumentationIssue: Equatable, Codable, Sendable {
    public let kind: Lane3InteractiveContinuityInstrumentationIssueKind
    public let detail: String

    public init(kind: Lane3InteractiveContinuityInstrumentationIssueKind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

public struct Lane3InteractiveContinuityInstrumentedObservation: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sampleID: UInt64
    public let operation: Lane3InteractiveContinuityOperationKind
    public let slotGenerationAtIntent: UInt64
    public let slotGenerationAtCompletion: UInt64
    public let transportTicket: UInt64
    public let playbackGeneration: UInt64
    public let firstIntentUptimeNanoseconds: UInt64
    public let tokenIssuedUptimeNanoseconds: UInt64
    public let backendCompletedUptimeNanoseconds: UInt64
    public let audibleResultUptimeNanoseconds: UInt64?
    public let requestedTarget: Lane3InteractiveContinuityMeasuredTarget
    public let appliedTarget: Lane3InteractiveContinuityMeasuredTarget
    public let callerCancellationObservedAfterDispatch: Bool
    public let audibleTimestampSource: String?
    public let parityPromotionAllowed: Bool

    public init(
        sampleID: UInt64,
        operation: Lane3InteractiveContinuityOperationKind,
        slotGenerationAtIntent: UInt64,
        slotGenerationAtCompletion: UInt64,
        transportTicket: UInt64,
        playbackGeneration: UInt64,
        firstIntentUptimeNanoseconds: UInt64,
        tokenIssuedUptimeNanoseconds: UInt64,
        backendCompletedUptimeNanoseconds: UInt64,
        audibleResultUptimeNanoseconds: UInt64?,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        appliedTarget: Lane3InteractiveContinuityMeasuredTarget,
        callerCancellationObservedAfterDispatch: Bool,
        audibleTimestampSource: String?
    ) {
        self.schemaVersion = 2
        self.evidenceScope = "LANE3_AW38_SELECTED_DEVICE_CONTINUITY_INSTRUMENTATION_NON_PARITY"
        self.sampleID = sampleID
        self.operation = operation
        self.slotGenerationAtIntent = slotGenerationAtIntent
        self.slotGenerationAtCompletion = slotGenerationAtCompletion
        self.transportTicket = transportTicket
        self.playbackGeneration = playbackGeneration
        self.firstIntentUptimeNanoseconds = firstIntentUptimeNanoseconds
        self.tokenIssuedUptimeNanoseconds = tokenIssuedUptimeNanoseconds
        self.backendCompletedUptimeNanoseconds = backendCompletedUptimeNanoseconds
        self.audibleResultUptimeNanoseconds = audibleResultUptimeNanoseconds
        self.requestedTarget = requestedTarget
        self.appliedTarget = appliedTarget
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
        self.audibleTimestampSource = audibleTimestampSource
        self.parityPromotionAllowed = false
    }

    public var hasExternalAudibleMarker: Bool {
        audibleResultUptimeNanoseconds != nil && !(audibleTimestampSource ?? "").isEmpty
    }

    /// Converts only shapes representable by the frozen AW35 schema. Loop-disable remains v2-only
    /// rather than being encoded as a fabricated enabled range.
    public func legacyAW35Observation() -> Lane3InteractiveContinuityObservation? {
        guard let requested = requestedTarget.legacyAW35Target,
              let applied = appliedTarget.legacyAW35Target else {
            return nil
        }
        return Lane3InteractiveContinuityObservation(
            sampleID: sampleID,
            operation: operation,
            outcome: .executed,
            slotGenerationAtIntent: slotGenerationAtIntent,
            slotGenerationAtCompletion: slotGenerationAtCompletion,
            transportTicket: transportTicket,
            playbackGeneration: playbackGeneration,
            firstIntentUptimeNanoseconds: firstIntentUptimeNanoseconds,
            tokenIssuedUptimeNanoseconds: tokenIssuedUptimeNanoseconds,
            audibleResultUptimeNanoseconds: audibleResultUptimeNanoseconds,
            requestedTarget: requested,
            appliedTarget: applied,
            callerCancellationObservedAfterDispatch: callerCancellationObservedAfterDispatch
        )
    }
}

public struct Lane3InteractiveContinuityInstrumentationResult: Equatable, Codable, Sendable {
    public let observation: Lane3InteractiveContinuityInstrumentedObservation?
    public let issues: [Lane3InteractiveContinuityInstrumentationIssue]
    public let exactTokenCorrelated: Bool
    public let backendAppliedTargetCorrelated: Bool
    public let externalAudibleMarkerPresent: Bool
    public let legacyAW35ObservationAvailable: Bool
    public let parityPromotionAllowed: Bool

    public init(
        observation: Lane3InteractiveContinuityInstrumentedObservation?,
        issues: [Lane3InteractiveContinuityInstrumentationIssue]
    ) {
        self.observation = observation
        self.issues = issues
        self.exactTokenCorrelated = observation != nil && !issues.contains { issue in
            issue.kind == .missingTokenTiming || issue.kind == .tokenReasonMismatch || issue.kind == .tokenBeforeIntent
        }
        self.backendAppliedTargetCorrelated = observation != nil && !issues.contains { issue in
            issue.kind == .missingBackendCompletion || issue.kind == .missingAppliedTarget || issue.kind == .appliedTargetInvalid || issue.kind == .targetShapeMismatch
        }
        self.externalAudibleMarkerPresent = observation?.hasExternalAudibleMarker ?? false
        self.legacyAW35ObservationAvailable = observation?.legacyAW35Observation() != nil
        self.parityPromotionAllowed = false
    }
}

/// Correlates one executed unified-transport receipt with the exact AW38 generation timing ledger.
/// `audibleResultUptimeNanoseconds` is deliberately caller supplied: backend completion, player
/// scheduling, or AW32 fade-in issuance are not physical audible output and must never be substituted.
public actor Lane3SelectedInteractiveContinuityInstrumentationAdapter {
    private let projectID: ProjectID
    private let playback: RescheduleFencedPlaybackBackend

    public init(projectID: ProjectID, playback: RescheduleFencedPlaybackBackend) {
        self.projectID = projectID
        self.playback = playback
    }

    public func correlateExecuted(
        sampleID: UInt64,
        receipt: Lane3UnifiedTransportExecutionReceipt,
        slotGenerationAtIntent: UInt64,
        slotGenerationAtCompletion: UInt64,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3InteractiveContinuityInstrumentationResult {
        var issues: [Lane3InteractiveContinuityInstrumentationIssue] = []

        let operation: Lane3InteractiveContinuityOperationKind
        let expectedReason: PlaybackTransportDiscontinuityReason
        switch receipt.kind {
        case .seek:
            operation = .seek
            expectedReason = .seek
        case .loop:
            operation = .loop
            expectedReason = .loopChange
        default:
            return Lane3InteractiveContinuityInstrumentationResult(
                observation: nil,
                issues: [.init(kind: .unsupportedTransportKind, detail: "receipt kind \(receipt.kind.rawValue) is not seek/loop")]
            )
        }

        guard requestedTarget.isFiniteAndValid else {
            return Lane3InteractiveContinuityInstrumentationResult(
                observation: nil,
                issues: [.init(kind: .requestedTargetInvalid, detail: "requested target is non-finite or invalid")]
            )
        }

        guard let timing = await playback.rescheduleTokenTiming(
            projectID: projectID,
            generation: receipt.playbackGeneration
        ) else {
            return Lane3InteractiveContinuityInstrumentationResult(
                observation: nil,
                issues: [.init(kind: .missingTokenTiming, detail: "generation \(receipt.playbackGeneration) is not retained in the bounded timing ledger")]
            )
        }

        if timing.reason != expectedReason {
            issues.append(.init(
                kind: .tokenReasonMismatch,
                detail: "expected \(expectedReason.rawValue), got \(timing.reason.rawValue)"
            ))
        }
        if timing.issuedUptimeNanoseconds < firstIntentUptimeNanoseconds {
            issues.append(.init(kind: .tokenBeforeIntent, detail: "token timestamp precedes first intent"))
        }
        guard let backendCompleted = timing.backendCompletedUptimeNanoseconds else {
            issues.append(.init(kind: .missingBackendCompletion, detail: "backend completion was not retained for executed receipt"))
            return Lane3InteractiveContinuityInstrumentationResult(observation: nil, issues: issues)
        }
        if backendCompleted < timing.issuedUptimeNanoseconds {
            issues.append(.init(kind: .backendCompletionBeforeToken, detail: "backend completion precedes token issuance"))
        }
        guard let rawApplied = timing.appliedTarget else {
            issues.append(.init(kind: .missingAppliedTarget, detail: "executed seek/loop lacks backend-applied target"))
            return Lane3InteractiveContinuityInstrumentationResult(observation: nil, issues: issues)
        }
        let applied = Lane3InteractiveContinuityMeasuredTarget(appliedTarget: rawApplied)
        if !applied.isFiniteAndValid {
            issues.append(.init(kind: .appliedTargetInvalid, detail: "backend-applied target is invalid"))
        }

        switch (requestedTarget, applied) {
        case (.seek, .seek), (.loop, .loop), (.loopDisabled, .loopDisabled):
            break
        default:
            issues.append(.init(kind: .targetShapeMismatch, detail: "requested/applied target shapes differ"))
        }

        if let audibleResultUptimeNanoseconds,
           audibleResultUptimeNanoseconds < timing.issuedUptimeNanoseconds {
            issues.append(.init(kind: .audibleBeforeToken, detail: "physical audible marker precedes token issuance"))
        }

        if case .loopDisabled = requestedTarget {
            issues.append(.init(
                kind: .legacyAW35CannotRepresentLoopDisabled,
                detail: "AW35 target schema cannot encode setLoop(nil); AW38 v2 observation remains authoritative for this operation"
            ))
        }

        let observation = Lane3InteractiveContinuityInstrumentedObservation(
            sampleID: sampleID,
            operation: operation,
            slotGenerationAtIntent: slotGenerationAtIntent,
            slotGenerationAtCompletion: slotGenerationAtCompletion,
            transportTicket: receipt.ticket,
            playbackGeneration: receipt.playbackGeneration,
            firstIntentUptimeNanoseconds: firstIntentUptimeNanoseconds,
            tokenIssuedUptimeNanoseconds: timing.issuedUptimeNanoseconds,
            backendCompletedUptimeNanoseconds: backendCompleted,
            audibleResultUptimeNanoseconds: audibleResultUptimeNanoseconds,
            requestedTarget: requestedTarget,
            appliedTarget: applied,
            callerCancellationObservedAfterDispatch: receipt.callerCancellationObservedAfterDispatch,
            audibleTimestampSource: audibleTimestampSource
        )
        return Lane3InteractiveContinuityInstrumentationResult(observation: observation, issues: issues)
    }
}
