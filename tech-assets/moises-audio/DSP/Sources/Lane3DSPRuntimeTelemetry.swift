import Foundation
import Dispatch

public enum Lane3DSPRuntimeOperationKind: String, Codable, Sendable, CaseIterable {
    case tempo
    case pitch
    case metronomeMutation
    case countInArm
    case countInConsume
    case countInDiscard
    case recovery
    case metronomeReplaceSchedule
    case metronomeAppendSchedule
    case countInReplaceSchedule
}

public protocol Lane3DSPRuntimeTelemetryTimeSource: Sendable {
    func nowNanoseconds() -> UInt64
}

public struct Lane3DSPSystemTelemetryTimeSource: Lane3DSPRuntimeTelemetryTimeSource {
    public init() {}
    public func nowNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
}

public struct Lane3DSPRuntimeTelemetryPrivacySnapshot: Codable, Equatable, Sendable {
    public let aggregationOnly: Bool
    public let rawEventLogRetained: Bool
    public let absoluteWallClockCaptured: Bool
    public let projectIdentifierCaptured: Bool
    public let mediaNameOrPathCaptured: Bool
    public let pcmOrAudioContentCaptured: Bool
    public let ticketOrGenerationValueExported: Bool
    public let taskLocalTracePersisted: Bool
    public let taskLocalTraceContainsOnlyOperationKindAndMonotonicStart: Bool
}

public struct Lane3DSPRuntimeLatencySnapshot: Codable, Equatable, Sendable {
    public let samples: UInt64
    public let p50UpperBoundMilliseconds: Double?
    public let p95UpperBoundMilliseconds: Double?
    public let p99UpperBoundMilliseconds: Double?
    public let maxObservedMilliseconds: Double
}

public struct Lane3DSPRuntimeKindSnapshot: Codable, Equatable, Sendable {
    public let kind: String
    public let productSubmissions: UInt64
    public let productSucceeded: UInt64
    public let productFailed: UInt64
    public let backendApplyCalls: UInt64
    public let backendPrimaryEntries: UInt64
    public let backendAdditionalAppliesWithinOperation: UInt64
    public let clickInvalidationCalls: UInt64
    public let clickInvalidationPrimaryEntries: UInt64
    public let clickInvalidationAdditionalCallsWithinOperation: UInt64
    public let productEndToEndLatency: Lane3DSPRuntimeLatencySnapshot
    public let submissionToBackendEntryLatency: Lane3DSPRuntimeLatencySnapshot
    public let backendApplyExecutionLatency: Lane3DSPRuntimeLatencySnapshot
    public let submissionToClickInvalidationLatency: Lane3DSPRuntimeLatencySnapshot
    public let clickInvalidationExecutionLatency: Lane3DSPRuntimeLatencySnapshot
}

public struct Lane3DSPRuntimeTelemetrySnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let scope: String
    public let privacy: Lane3DSPRuntimeTelemetryPrivacySnapshot
    public let unscopedBackendApplyCalls: UInt64
    public let unscopedClickInvalidationCalls: UInt64
    public let counterOverflowed: Bool
    public let perKind: [Lane3DSPRuntimeKindSnapshot]
}

private struct Lane3DSPSaturatingCounter {
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

private struct Lane3DSPRuntimeHistogram {
    static let upperBoundsNanoseconds: [UInt64] = [
        250_000, 500_000, 1_000_000, 2_000_000, 4_000_000, 8_000_000,
        12_000_000, 16_000_000, 24_000_000, 32_000_000, 48_000_000,
        64_000_000, 96_000_000, 128_000_000, 192_000_000, 256_000_000,
        384_000_000, 512_000_000, 750_000_000, 1_000_000_000, 2_000_000_000,
        5_000_000_000
    ]

    var buckets: [UInt64] = Array(repeating: 0, count: upperBoundsNanoseconds.count + 1)
    var samples = Lane3DSPSaturatingCounter()
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

    func snapshot() -> Lane3DSPRuntimeLatencySnapshot {
        Lane3DSPRuntimeLatencySnapshot(
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

private struct Lane3DSPRuntimeKindState {
    var productSubmissions = Lane3DSPSaturatingCounter()
    var productSucceeded = Lane3DSPSaturatingCounter()
    var productFailed = Lane3DSPSaturatingCounter()
    var backendApplyCalls = Lane3DSPSaturatingCounter()
    var backendPrimaryEntries = Lane3DSPSaturatingCounter()
    var backendAdditionalAppliesWithinOperation = Lane3DSPSaturatingCounter()
    var clickInvalidationCalls = Lane3DSPSaturatingCounter()
    var clickInvalidationPrimaryEntries = Lane3DSPSaturatingCounter()
    var clickInvalidationAdditionalCallsWithinOperation = Lane3DSPSaturatingCounter()
    var productEndToEndLatency = Lane3DSPRuntimeHistogram()
    var submissionToBackendEntryLatency = Lane3DSPRuntimeHistogram()
    var backendApplyExecutionLatency = Lane3DSPRuntimeHistogram()
    var submissionToClickInvalidationLatency = Lane3DSPRuntimeHistogram()
    var clickInvalidationExecutionLatency = Lane3DSPRuntimeHistogram()

    var overflowed: Bool {
        [productSubmissions, productSucceeded, productFailed, backendApplyCalls,
         backendPrimaryEntries, backendAdditionalAppliesWithinOperation,
         clickInvalidationCalls, clickInvalidationPrimaryEntries,
         clickInvalidationAdditionalCallsWithinOperation].contains(where: \.overflowed)
        || productEndToEndLatency.samples.overflowed
        || submissionToBackendEntryLatency.samples.overflowed
        || backendApplyExecutionLatency.samples.overflowed
        || submissionToClickInvalidationLatency.samples.overflowed
        || clickInvalidationExecutionLatency.samples.overflowed
    }
}

final class Lane3DSPRuntimeTelemetryTrace: @unchecked Sendable {
    let kind: Lane3DSPRuntimeOperationKind
    let startedAtNanoseconds: UInt64
    private let lock = NSLock()
    private var backendEntryClaimed = false
    private var clickInvalidationEntryClaimed = false

    init(kind: Lane3DSPRuntimeOperationKind, startedAtNanoseconds: UInt64) {
        self.kind = kind
        self.startedAtNanoseconds = startedAtNanoseconds
    }

    func claimBackendEntry(at nanoseconds: UInt64) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        guard !backendEntryClaimed else { return nil }
        backendEntryClaimed = true
        return Self.elapsed(from: startedAtNanoseconds, to: nanoseconds)
    }

    func claimClickInvalidationEntry(at nanoseconds: UInt64) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        guard !clickInvalidationEntryClaimed else { return nil }
        clickInvalidationEntryClaimed = true
        return Self.elapsed(from: startedAtNanoseconds, to: nanoseconds)
    }

    private static func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }
}

enum Lane3DSPRuntimeTelemetryTaskContext {
    @TaskLocal static var trace: Lane3DSPRuntimeTelemetryTrace?
}

public final class Lane3DSPRuntimeTelemetryCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [Lane3DSPRuntimeOperationKind: Lane3DSPRuntimeKindState] = [:]
    private var unscopedBackendApplyCalls = Lane3DSPSaturatingCounter()
    private var unscopedClickInvalidationCalls = Lane3DSPSaturatingCounter()

    public init() {}

    func recordProductSubmission(kind: Lane3DSPRuntimeOperationKind) {
        withState(kind) { $0.productSubmissions.add() }
    }

    func recordProductCompletion(
        kind: Lane3DSPRuntimeOperationKind,
        durationNanoseconds: UInt64,
        succeeded: Bool
    ) {
        withState(kind) { state in
            if succeeded { state.productSucceeded.add() } else { state.productFailed.add() }
            state.productEndToEndLatency.record(durationNanoseconds)
        }
    }

    func recordBackendEntry(trace: Lane3DSPRuntimeTelemetryTrace?, at nanoseconds: UInt64) {
        guard let trace else {
            lock.lock(); defer { lock.unlock() }
            unscopedBackendApplyCalls.add()
            return
        }
        let firstLatency = trace.claimBackendEntry(at: nanoseconds)
        withState(trace.kind) { state in
            state.backendApplyCalls.add()
            if let firstLatency {
                state.backendPrimaryEntries.add()
                state.submissionToBackendEntryLatency.record(firstLatency)
            } else {
                state.backendAdditionalAppliesWithinOperation.add()
            }
        }
    }

    func recordBackendCompletion(
        trace: Lane3DSPRuntimeTelemetryTrace?,
        durationNanoseconds: UInt64
    ) {
        guard let trace else { return }
        withState(trace.kind) { state in
            state.backendApplyExecutionLatency.record(durationNanoseconds)
        }
    }

    func recordClickInvalidationEntry(trace: Lane3DSPRuntimeTelemetryTrace?, at nanoseconds: UInt64) {
        guard let trace else {
            lock.lock(); defer { lock.unlock() }
            unscopedClickInvalidationCalls.add()
            return
        }
        let firstLatency = trace.claimClickInvalidationEntry(at: nanoseconds)
        withState(trace.kind) { state in
            state.clickInvalidationCalls.add()
            if let firstLatency {
                state.clickInvalidationPrimaryEntries.add()
                state.submissionToClickInvalidationLatency.record(firstLatency)
            } else {
                state.clickInvalidationAdditionalCallsWithinOperation.add()
            }
        }
    }

    func recordClickInvalidationCompletion(
        trace: Lane3DSPRuntimeTelemetryTrace?,
        durationNanoseconds: UInt64
    ) {
        guard let trace else { return }
        withState(trace.kind) { state in
            state.clickInvalidationExecutionLatency.record(durationNanoseconds)
        }
    }

    public func snapshot() -> Lane3DSPRuntimeTelemetrySnapshot {
        lock.lock()
        defer { lock.unlock() }
        let snapshots = Lane3DSPRuntimeOperationKind.allCases.map { kind -> Lane3DSPRuntimeKindSnapshot in
            let state = states[kind] ?? Lane3DSPRuntimeKindState()
            return Lane3DSPRuntimeKindSnapshot(
                kind: kind.rawValue,
                productSubmissions: state.productSubmissions.value,
                productSucceeded: state.productSucceeded.value,
                productFailed: state.productFailed.value,
                backendApplyCalls: state.backendApplyCalls.value,
                backendPrimaryEntries: state.backendPrimaryEntries.value,
                backendAdditionalAppliesWithinOperation: state.backendAdditionalAppliesWithinOperation.value,
                clickInvalidationCalls: state.clickInvalidationCalls.value,
                clickInvalidationPrimaryEntries: state.clickInvalidationPrimaryEntries.value,
                clickInvalidationAdditionalCallsWithinOperation: state.clickInvalidationAdditionalCallsWithinOperation.value,
                productEndToEndLatency: state.productEndToEndLatency.snapshot(),
                submissionToBackendEntryLatency: state.submissionToBackendEntryLatency.snapshot(),
                backendApplyExecutionLatency: state.backendApplyExecutionLatency.snapshot(),
                submissionToClickInvalidationLatency: state.submissionToClickInvalidationLatency.snapshot(),
                clickInvalidationExecutionLatency: state.clickInvalidationExecutionLatency.snapshot()
            )
        }
        return Lane3DSPRuntimeTelemetrySnapshot(
            schemaVersion: 1,
            scope: "LANE3_DSP_RUNTIME_TASKLOCAL_TELEMETRY_NON_PARITY",
            privacy: Lane3DSPRuntimeTelemetryPrivacySnapshot(
                aggregationOnly: true,
                rawEventLogRetained: false,
                absoluteWallClockCaptured: false,
                projectIdentifierCaptured: false,
                mediaNameOrPathCaptured: false,
                pcmOrAudioContentCaptured: false,
                ticketOrGenerationValueExported: false,
                taskLocalTracePersisted: false,
                taskLocalTraceContainsOnlyOperationKindAndMonotonicStart: true
            ),
            unscopedBackendApplyCalls: unscopedBackendApplyCalls.value,
            unscopedClickInvalidationCalls: unscopedClickInvalidationCalls.value,
            counterOverflowed: states.values.contains(where: \.overflowed)
                || unscopedBackendApplyCalls.overflowed
                || unscopedClickInvalidationCalls.overflowed,
            perKind: snapshots
        )
    }

    private func withState(
        _ kind: Lane3DSPRuntimeOperationKind,
        mutate: (inout Lane3DSPRuntimeKindState) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        var state = states[kind] ?? Lane3DSPRuntimeKindState()
        mutate(&state)
        states[kind] = state
    }
}

public final class Lane3DSPRuntimeTelemetryProbe: @unchecked Sendable {
    private let collector: Lane3DSPRuntimeTelemetryCollector
    private let timeSource: any Lane3DSPRuntimeTelemetryTimeSource

    public init(
        collector: Lane3DSPRuntimeTelemetryCollector,
        timeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource()
    ) {
        self.collector = collector
        self.timeSource = timeSource
    }

    public func measureAsync<T>(
        kind: Lane3DSPRuntimeOperationKind,
        operation: () async throws -> T
    ) async rethrows -> T {
        let started = timeSource.nowNanoseconds()
        let trace = Lane3DSPRuntimeTelemetryTrace(kind: kind, startedAtNanoseconds: started)
        collector.recordProductSubmission(kind: kind)
        return try await Lane3DSPRuntimeTelemetryTaskContext.$trace.withValue(trace) {
            do {
                let value = try await operation()
                collector.recordProductCompletion(
                    kind: kind,
                    durationNanoseconds: Self.elapsed(from: started, to: timeSource.nowNanoseconds()),
                    succeeded: true
                )
                return value
            } catch {
                collector.recordProductCompletion(
                    kind: kind,
                    durationNanoseconds: Self.elapsed(from: started, to: timeSource.nowNanoseconds()),
                    succeeded: false
                )
                throw error
            }
        }
    }

    public func measureSync<T>(
        kind: Lane3DSPRuntimeOperationKind,
        operation: () throws -> T
    ) rethrows -> T {
        let started = timeSource.nowNanoseconds()
        let trace = Lane3DSPRuntimeTelemetryTrace(kind: kind, startedAtNanoseconds: started)
        collector.recordProductSubmission(kind: kind)
        return try Lane3DSPRuntimeTelemetryTaskContext.$trace.withValue(trace) {
            do {
                let value = try operation()
                collector.recordProductCompletion(
                    kind: kind,
                    durationNanoseconds: Self.elapsed(from: started, to: timeSource.nowNanoseconds()),
                    succeeded: true
                )
                return value
            } catch {
                collector.recordProductCompletion(
                    kind: kind,
                    durationNanoseconds: Self.elapsed(from: started, to: timeSource.nowNanoseconds()),
                    succeeded: false
                )
                throw error
            }
        }
    }

    public func snapshot() -> Lane3DSPRuntimeTelemetrySnapshot { collector.snapshot() }

    private static func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }
}
