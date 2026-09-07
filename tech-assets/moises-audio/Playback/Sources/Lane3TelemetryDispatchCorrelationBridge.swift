import Foundation

public struct Lane3TelemetryCorrelationHealthSnapshot: Codable, Equatable, Sendable {
    public let maxPendingPerKind: Int
    public let pendingEntries: UInt64
    public let overflowDrops: UInt64
    public let unmatchedBackendOutcomes: UInt64
}

/// Bounds the short-lived backend-entry timestamps used only to correlate product submission time
/// with the real Playback backend entry. The bridge never receives project/media/audio data and
/// forwards a matched timestamp to the aggregate collector only immediately before that outcome is
/// aggregated. This prevents the collector from accumulating raw monotonic entries if App code is
/// accidentally misrouted or caller tasks are delayed.
public actor Lane3TelemetryDispatchCorrelationBridge {
    private let maxPendingPerKind: Int
    private var entries: [String: [UInt64]] = [:]
    private var overflowDrops: UInt64 = 0
    private var unmatchedBackendOutcomes: UInt64 = 0

    public init(maxPendingPerKind: Int = 256) {
        self.maxPendingPerKind = max(1, maxPendingPerKind)
    }

    public func recordBackendEntry(
        kind: Lane3UnifiedTransportKind,
        atNanoseconds: UInt64
    ) {
        var queue = entries[kind.rawValue, default: []]
        if queue.count >= maxPendingPerKind {
            queue.removeFirst()
            overflowDrops = saturatingIncrement(overflowDrops)
        }
        queue.append(atNanoseconds)
        entries[kind.rawValue] = queue
    }

    public func forwardCorrelation(
        for guardedOutcome: Lane3InterruptionGuardedOutcome,
        expectedProductKind: Lane3UnifiedTransportKind,
        to collector: Lane3ProductionTelemetryCollector
    ) async {
        guard case let .transport(outcome) = guardedOutcome else { return }
        await forwardCorrelation(for: outcome, fallbackKind: expectedProductKind, to: collector)
    }

    public func forwardCorrelations(
        for beginResult: Lane3InterruptionBeginResult,
        to collector: Lane3ProductionTelemetryCollector
    ) async {
        guard case let .began(receipt) = beginResult else { return }
        if let recovery = receipt.preBoundaryRecovery {
            await forwardCorrelation(for: recovery, fallbackKind: .recovery, to: collector)
        }
        if let boundary = receipt.boundaryOutcome {
            await forwardCorrelation(for: boundary, fallbackKind: .interruptionBegan, to: collector)
        }
    }

    public func forwardCorrelations(
        for endResult: Lane3InterruptionEndResult,
        to collector: Lane3ProductionTelemetryCollector
    ) async {
        guard case let .ended(receipt) = endResult else { return }
        if let recovery = receipt.preBoundaryRecovery {
            await forwardCorrelation(for: recovery, fallbackKind: .recovery, to: collector)
        }
        if let boundary = receipt.boundaryOutcome {
            await forwardCorrelation(for: boundary, fallbackKind: .interruptionEnded, to: collector)
        }
        if let resume = receipt.resumeOutcome {
            await forwardCorrelation(for: resume, fallbackKind: .play, to: collector)
        }
        if let pause = receipt.compensatingPauseOutcome {
            await forwardCorrelation(for: pause, fallbackKind: .pause, to: collector)
        }
    }

    public func snapshot() -> Lane3TelemetryCorrelationHealthSnapshot {
        var pending: UInt64 = 0
        for queue in entries.values {
            let (next, overflow) = pending.addingReportingOverflow(UInt64(queue.count))
            pending = overflow ? UInt64.max : next
        }
        return Lane3TelemetryCorrelationHealthSnapshot(
            maxPendingPerKind: maxPendingPerKind,
            pendingEntries: pending,
            overflowDrops: overflowDrops,
            unmatchedBackendOutcomes: unmatchedBackendOutcomes
        )
    }

    private func forwardCorrelation(
        for outcome: Lane3UnifiedTransportOutcome,
        fallbackKind: Lane3UnifiedTransportKind,
        to collector: Lane3ProductionTelemetryCollector
    ) async {
        let kind: Lane3UnifiedTransportKind
        switch outcome {
        case let .executed(receipt): kind = receipt.kind
        case let .failedAfterDispatch(failure): kind = failure.kind
        case let .supersededBeforeToken(_, _, value): kind = value
        case let .cancelledBeforeDispatch(_, value): kind = value
        case let .rejectedBeforeToken(_, value, _): kind = value
        }
        let resolvedKind = kind.rawValue.isEmpty ? fallbackKind : kind
        guard backendInstrumentable(resolvedKind) else { return }
        switch outcome {
        case .executed, .failedAfterDispatch:
            guard var queue = entries[resolvedKind.rawValue], !queue.isEmpty else {
                unmatchedBackendOutcomes = saturatingIncrement(unmatchedBackendOutcomes)
                return
            }
            let timestamp = queue.removeFirst()
            entries[resolvedKind.rawValue] = queue
            await collector.recordBackendDispatchEntry(
                kind: resolvedKind,
                atNanoseconds: timestamp
            )
        default:
            return
        }
    }

    private func backendInstrumentable(_ kind: Lane3UnifiedTransportKind) -> Bool {
        switch kind {
        case .seek, .loop, .mediaLoad, .mediaReplacement, .play, .pause: return true
        default: return false
        }
    }

    private func saturatingIncrement(_ value: UInt64) -> UInt64 {
        let (next, overflow) = value.addingReportingOverflow(1)
        return overflow ? UInt64.max : next
    }
}
