import Foundation

public enum Lane3UnifiedTransportCancellationRaceOperation: Equatable, Sendable {
    case seek(
        basePositionSeconds: Double,
        stepSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    )
    case loop(
        baseStartSeconds: Double,
        durationSeconds: Double,
        stepSeconds: Double
    )
}

public enum Lane3UnifiedTransportCancellationRaceAdapterError: Error, Equatable, Sendable {
    case invalidBasePosition(Double)
    case invalidStep(Double)
    case invalidLoopDuration(Double)
    case positionOverflow
}

/// AW37 Lane-local adapter that drives the real unified transport authority through cancellation
/// races without depending on the Lane-4 build harness. The adapter exposes only existing product
/// operations and the AW36 authority snapshot; it does not change transport ordering or cancellation
/// semantics.
public struct Lane3UnifiedTransportCancellationRaceAdapter: Lane3CancellationRaceProbeDriving, Sendable {
    private let authority: Lane3UnifiedProductionTransportAuthority
    private let operation: Lane3UnifiedTransportCancellationRaceOperation

    public init(
        authority: Lane3UnifiedProductionTransportAuthority,
        operation: Lane3UnifiedTransportCancellationRaceOperation
    ) throws {
        switch operation {
        case let .seek(base, step, _, loop):
            guard base.isFinite, base >= 0 else {
                throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidBasePosition(base)
            }
            guard step.isFinite, step >= 0 else {
                throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidStep(step)
            }
            if let loop {
                guard loop.startSeconds.isFinite,
                      loop.endSeconds.isFinite,
                      loop.startSeconds >= 0,
                      loop.endSeconds > loop.startSeconds else {
                    throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidLoopDuration(
                        loop.endSeconds - loop.startSeconds
                    )
                }
            }
        case let .loop(base, duration, step):
            guard base.isFinite, base >= 0 else {
                throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidBasePosition(base)
            }
            guard duration.isFinite, duration > 0 else {
                throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidLoopDuration(duration)
            }
            guard step.isFinite, step >= 0 else {
                throw Lane3UnifiedTransportCancellationRaceAdapterError.invalidStep(step)
            }
        }
        self.authority = authority
        self.operation = operation
    }

    public func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
        guard index >= 0 else { return .rejectedBeforeToken }
        switch operation {
        case let .seek(base, step, resume, loop):
            guard let position = Self.offset(base: base, step: step, index: index) else {
                return .rejectedBeforeToken
            }
            return Self.map(await authority.submitSeek(to: position, resume: resume, loop: loop))

        case let .loop(base, duration, step):
            guard let start = Self.offset(base: base, step: step, index: index),
                  let end = Self.add(start, duration) else {
                return .rejectedBeforeToken
            }
            return Self.map(await authority.submitLoop(
                PlaybackLoopRange(startSeconds: start, endSeconds: end)
            ))
        }
    }

    public func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot {
        let snapshot = await authority.snapshot()
        return Lane3CancellationRaceProbeSnapshot(
            pendingOperationCount: snapshot.pendingContinuousKinds.count + snapshot.pendingDiscreteKinds.count,
            executionInFlight: snapshot.executionInFlight,
            admittingTicketCount: snapshot.cancellationAdmission.admittingTicketCount,
            cancelledBeforeEnqueueTicketCount: snapshot.cancellationAdmission.cancelledBeforeEnqueueTicketCount,
            lateRetiredCancellationIgnored: snapshot.cancellationAdmission.lateRetiredCancellationIgnored,
            cancellationCounterOverflowed: snapshot.cancellationAdmission.counterOverflowed,
            admissionInvariantHolds: snapshot.cancellationAdmission.invariantHolds
        )
    }

    private static func map(_ outcome: Lane3UnifiedTransportOutcome) -> Lane3CancellationRaceProbeOutcome {
        switch outcome {
        case .executed(let receipt):
            return .executed(
                callerCancellationObservedAfterDispatch: receipt.callerCancellationObservedAfterDispatch
            )
        case .supersededBeforeToken:
            return .supersededBeforeToken
        case .cancelledBeforeDispatch:
            return .cancelledBeforeDispatch
        case .rejectedBeforeToken:
            return .rejectedBeforeToken
        case .failedAfterDispatch(let receipt):
            return .failedAfterDispatch(
                callerCancellationObservedAfterDispatch: receipt.callerCancellationObservedAfterDispatch
            )
        }
    }

    private static func offset(base: Double, step: Double, index: Int) -> Double? {
        guard index >= 0 else { return nil }
        let delta = step * Double(index)
        guard delta.isFinite else { return nil }
        return add(base, delta)
    }

    private static func add(_ lhs: Double, _ rhs: Double) -> Double? {
        let value = lhs + rhs
        return value.isFinite && value >= 0 ? value : nil
    }
}
