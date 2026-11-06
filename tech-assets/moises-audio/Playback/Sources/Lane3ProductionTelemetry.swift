import Foundation
import Dispatch

public protocol Lane3TelemetryTimeSource: Sendable {
    func nowNanoseconds() -> UInt64
}

public struct Lane3SystemTelemetryTimeSource: Lane3TelemetryTimeSource {
    public init() {}
    public func nowNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
}

public struct Lane3TelemetryPolicy: Equatable, Sendable {
    public let seekQuietPeriodNanoseconds: UInt64
    public let loopQuietPeriodNanoseconds: UInt64
    public let tempoQuietPeriodNanoseconds: UInt64

    public init(
        seekQuietPeriodNanoseconds: UInt64 = 16_000_000,
        loopQuietPeriodNanoseconds: UInt64 = 16_000_000,
        tempoQuietPeriodNanoseconds: UInt64 = 16_000_000
    ) {
        self.seekQuietPeriodNanoseconds = seekQuietPeriodNanoseconds
        self.loopQuietPeriodNanoseconds = loopQuietPeriodNanoseconds
        self.tempoQuietPeriodNanoseconds = tempoQuietPeriodNanoseconds
    }

    public func quietPeriodNanoseconds(for kind: Lane3UnifiedTransportKind) -> UInt64 {
        switch kind {
        case .seek: return seekQuietPeriodNanoseconds
        case .loop: return loopQuietPeriodNanoseconds
        case .tempo: return tempoQuietPeriodNanoseconds
        default: return 0
        }
    }
}

public struct Lane3TelemetryPrivacySnapshot: Codable, Equatable, Sendable {
    public let aggregationOnly: Bool
    public let rawEventLogRetained: Bool
    public let absoluteWallClockCaptured: Bool
    public let projectIdentifierCaptured: Bool
    public let mediaNameOrPathCaptured: Bool
    public let pcmOrAudioContentCaptured: Bool
    public let ticketOrGenerationValueExported: Bool
}

public struct Lane3TelemetryLatencySnapshot: Codable, Equatable, Sendable {
    public let samples: UInt64
    public let p50UpperBoundMilliseconds: Double?
    public let p95UpperBoundMilliseconds: Double?
    public let p99UpperBoundMilliseconds: Double?
    public let maxObservedMilliseconds: Double
}

public struct Lane3TelemetryKindSnapshot: Codable, Equatable, Sendable {
    public let kind: String
    public let productSubmissions: UInt64
    public let internalTransportOperations: UInt64
    public let executed: UInt64
    public let supersededBeforeToken: UInt64
    public let cancelledBeforeDispatch: UInt64
    public let rejectedBeforeToken: UInt64
    public let failedAfterDispatch: UInt64
    public let controlPlaybackTokens: UInt64
    public let recoveryPlaybackTokens: UInt64
    public let coalescedPredecessors: UInt64
    public let callerCancellationObservedAfterDispatch: UInt64
    public let endToEndLatency: Lane3TelemetryLatencySnapshot
    public let submissionToBackendEntryLatency: Lane3TelemetryLatencySnapshot
    public let postConfiguredQuietResidualLatency: Lane3TelemetryLatencySnapshot
    public let backendExecutionLatency: Lane3TelemetryLatencySnapshot
}

public struct Lane3InterruptionTelemetrySnapshot: Codable, Equatable, Sendable {
    public let beginCalls: UInt64
    public let beginRejected: UInt64
    public let beginBoundaryUnsafe: UInt64
    public let endCalls: UInt64
    public let endRejected: UInt64
    public let endBoundaryUnsafe: UInt64
    public let osShouldResumeTrue: UInt64
    public let resumeArmedAtEnd: UInt64
    public let resumedPlayback: UInt64
    public let resumeSuppressedWithoutToken: UInt64
    public let recoveryRequiredAfterEnd: UInt64
    public let staleLifecycleCompletions: UInt64
    public let beginLatency: Lane3TelemetryLatencySnapshot
    public let endLatency: Lane3TelemetryLatencySnapshot
    public let resumedEndToCompletionLatency: Lane3TelemetryLatencySnapshot
}

public struct Lane3ProductionTelemetrySnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let scope: String
    public let privacy: Lane3TelemetryPrivacySnapshot
    public let totalProductSubmissions: UInt64
    public let totalInternalTransportOperations: UInt64
    public let totalPlaybackTokensObserved: UInt64
    public let totalControlPlaybackTokens: UInt64
    public let totalRecoveryPlaybackTokens: UInt64
    public let totalPreTokenSuperseded: UInt64
    public let totalCoalescedPredecessors: UInt64
    public let tokenGenerationsPerThousandProductSubmissions: Double
    public let preTokenSupersessionPerThousandProductSubmissions: Double
    public let backendDispatchEntrySamplesUnmatched: UInt64
    public let counterOverflowed: Bool
    public let perKind: [Lane3TelemetryKindSnapshot]
    public let interruption: Lane3InterruptionTelemetrySnapshot
}

private struct Lane3SaturatingCounter: Sendable {
    var value: UInt64 = 0
    var overflowed = false

    mutating func add(_ delta: UInt64 = 1) {
        let (next, overflow) = value.addingReportingOverflow(delta)
        if overflow {
            value = UInt64.max
            overflowed = true
        } else {
            value = next
        }
    }
}

private struct Lane3LatencyHistogram: Sendable {
    static let upperBoundsNanoseconds: [UInt64] = [
        1_000_000, 2_000_000, 4_000_000, 8_000_000,
        12_000_000, 16_000_000, 20_000_000, 24_000_000,
        32_000_000, 48_000_000, 64_000_000, 96_000_000,
        128_000_000, 192_000_000, 256_000_000, 384_000_000,
        512_000_000, 750_000_000, 1_000_000_000, 1_500_000_000,
        2_000_000_000, 5_000_000_000
    ]

    var buckets: [UInt64] = Array(repeating: 0, count: upperBoundsNanoseconds.count + 1)
    var samples = Lane3SaturatingCounter()
    var maxNanoseconds: UInt64 = 0

    mutating func record(_ nanoseconds: UInt64) {
        samples.add()
        maxNanoseconds = max(maxNanoseconds, nanoseconds)
        let index = Self.upperBoundsNanoseconds.firstIndex(where: { nanoseconds <= $0 })
            ?? Self.upperBoundsNanoseconds.count
        let (next, overflow) = buckets[index].addingReportingOverflow(1)
        buckets[index] = overflow ? UInt64.max : next
        if overflow { samples.overflowed = true }
    }

    func snapshot() -> Lane3TelemetryLatencySnapshot {
        Lane3TelemetryLatencySnapshot(
            samples: samples.value,
            p50UpperBoundMilliseconds: percentileUpperBound(0.50),
            p95UpperBoundMilliseconds: percentileUpperBound(0.95),
            p99UpperBoundMilliseconds: percentileUpperBound(0.99),
            maxObservedMilliseconds: Double(maxNanoseconds) / 1_000_000
        )
    }

    private func percentileUpperBound(_ fraction: Double) -> Double? {
        guard samples.value > 0 else { return nil }
        let rawTarget = (Double(samples.value) * fraction).rounded(.up)
        let target = max(UInt64(1), UInt64(min(rawTarget, Double(UInt64.max))))
        var cumulative: UInt64 = 0
        for (index, count) in buckets.enumerated() {
            let (next, overflow) = cumulative.addingReportingOverflow(count)
            cumulative = overflow ? UInt64.max : next
            if cumulative >= target {
                guard index < Self.upperBoundsNanoseconds.count else { return nil }
                return Double(Self.upperBoundsNanoseconds[index]) / 1_000_000
            }
        }
        return nil
    }
}

private struct Lane3KindTelemetryState: Sendable {
    var productSubmissions = Lane3SaturatingCounter()
    var internalTransportOperations = Lane3SaturatingCounter()
    var executed = Lane3SaturatingCounter()
    var supersededBeforeToken = Lane3SaturatingCounter()
    var cancelledBeforeDispatch = Lane3SaturatingCounter()
    var rejectedBeforeToken = Lane3SaturatingCounter()
    var failedAfterDispatch = Lane3SaturatingCounter()
    var controlPlaybackTokens = Lane3SaturatingCounter()
    var recoveryPlaybackTokens = Lane3SaturatingCounter()
    var coalescedPredecessors = Lane3SaturatingCounter()
    var callerCancellationObservedAfterDispatch = Lane3SaturatingCounter()
    var endToEndLatency = Lane3LatencyHistogram()
    var submissionToBackendEntryLatency = Lane3LatencyHistogram()
    var postConfiguredQuietResidualLatency = Lane3LatencyHistogram()
    var backendExecutionLatency = Lane3LatencyHistogram()

    var overflowed: Bool {
        [productSubmissions, internalTransportOperations, executed, supersededBeforeToken,
         cancelledBeforeDispatch, rejectedBeforeToken, failedAfterDispatch, controlPlaybackTokens,
         recoveryPlaybackTokens, coalescedPredecessors, callerCancellationObservedAfterDispatch]
            .contains(where: \.overflowed)
        || endToEndLatency.samples.overflowed
        || submissionToBackendEntryLatency.samples.overflowed
        || postConfiguredQuietResidualLatency.samples.overflowed
        || backendExecutionLatency.samples.overflowed
    }
}

private struct Lane3InterruptionTelemetryState: Sendable {
    var beginCalls = Lane3SaturatingCounter()
    var beginRejected = Lane3SaturatingCounter()
    var beginBoundaryUnsafe = Lane3SaturatingCounter()
    var endCalls = Lane3SaturatingCounter()
    var endRejected = Lane3SaturatingCounter()
    var endBoundaryUnsafe = Lane3SaturatingCounter()
    var osShouldResumeTrue = Lane3SaturatingCounter()
    var resumeArmedAtEnd = Lane3SaturatingCounter()
    var resumedPlayback = Lane3SaturatingCounter()
    var resumeSuppressedWithoutToken = Lane3SaturatingCounter()
    var recoveryRequiredAfterEnd = Lane3SaturatingCounter()
    var staleLifecycleCompletions = Lane3SaturatingCounter()
    var beginLatency = Lane3LatencyHistogram()
    var endLatency = Lane3LatencyHistogram()
    var resumedEndToCompletionLatency = Lane3LatencyHistogram()

    var overflowed: Bool {
        [beginCalls, beginRejected, beginBoundaryUnsafe, endCalls, endRejected, endBoundaryUnsafe,
         osShouldResumeTrue, resumeArmedAtEnd, resumedPlayback, resumeSuppressedWithoutToken,
         recoveryRequiredAfterEnd, staleLifecycleCompletions].contains(where: \.overflowed)
        || beginLatency.samples.overflowed
        || endLatency.samples.overflowed
        || resumedEndToCompletionLatency.samples.overflowed
    }
}

public actor Lane3ProductionTelemetryCollector {
    private let policy: Lane3TelemetryPolicy
    private var kinds: [String: Lane3KindTelemetryState] = [:]
    private var interruption = Lane3InterruptionTelemetryState()
    private var backendDispatchEntries: [String: [UInt64]] = [:]
    private var backendDispatchEntrySamplesUnmatched = Lane3SaturatingCounter()
    private var totalProductSubmissions = Lane3SaturatingCounter()
    private var totalInternalTransportOperations = Lane3SaturatingCounter()
    private var totalControlPlaybackTokens = Lane3SaturatingCounter()
    private var totalRecoveryPlaybackTokens = Lane3SaturatingCounter()
    private var totalPreTokenSuperseded = Lane3SaturatingCounter()
    private var totalCoalescedPredecessors = Lane3SaturatingCounter()

    public init(policy: Lane3TelemetryPolicy = Lane3TelemetryPolicy()) {
        self.policy = policy
    }

    public func recordBackendDispatchEntry(kind: Lane3UnifiedTransportKind, atNanoseconds: UInt64) {
        backendDispatchEntries[kind.rawValue, default: []].append(atNanoseconds)
    }

    public func recordBackendCompletion(
        kind: Lane3UnifiedTransportKind,
        durationNanoseconds: UInt64
    ) {
        var state = state(for: kind)
        state.backendExecutionLatency.record(durationNanoseconds)
        kinds[kind.rawValue] = state
    }

    public func recordGuardedSubmission(
        kind: Lane3UnifiedTransportKind,
        startedAtNanoseconds: UInt64,
        completedAtNanoseconds: UInt64,
        outcome: Lane3InterruptionGuardedOutcome
    ) {
        totalProductSubmissions.add()
        var initialState = state(for: kind)
        initialState.productSubmissions.add()
        initialState.endToEndLatency.record(elapsed(from: startedAtNanoseconds, to: completedAtNanoseconds))
        kinds[kind.rawValue] = initialState

        switch outcome {
        case let .transport(transport):
            recordTransportOutcome(
                transport,
                productKind: kind,
                productStartedAtNanoseconds: startedAtNanoseconds,
                isInternal: false
            )
        case .rejectedBeforeTransport:
            var rejectedState = state(for: kind)
            rejectedState.rejectedBeforeToken.add()
            kinds[kind.rawValue] = rejectedState
        case .resumeSuppressedWithoutToken:
            interruption.resumeSuppressedWithoutToken.add()
        }
    }

    public func recordInterruptionBegin(
        startedAtNanoseconds: UInt64,
        completedAtNanoseconds: UInt64,
        result: Lane3InterruptionBeginResult
    ) {
        totalProductSubmissions.add()
        interruption.beginCalls.add()
        interruption.beginLatency.record(elapsed(from: startedAtNanoseconds, to: completedAtNanoseconds))
        var kindState = state(for: .interruptionBegan)
        kindState.productSubmissions.add()
        kindState.endToEndLatency.record(elapsed(from: startedAtNanoseconds, to: completedAtNanoseconds))
        kinds[Lane3UnifiedTransportKind.interruptionBegan.rawValue] = kindState

        switch result {
        case let .began(receipt):
            if !receipt.boundarySafe { interruption.beginBoundaryUnsafe.add() }
            if receipt.supersededByNewerLifecycleEvent { interruption.staleLifecycleCompletions.add() }
            if let recovery = receipt.preBoundaryRecovery {
                recordTransportOutcome(recovery, productKind: .recovery, productStartedAtNanoseconds: nil, isInternal: true)
            }
            if let boundary = receipt.boundaryOutcome {
                recordTransportOutcome(boundary, productKind: .interruptionBegan, productStartedAtNanoseconds: nil, isInternal: true)
            }
        case .rejected:
            interruption.beginRejected.add()
            var rejectedState = state(for: .interruptionBegan)
            rejectedState.rejectedBeforeToken.add()
            kinds[Lane3UnifiedTransportKind.interruptionBegan.rawValue] = rejectedState
        }
    }

    public func recordInterruptionEnd(
        startedAtNanoseconds: UInt64,
        completedAtNanoseconds: UInt64,
        result: Lane3InterruptionEndResult
    ) {
        totalProductSubmissions.add()
        interruption.endCalls.add()
        let duration = elapsed(from: startedAtNanoseconds, to: completedAtNanoseconds)
        interruption.endLatency.record(duration)
        var kindState = state(for: .interruptionEnded)
        kindState.productSubmissions.add()
        kindState.endToEndLatency.record(duration)
        kinds[Lane3UnifiedTransportKind.interruptionEnded.rawValue] = kindState

        switch result {
        case let .ended(receipt):
            if !receipt.boundarySafe { interruption.endBoundaryUnsafe.add() }
            if receipt.osShouldResume { interruption.osShouldResumeTrue.add() }
            if receipt.resumeWasArmed { interruption.resumeArmedAtEnd.add() }
            if receipt.resumedPlayback {
                interruption.resumedPlayback.add()
                interruption.resumedEndToCompletionLatency.record(duration)
            }
            if receipt.recoveryRequired { interruption.recoveryRequiredAfterEnd.add() }
            if receipt.supersededByNewerLifecycleEvent { interruption.staleLifecycleCompletions.add() }
            if let recovery = receipt.preBoundaryRecovery {
                recordTransportOutcome(recovery, productKind: .recovery, productStartedAtNanoseconds: nil, isInternal: true)
            }
            if let boundary = receipt.boundaryOutcome {
                recordTransportOutcome(boundary, productKind: .interruptionEnded, productStartedAtNanoseconds: nil, isInternal: true)
            }
            if let resume = receipt.resumeOutcome {
                recordTransportOutcome(resume, productKind: .play, productStartedAtNanoseconds: nil, isInternal: true)
            }
            if let pause = receipt.compensatingPauseOutcome {
                recordTransportOutcome(pause, productKind: .pause, productStartedAtNanoseconds: nil, isInternal: true)
            }
        case .rejected:
            interruption.endRejected.add()
            var rejectedState = state(for: .interruptionEnded)
            rejectedState.rejectedBeforeToken.add()
            kinds[Lane3UnifiedTransportKind.interruptionEnded.rawValue] = rejectedState
        }
    }

    public func snapshot() -> Lane3ProductionTelemetrySnapshot {
        let kindSnapshots = Lane3UnifiedTransportKind.allCases.map { kind -> Lane3TelemetryKindSnapshot in
            let s = state(for: kind)
            return Lane3TelemetryKindSnapshot(
                kind: kind.rawValue,
                productSubmissions: s.productSubmissions.value,
                internalTransportOperations: s.internalTransportOperations.value,
                executed: s.executed.value,
                supersededBeforeToken: s.supersededBeforeToken.value,
                cancelledBeforeDispatch: s.cancelledBeforeDispatch.value,
                rejectedBeforeToken: s.rejectedBeforeToken.value,
                failedAfterDispatch: s.failedAfterDispatch.value,
                controlPlaybackTokens: s.controlPlaybackTokens.value,
                recoveryPlaybackTokens: s.recoveryPlaybackTokens.value,
                coalescedPredecessors: s.coalescedPredecessors.value,
                callerCancellationObservedAfterDispatch: s.callerCancellationObservedAfterDispatch.value,
                endToEndLatency: s.endToEndLatency.snapshot(),
                submissionToBackendEntryLatency: s.submissionToBackendEntryLatency.snapshot(),
                postConfiguredQuietResidualLatency: s.postConfiguredQuietResidualLatency.snapshot(),
                backendExecutionLatency: s.backendExecutionLatency.snapshot()
            )
        }
        let product = totalProductSubmissions.value
        let totalTokens = saturatingSum(totalControlPlaybackTokens.value, totalRecoveryPlaybackTokens.value)
        let overflowed = totalProductSubmissions.overflowed
            || totalInternalTransportOperations.overflowed
            || totalControlPlaybackTokens.overflowed
            || totalRecoveryPlaybackTokens.overflowed
            || totalPreTokenSuperseded.overflowed
            || totalCoalescedPredecessors.overflowed
            || backendDispatchEntrySamplesUnmatched.overflowed
            || interruption.overflowed
            || kinds.values.contains(where: \.overflowed)

        return Lane3ProductionTelemetrySnapshot(
            schemaVersion: 1,
            scope: "LANE3_PRIVACY_PRESERVING_PRODUCTION_TELEMETRY_NON_PARITY",
            privacy: Lane3TelemetryPrivacySnapshot(
                aggregationOnly: true,
                rawEventLogRetained: false,
                absoluteWallClockCaptured: false,
                projectIdentifierCaptured: false,
                mediaNameOrPathCaptured: false,
                pcmOrAudioContentCaptured: false,
                ticketOrGenerationValueExported: false
            ),
            totalProductSubmissions: product,
            totalInternalTransportOperations: totalInternalTransportOperations.value,
            totalPlaybackTokensObserved: totalTokens,
            totalControlPlaybackTokens: totalControlPlaybackTokens.value,
            totalRecoveryPlaybackTokens: totalRecoveryPlaybackTokens.value,
            totalPreTokenSuperseded: totalPreTokenSuperseded.value,
            totalCoalescedPredecessors: totalCoalescedPredecessors.value,
            tokenGenerationsPerThousandProductSubmissions: ratePerThousand(totalTokens, denominator: product),
            preTokenSupersessionPerThousandProductSubmissions: ratePerThousand(totalPreTokenSuperseded.value, denominator: product),
            backendDispatchEntrySamplesUnmatched: backendDispatchEntrySamplesUnmatched.value,
            counterOverflowed: overflowed,
            perKind: kindSnapshots,
            interruption: Lane3InterruptionTelemetrySnapshot(
                beginCalls: interruption.beginCalls.value,
                beginRejected: interruption.beginRejected.value,
                beginBoundaryUnsafe: interruption.beginBoundaryUnsafe.value,
                endCalls: interruption.endCalls.value,
                endRejected: interruption.endRejected.value,
                endBoundaryUnsafe: interruption.endBoundaryUnsafe.value,
                osShouldResumeTrue: interruption.osShouldResumeTrue.value,
                resumeArmedAtEnd: interruption.resumeArmedAtEnd.value,
                resumedPlayback: interruption.resumedPlayback.value,
                resumeSuppressedWithoutToken: interruption.resumeSuppressedWithoutToken.value,
                recoveryRequiredAfterEnd: interruption.recoveryRequiredAfterEnd.value,
                staleLifecycleCompletions: interruption.staleLifecycleCompletions.value,
                beginLatency: interruption.beginLatency.snapshot(),
                endLatency: interruption.endLatency.snapshot(),
                resumedEndToCompletionLatency: interruption.resumedEndToCompletionLatency.snapshot()
            )
        )
    }

    private func recordTransportOutcome(
        _ outcome: Lane3UnifiedTransportOutcome,
        productKind: Lane3UnifiedTransportKind,
        productStartedAtNanoseconds: UInt64?,
        isInternal: Bool
    ) {
        let actualKind = kind(from: outcome) ?? productKind
        var state = state(for: actualKind)
        if isInternal {
            state.internalTransportOperations.add()
            totalInternalTransportOperations.add()
        }

        switch outcome {
        case let .executed(receipt):
            state.executed.add()
            state.controlPlaybackTokens.add()
            totalControlPlaybackTokens.add()
            state.coalescedPredecessors.add(UInt64(max(0, receipt.coalescedPredecessorCount)))
            totalCoalescedPredecessors.add(UInt64(max(0, receipt.coalescedPredecessorCount)))
            if receipt.callerCancellationObservedAfterDispatch {
                state.callerCancellationObservedAfterDispatch.add()
            }
            if let started = productStartedAtNanoseconds {
                recordDispatchEntryLatencyIfAvailable(kind: actualKind, startedAtNanoseconds: started, state: &state)
            } else {
                discardOneBackendEntryIfPresent(kind: actualKind)
            }
        case .supersededBeforeToken:
            state.supersededBeforeToken.add()
            totalPreTokenSuperseded.add()
        case .cancelledBeforeDispatch:
            state.cancelledBeforeDispatch.add()
        case .rejectedBeforeToken:
            state.rejectedBeforeToken.add()
        case let .failedAfterDispatch(failure):
            state.failedAfterDispatch.add()
            if failure.playbackGeneration != nil {
                state.controlPlaybackTokens.add()
                totalControlPlaybackTokens.add()
            }
            if failure.callerCancellationObservedAfterDispatch {
                state.callerCancellationObservedAfterDispatch.add()
            }
            if failure.automaticRecovery.attempted {
                if failure.automaticRecovery.playbackGeneration != nil {
                    state.recoveryPlaybackTokens.add()
                    totalRecoveryPlaybackTokens.add()
                }
            }
            if let started = productStartedAtNanoseconds {
                recordDispatchEntryLatencyIfAvailable(kind: actualKind, startedAtNanoseconds: started, state: &state)
            } else {
                discardOneBackendEntryIfPresent(kind: actualKind)
            }
        }
        kinds[actualKind.rawValue] = state
    }

    private func recordDispatchEntryLatencyIfAvailable(
        kind: Lane3UnifiedTransportKind,
        startedAtNanoseconds: UInt64,
        state: inout Lane3KindTelemetryState
    ) {
        guard backendInstrumentable(kind: kind) else { return }
        guard var entries = backendDispatchEntries[kind.rawValue], !entries.isEmpty else {
            backendDispatchEntrySamplesUnmatched.add()
            return
        }
        let entry = entries.removeFirst()
        backendDispatchEntries[kind.rawValue] = entries
        let latency = elapsed(from: startedAtNanoseconds, to: entry)
        state.submissionToBackendEntryLatency.record(latency)
        let quiet = policy.quietPeriodNanoseconds(for: kind)
        state.postConfiguredQuietResidualLatency.record(latency > quiet ? latency - quiet : 0)
    }

    private func discardOneBackendEntryIfPresent(kind: Lane3UnifiedTransportKind) {
        guard backendInstrumentable(kind: kind),
              var entries = backendDispatchEntries[kind.rawValue], !entries.isEmpty else { return }
        entries.removeFirst()
        backendDispatchEntries[kind.rawValue] = entries
    }

    private func backendInstrumentable(kind: Lane3UnifiedTransportKind) -> Bool {
        switch kind {
        case .seek, .loop, .mediaLoad, .mediaReplacement, .play, .pause: return true
        default: return false
        }
    }

    private func kind(from outcome: Lane3UnifiedTransportOutcome) -> Lane3UnifiedTransportKind? {
        switch outcome {
        case let .executed(receipt): return receipt.kind
        case let .supersededBeforeToken(_, _, kind): return kind
        case let .cancelledBeforeDispatch(_, kind): return kind
        case let .rejectedBeforeToken(_, kind, _): return kind
        case let .failedAfterDispatch(failure): return failure.kind
        }
    }

    private func state(for kind: Lane3UnifiedTransportKind) -> Lane3KindTelemetryState {
        kinds[kind.rawValue] ?? Lane3KindTelemetryState()
    }

    private func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }

    private func saturatingSum(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }

    private func ratePerThousand(_ numerator: UInt64, denominator: UInt64) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) * 1_000 / Double(denominator)
    }
}
