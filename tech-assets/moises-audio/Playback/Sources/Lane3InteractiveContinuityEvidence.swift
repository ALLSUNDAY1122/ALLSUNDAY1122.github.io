import Foundation

public enum Lane3InteractiveContinuityOperationKind: String, Codable, Sendable, CaseIterable {
    case seek
    case loop
}

public enum Lane3InteractiveContinuityOutcomeKind: String, Codable, Sendable {
    case executed
    case supersededBeforeToken
    case cancelledBeforeDispatch
    case rejectedBeforeToken
    case failedAfterDispatch
    case staleGenerationRejected
}

public enum Lane3InteractiveContinuityTarget: Equatable, Codable, Sendable {
    case seek(positionSeconds: Double)
    case loop(startSeconds: Double, endSeconds: Double)

    fileprivate var isFiniteAndValid: Bool {
        switch self {
        case .seek(let positionSeconds):
            return positionSeconds.isFinite && positionSeconds >= 0
        case .loop(let startSeconds, let endSeconds):
            return startSeconds.isFinite && endSeconds.isFinite && startSeconds >= 0 && endSeconds > startSeconds
        }
    }

    fileprivate func maximumAbsoluteError(comparedWith other: Self) -> Double? {
        switch (self, other) {
        case let (.seek(expected), .seek(actual)):
            return abs(expected - actual)
        case let (.loop(expectedStart, expectedEnd), .loop(actualStart, actualEnd)):
            return max(abs(expectedStart - actualStart), abs(expectedEnd - actualEnd))
        default:
            return nil
        }
    }
}

public struct Lane3InteractiveContinuityDeviceContext: Equatable, Codable, Sendable {
    public let physicalIPhone: Bool
    public let hardwareIdentifier: String
    public let osVersion: String
    public let appBuildIdentifier: String
    public let sampleRate: Double
    public let rightsClearedRealAudio: Bool
    public let currentMoisesDifferentialObserved: Bool
    public let humanListeningObserved: Bool

    public init(
        physicalIPhone: Bool,
        hardwareIdentifier: String,
        osVersion: String,
        appBuildIdentifier: String,
        sampleRate: Double,
        rightsClearedRealAudio: Bool,
        currentMoisesDifferentialObserved: Bool,
        humanListeningObserved: Bool
    ) {
        self.physicalIPhone = physicalIPhone
        self.hardwareIdentifier = hardwareIdentifier
        self.osVersion = osVersion
        self.appBuildIdentifier = appBuildIdentifier
        self.sampleRate = sampleRate
        self.rightsClearedRealAudio = rightsClearedRealAudio
        self.currentMoisesDifferentialObserved = currentMoisesDifferentialObserved
        self.humanListeningObserved = humanListeningObserved
    }
}

public struct Lane3InteractiveContinuityObservation: Equatable, Codable, Sendable {
    public let sampleID: UInt64
    public let operation: Lane3InteractiveContinuityOperationKind
    public let outcome: Lane3InteractiveContinuityOutcomeKind
    public let slotGenerationAtIntent: UInt64
    public let slotGenerationAtCompletion: UInt64
    public let transportTicket: UInt64?
    public let playbackGeneration: UInt64?
    public let firstIntentUptimeNanoseconds: UInt64
    public let tokenIssuedUptimeNanoseconds: UInt64?
    public let audibleResultUptimeNanoseconds: UInt64?
    public let requestedTarget: Lane3InteractiveContinuityTarget?
    public let appliedTarget: Lane3InteractiveContinuityTarget?
    public let callerCancellationObservedAfterDispatch: Bool

    public init(
        sampleID: UInt64,
        operation: Lane3InteractiveContinuityOperationKind,
        outcome: Lane3InteractiveContinuityOutcomeKind,
        slotGenerationAtIntent: UInt64,
        slotGenerationAtCompletion: UInt64,
        transportTicket: UInt64?,
        playbackGeneration: UInt64?,
        firstIntentUptimeNanoseconds: UInt64,
        tokenIssuedUptimeNanoseconds: UInt64?,
        audibleResultUptimeNanoseconds: UInt64?,
        requestedTarget: Lane3InteractiveContinuityTarget?,
        appliedTarget: Lane3InteractiveContinuityTarget?,
        callerCancellationObservedAfterDispatch: Bool
    ) {
        self.sampleID = sampleID
        self.operation = operation
        self.outcome = outcome
        self.slotGenerationAtIntent = slotGenerationAtIntent
        self.slotGenerationAtCompletion = slotGenerationAtCompletion
        self.transportTicket = transportTicket
        self.playbackGeneration = playbackGeneration
        self.firstIntentUptimeNanoseconds = firstIntentUptimeNanoseconds
        self.tokenIssuedUptimeNanoseconds = tokenIssuedUptimeNanoseconds
        self.audibleResultUptimeNanoseconds = audibleResultUptimeNanoseconds
        self.requestedTarget = requestedTarget
        self.appliedTarget = appliedTarget
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
    }
}

public struct Lane3InteractiveContinuityPercentiles: Equatable, Codable, Sendable {
    public let count: Int
    public let p50Nanoseconds: UInt64?
    public let p95Nanoseconds: UInt64?
    public let p99Nanoseconds: UInt64?
    public let maximumNanoseconds: UInt64?

    public init(valuesNanoseconds: [UInt64]) {
        let sorted = valuesNanoseconds.sorted()
        self.count = sorted.count
        self.p50Nanoseconds = Self.nearestRank(0.50, sorted: sorted)
        self.p95Nanoseconds = Self.nearestRank(0.95, sorted: sorted)
        self.p99Nanoseconds = Self.nearestRank(0.99, sorted: sorted)
        self.maximumNanoseconds = sorted.last
    }

    private static func nearestRank(_ percentile: Double, sorted: [UInt64]) -> UInt64? {
        guard !sorted.isEmpty else { return nil }
        let rank = max(1, Int(ceil(percentile * Double(sorted.count))))
        return sorted[min(sorted.count - 1, rank - 1)]
    }
}

public enum Lane3InteractiveContinuityViolationKind: String, Codable, Sendable, CaseIterable {
    case invalidDeviceContext
    case duplicateSampleID
    case invalidTarget
    case tokenBeforeIntent
    case audibleBeforeIntent
    case audibleBeforeToken
    case executedAcrossSlotGeneration
    case staleGenerationRejectionWithoutGenerationChange
    case executedWithoutTransportTicket
    case executedWithoutPlaybackGeneration
    case executedWithoutAppliedTarget
    case targetShapeMismatch
    case targetErrorExceededTolerance
}

public struct Lane3InteractiveContinuityValidationIssue: Equatable, Codable, Sendable {
    public let sampleID: UInt64?
    public let kind: Lane3InteractiveContinuityViolationKind
    public let detail: String

    public init(sampleID: UInt64?, kind: Lane3InteractiveContinuityViolationKind, detail: String) {
        self.sampleID = sampleID
        self.kind = kind
        self.detail = detail
    }
}

public struct Lane3InteractiveContinuityEvidenceReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let retainedObservationCount: Int
    public let capacityDrops: UInt64
    public let executedObservationCount: Int
    public let staleGenerationRejectionCount: Int
    public let missingTokenTimestampCount: Int
    public let missingAudibleTimestampCount: Int
    public let missingAppliedTargetCount: Int
    public let firstIntentToToken: Lane3InteractiveContinuityPercentiles
    public let firstIntentToAudibleResult: Lane3InteractiveContinuityPercentiles
    public let maximumTargetErrorSeconds: Double?
    public let issues: [Lane3InteractiveContinuityValidationIssue]
    public let physicalDeviceMeasurementComplete: Bool
    public let differentialListeningBundleComplete: Bool
    public let parityPromotionAllowed: Bool

    public init(
        retainedObservationCount: Int,
        capacityDrops: UInt64,
        executedObservationCount: Int,
        staleGenerationRejectionCount: Int,
        missingTokenTimestampCount: Int,
        missingAudibleTimestampCount: Int,
        missingAppliedTargetCount: Int,
        firstIntentToToken: Lane3InteractiveContinuityPercentiles,
        firstIntentToAudibleResult: Lane3InteractiveContinuityPercentiles,
        maximumTargetErrorSeconds: Double?,
        issues: [Lane3InteractiveContinuityValidationIssue],
        physicalDeviceMeasurementComplete: Bool,
        differentialListeningBundleComplete: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW35_INTERACTIVE_CONTINUITY_EVIDENCE_NON_PARITY"
        self.retainedObservationCount = retainedObservationCount
        self.capacityDrops = capacityDrops
        self.executedObservationCount = executedObservationCount
        self.staleGenerationRejectionCount = staleGenerationRejectionCount
        self.missingTokenTimestampCount = missingTokenTimestampCount
        self.missingAudibleTimestampCount = missingAudibleTimestampCount
        self.missingAppliedTargetCount = missingAppliedTargetCount
        self.firstIntentToToken = firstIntentToToken
        self.firstIntentToAudibleResult = firstIntentToAudibleResult
        self.maximumTargetErrorSeconds = maximumTargetErrorSeconds
        self.issues = issues
        self.physicalDeviceMeasurementComplete = physicalDeviceMeasurementComplete
        self.differentialListeningBundleComplete = differentialListeningBundleComplete
        self.parityPromotionAllowed = false
    }
}

/// Bounded recorder for physical-device seek/loop continuity evidence. The ring intentionally drops
/// the oldest observation when full rather than allowing a long drag/device run to grow memory
/// without bound. `capacityDrops` is durable evidence that the run exceeded the retained window.
public struct Lane3InteractiveContinuityEvidenceBuffer: Sendable {
    public let capacity: Int
    public private(set) var capacityDrops: UInt64 = 0

    private var storage: [Lane3InteractiveContinuityObservation?]
    private var count: Int = 0
    private var nextOverwriteIndex: Int = 0

    public init(capacity: Int = 4_096) {
        let normalizedCapacity = min(max(capacity, 16), 65_536)
        self.capacity = normalizedCapacity
        self.storage = Array(repeating: nil, count: normalizedCapacity)
    }

    public var retainedCount: Int { count }

    public mutating func append(_ observation: Lane3InteractiveContinuityObservation) {
        if count < capacity {
            storage[count] = observation
            count += 1
            if count == capacity { nextOverwriteIndex = 0 }
            return
        }

        storage[nextOverwriteIndex] = observation
        nextOverwriteIndex += 1
        if nextOverwriteIndex == capacity { nextOverwriteIndex = 0 }
        let next = capacityDrops.addingReportingOverflow(1)
        capacityDrops = next.overflow ? UInt64.max : next.partialValue
    }

    public func orderedObservations() -> [Lane3InteractiveContinuityObservation] {
        guard count > 0 else { return [] }
        if count < capacity {
            return storage[0..<count].compactMap { $0 }
        }
        var result: [Lane3InteractiveContinuityObservation] = []
        result.reserveCapacity(capacity)
        for index in nextOverwriteIndex..<capacity {
            if let observation = storage[index] { result.append(observation) }
        }
        if nextOverwriteIndex > 0 {
            for index in 0..<nextOverwriteIndex {
                if let observation = storage[index] { result.append(observation) }
            }
        }
        return result
    }
}

public enum Lane3InteractiveContinuityEvidenceAnalyzer {
    public static func analyze(
        context: Lane3InteractiveContinuityDeviceContext,
        buffer: Lane3InteractiveContinuityEvidenceBuffer,
        targetToleranceSeconds: Double = 0.050
    ) -> Lane3InteractiveContinuityEvidenceReport {
        let observations = buffer.orderedObservations()
        var issues: [Lane3InteractiveContinuityValidationIssue] = []
        var seenSampleIDs: Set<UInt64> = []
        seenSampleIDs.reserveCapacity(observations.count)

        if !context.sampleRate.isFinite || context.sampleRate <= 0 ||
            context.hardwareIdentifier.isEmpty || context.osVersion.isEmpty || context.appBuildIdentifier.isEmpty {
            issues.append(.init(sampleID: nil, kind: .invalidDeviceContext, detail: "device metadata/sample rate incomplete"))
        }

        let tolerance = targetToleranceSeconds.isFinite && targetToleranceSeconds >= 0
            ? targetToleranceSeconds
            : 0.050
        var tokenLatencies: [UInt64] = []
        var audibleLatencies: [UInt64] = []
        tokenLatencies.reserveCapacity(observations.count)
        audibleLatencies.reserveCapacity(observations.count)

        var executedCount = 0
        var staleGenerationRejectionCount = 0
        var missingTokenCount = 0
        var missingAudibleCount = 0
        var missingAppliedTargetCount = 0
        var maximumTargetError: Double?

        for observation in observations {
            if !seenSampleIDs.insert(observation.sampleID).inserted {
                issues.append(.init(sampleID: observation.sampleID, kind: .duplicateSampleID, detail: "sampleID reused"))
            }
            if let requestedTarget = observation.requestedTarget, !requestedTarget.isFiniteAndValid {
                issues.append(.init(sampleID: observation.sampleID, kind: .invalidTarget, detail: "requested target invalid"))
            }
            if let appliedTarget = observation.appliedTarget, !appliedTarget.isFiniteAndValid {
                issues.append(.init(sampleID: observation.sampleID, kind: .invalidTarget, detail: "applied target invalid"))
            }

            if let token = observation.tokenIssuedUptimeNanoseconds {
                if token < observation.firstIntentUptimeNanoseconds {
                    issues.append(.init(sampleID: observation.sampleID, kind: .tokenBeforeIntent, detail: "token timestamp precedes intent"))
                } else {
                    tokenLatencies.append(token - observation.firstIntentUptimeNanoseconds)
                }
            }
            if let audible = observation.audibleResultUptimeNanoseconds {
                if audible < observation.firstIntentUptimeNanoseconds {
                    issues.append(.init(sampleID: observation.sampleID, kind: .audibleBeforeIntent, detail: "audible timestamp precedes intent"))
                } else {
                    audibleLatencies.append(audible - observation.firstIntentUptimeNanoseconds)
                }
                if let token = observation.tokenIssuedUptimeNanoseconds, audible < token {
                    issues.append(.init(sampleID: observation.sampleID, kind: .audibleBeforeToken, detail: "audible result precedes token issuance"))
                }
            }

            switch observation.outcome {
            case .executed:
                executedCount += 1
                if observation.slotGenerationAtCompletion != observation.slotGenerationAtIntent {
                    issues.append(.init(sampleID: observation.sampleID, kind: .executedAcrossSlotGeneration, detail: "executed work crossed reconstruction slot generation"))
                }
                if observation.transportTicket == nil {
                    issues.append(.init(sampleID: observation.sampleID, kind: .executedWithoutTransportTicket, detail: "executed sample lacks transport ticket"))
                }
                if observation.playbackGeneration == nil {
                    issues.append(.init(sampleID: observation.sampleID, kind: .executedWithoutPlaybackGeneration, detail: "executed sample lacks playback generation"))
                }
                if observation.tokenIssuedUptimeNanoseconds == nil { missingTokenCount += 1 }
                if observation.audibleResultUptimeNanoseconds == nil { missingAudibleCount += 1 }
                if observation.appliedTarget == nil {
                    missingAppliedTargetCount += 1
                    issues.append(.init(sampleID: observation.sampleID, kind: .executedWithoutAppliedTarget, detail: "executed sample lacks applied seek/loop target"))
                }
                if let requested = observation.requestedTarget, let applied = observation.appliedTarget {
                    if let error = requested.maximumAbsoluteError(comparedWith: applied) {
                        maximumTargetError = max(maximumTargetError ?? 0, error)
                        if error > tolerance {
                            issues.append(.init(sampleID: observation.sampleID, kind: .targetErrorExceededTolerance, detail: "target error \(error)s exceeds \(tolerance)s"))
                        }
                    } else {
                        issues.append(.init(sampleID: observation.sampleID, kind: .targetShapeMismatch, detail: "requested/applied target kinds differ"))
                    }
                }
            case .staleGenerationRejected:
                staleGenerationRejectionCount += 1
                if observation.slotGenerationAtCompletion == observation.slotGenerationAtIntent {
                    issues.append(.init(sampleID: observation.sampleID, kind: .staleGenerationRejectionWithoutGenerationChange, detail: "stale rejection recorded without reconstruction generation change"))
                }
            case .supersededBeforeToken, .cancelledBeforeDispatch, .rejectedBeforeToken, .failedAfterDispatch:
                break
            }
        }

        let noIssues = issues.isEmpty
        let completeTimings = executedCount > 0 && missingTokenCount == 0 && missingAudibleCount == 0
        let completeTargets = executedCount > 0 && missingAppliedTargetCount == 0
        let physicalComplete = context.physicalIPhone &&
            context.rightsClearedRealAudio &&
            context.sampleRate.isFinite && context.sampleRate > 0 &&
            !context.hardwareIdentifier.isEmpty && !context.osVersion.isEmpty && !context.appBuildIdentifier.isEmpty &&
            completeTimings && completeTargets && noIssues
        let differentialComplete = physicalComplete &&
            context.currentMoisesDifferentialObserved &&
            context.humanListeningObserved

        return Lane3InteractiveContinuityEvidenceReport(
            retainedObservationCount: observations.count,
            capacityDrops: buffer.capacityDrops,
            executedObservationCount: executedCount,
            staleGenerationRejectionCount: staleGenerationRejectionCount,
            missingTokenTimestampCount: missingTokenCount,
            missingAudibleTimestampCount: missingAudibleCount,
            missingAppliedTargetCount: missingAppliedTargetCount,
            firstIntentToToken: Lane3InteractiveContinuityPercentiles(valuesNanoseconds: tokenLatencies),
            firstIntentToAudibleResult: Lane3InteractiveContinuityPercentiles(valuesNanoseconds: audibleLatencies),
            maximumTargetErrorSeconds: maximumTargetError,
            issues: issues,
            physicalDeviceMeasurementComplete: physicalComplete,
            differentialListeningBundleComplete: differentialComplete
        )
    }
}
