import Foundation

public enum Lane3CandidatePhysicalSamplingAbortReason: String, Codable, Sendable {
    case hostCancelled
    case applicationWillResignActive
    case applicationDidEnterBackground
    case applicationWillTerminate
    case samplingFailed
    case cadenceGapExceeded
}

public enum Lane3CandidatePhysicalSamplingLifecycleState: String, Codable, Sendable {
    case prepared
    case running
    case completed
    case aborted
}

public enum Lane3CandidatePhysicalSamplingLifecycleError: Error, Equatable, Sendable {
    case invalidUptime
    case alreadyStarted
    case notRunning
    case terminalState(Lane3CandidatePhysicalSamplingLifecycleState)
    case nonMonotonicTick(previous: Double, next: Double)
    case cadenceGapExceeded(maximumAllowedSeconds: Double, observedSeconds: Double)
}

/// Portable AW53 lifecycle gate for the physical candidate sampler.
///
/// The selected-iOS driver owns scheduling and UIKit notifications; this value type owns the
/// fail-closed state transition and cadence contract so it can be regression-tested on Linux.
public struct Lane3CandidatePhysicalSamplingLifecycle: Equatable, Sendable {
    public static let recommendedCadenceSeconds =
        Lane3CandidatePhysicalResourceTraceAccumulator.recommendedSamplingIntervalSeconds
    public static let maximumCadenceGapSeconds =
        Lane3CandidatePhysicalResourceTraceAccumulator.maximumSamplingIntervalSeconds

    public private(set) var state: Lane3CandidatePhysicalSamplingLifecycleState = .prepared
    public private(set) var firstSampleUptimeSeconds: Double?
    public private(set) var lastSampleUptimeSeconds: Double?
    public private(set) var acceptedSamples: Int = 0
    public private(set) var maximumObservedGapSeconds: Double = 0
    public private(set) var abortReason: Lane3CandidatePhysicalSamplingAbortReason?

    public init() {}

    public mutating func start(firstSampleUptimeSeconds uptime: Double) throws {
        guard uptime.isFinite, uptime >= 0 else {
            throw Lane3CandidatePhysicalSamplingLifecycleError.invalidUptime
        }
        switch state {
        case .prepared:
            state = .running
            firstSampleUptimeSeconds = uptime
            lastSampleUptimeSeconds = uptime
            acceptedSamples = 1
            maximumObservedGapSeconds = 0
            abortReason = nil
        case .running:
            throw Lane3CandidatePhysicalSamplingLifecycleError.alreadyStarted
        case .completed, .aborted:
            throw Lane3CandidatePhysicalSamplingLifecycleError.terminalState(state)
        }
    }

    public mutating func acceptSample(uptimeSeconds uptime: Double) throws {
        guard uptime.isFinite, uptime >= 0 else {
            throw Lane3CandidatePhysicalSamplingLifecycleError.invalidUptime
        }
        guard state == .running else {
            if state == .prepared {
                throw Lane3CandidatePhysicalSamplingLifecycleError.notRunning
            }
            throw Lane3CandidatePhysicalSamplingLifecycleError.terminalState(state)
        }
        guard let previous = lastSampleUptimeSeconds else {
            throw Lane3CandidatePhysicalSamplingLifecycleError.notRunning
        }
        guard uptime > previous else {
            throw Lane3CandidatePhysicalSamplingLifecycleError.nonMonotonicTick(
                previous: previous,
                next: uptime
            )
        }
        let gap = uptime - previous
        guard gap <= Self.maximumCadenceGapSeconds else {
            throw Lane3CandidatePhysicalSamplingLifecycleError.cadenceGapExceeded(
                maximumAllowedSeconds: Self.maximumCadenceGapSeconds,
                observedSeconds: gap
            )
        }
        lastSampleUptimeSeconds = uptime
        acceptedSamples += 1
        maximumObservedGapSeconds = max(maximumObservedGapSeconds, gap)
    }

    public mutating func complete() throws {
        guard state == .running else {
            if state == .prepared {
                throw Lane3CandidatePhysicalSamplingLifecycleError.notRunning
            }
            throw Lane3CandidatePhysicalSamplingLifecycleError.terminalState(state)
        }
        state = .completed
    }

    public mutating func abort(_ reason: Lane3CandidatePhysicalSamplingAbortReason) {
        guard state == .prepared || state == .running else { return }
        state = .aborted
        abortReason = reason
    }

    public var isTerminal: Bool {
        state == .completed || state == .aborted
    }
}
