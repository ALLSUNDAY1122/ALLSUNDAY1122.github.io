import Foundation

public enum Lane3ProductionTokenRoute: String, Codable, Sendable {
    case transportBinding
    case tempoMutation
    case recovery
}

public enum Lane3ProductionTokenRouting {
    public static func route(for reason: PlaybackTransportDiscontinuityReason) -> Lane3ProductionTokenRoute {
        switch reason {
        case .tempoChange:
            return .tempoMutation
        case .recovery:
            return .recovery
        default:
            return .transportBinding
        }
    }
}

public enum Lane3IntentCoalescingFamily: String, Codable, Sendable, CaseIterable, Hashable {
    case seek
    case loop
    case tempo
}

public struct Lane3ContinuousDispatchPolicy: Equatable, Sendable {
    public let seekQuietPeriod: Duration
    public let loopQuietPeriod: Duration
    public let tempoQuietPeriod: Duration
    public let tempoRatioRange: ClosedRange<Double>

    public init(
        seekQuietPeriod: Duration = .milliseconds(16),
        loopQuietPeriod: Duration = .milliseconds(16),
        tempoQuietPeriod: Duration = .milliseconds(16),
        tempoRatioRange: ClosedRange<Double> = PracticeDSPCapabilities.appleTimePitchBaseline.tempoRatioRange
    ) {
        self.seekQuietPeriod = seekQuietPeriod
        self.loopQuietPeriod = loopQuietPeriod
        self.tempoQuietPeriod = tempoQuietPeriod
        self.tempoRatioRange = tempoRatioRange
    }

    fileprivate func quietPeriod(for family: Lane3IntentCoalescingFamily) -> Duration {
        switch family {
        case .seek: return seekQuietPeriod
        case .loop: return loopQuietPeriod
        case .tempo: return tempoQuietPeriod
        }
    }
}

public struct Lane3AutomaticRecoveryReceipt: Equatable, Sendable {
    public let attempted: Bool
    public let succeeded: Bool
    public let playbackGeneration: UInt64?
    public let clickGeneration: UInt64?
    public let errorDescription: String?

    public init(
        attempted: Bool,
        succeeded: Bool,
        playbackGeneration: UInt64?,
        clickGeneration: UInt64?,
        errorDescription: String?
    ) {
        self.attempted = attempted
        self.succeeded = succeeded
        self.playbackGeneration = playbackGeneration
        self.clickGeneration = clickGeneration
        self.errorDescription = errorDescription
    }

    public static let notAttempted = Lane3AutomaticRecoveryReceipt(
        attempted: false,
        succeeded: false,
        playbackGeneration: nil,
        clickGeneration: nil,
        errorDescription: nil
    )
}

public struct Lane3IntentExecutionReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let family: Lane3IntentCoalescingFamily
    public let coalescedPredecessorCount: Int
    public let playbackGeneration: UInt64
    public let coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt
    public let callerCancellationObservedAfterDispatch: Bool

    public init(
        ticket: UInt64,
        family: Lane3IntentCoalescingFamily,
        coalescedPredecessorCount: Int,
        playbackGeneration: UInt64,
        coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt,
        callerCancellationObservedAfterDispatch: Bool
    ) {
        self.ticket = ticket
        self.family = family
        self.coalescedPredecessorCount = coalescedPredecessorCount
        self.playbackGeneration = playbackGeneration
        self.coordinatorReceipt = coordinatorReceipt
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
    }
}

public struct Lane3IntentFailureReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let family: Lane3IntentCoalescingFamily
    public let playbackGeneration: UInt64?
    public let tokenReason: PlaybackTransportDiscontinuityReason?
    public let errorDescription: String
    public let automaticRecovery: Lane3AutomaticRecoveryReceipt
    public let callerCancellationObservedAfterDispatch: Bool
}

public enum Lane3IntentDispatchOutcome: Equatable, Sendable {
    case executed(Lane3IntentExecutionReceipt)
    case superseded(ticket: UInt64, byTicket: UInt64, family: Lane3IntentCoalescingFamily)
    case cancelledBeforeDispatch(ticket: UInt64, family: Lane3IntentCoalescingFamily)
    case rejectedBeforeToken(ticket: UInt64, family: Lane3IntentCoalescingFamily, reason: String)
    case failedAfterDispatch(Lane3IntentFailureReceipt)
}

/// Upstream continuous-control dispatcher. Seek/loop/tempo intents are coalesced before a Playback
/// reschedule token is created, so discarded UI events never advance the Playback generation and do
/// not force AW15 supersession poison/recovery. Actual token generation + coordinator mutation is
/// serialized here. Once token generation starts the operation is intentionally allowed to finish;
/// caller cancellation is recorded but does not cancel a half-issued generation.
public actor Lane3ProductionIntentDispatcher {
    private enum Command: Sendable {
        case seek(positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?)
        case loop(PlaybackLoopRange?)
        case tempo(Double)
    }

    private struct PendingIntent {
        let ticket: UInt64
        let family: Lane3IntentCoalescingFamily
        let command: Command
        let coalescedPredecessorCount: Int
        var ready: Bool
        let continuation: CheckedContinuation<Lane3IntentDispatchOutcome, Never>
    }

    private struct ExecutionCoreResult {
        let playbackToken: PlaybackTransportRescheduleToken?
        let coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt?
        let errorDescription: String?
        let automaticRecovery: Lane3AutomaticRecoveryReceipt
    }

    private let projectID: ProjectID
    private let playback: RescheduleFencedPlaybackBackend
    private let coordinator: PracticeDSPGenerationCoordinator
    private let policy: Lane3ContinuousDispatchPolicy

    private var nextTicket: UInt64 = 0
    private var pending: [Lane3IntentCoalescingFamily: PendingIntent] = [:]
    private var wakeTasks: [Lane3IntentCoalescingFamily: Task<Void, Never>] = [:]
    private var executionInFlight = false
    private var executingTicket: UInt64?
    private var cancellationAfterDispatch: Set<UInt64> = []
    private var cancellationBeforeEnqueue: Set<UInt64> = []
    private var recoveryBlocked = false

    public init(
        projectID: ProjectID,
        playback: RescheduleFencedPlaybackBackend,
        coordinator: PracticeDSPGenerationCoordinator,
        policy: Lane3ContinuousDispatchPolicy = Lane3ContinuousDispatchPolicy()
    ) {
        self.projectID = projectID
        self.playback = playback
        self.coordinator = coordinator
        self.policy = policy
    }

    public func submitSeek(
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async -> Lane3IntentDispatchOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, family: .seek, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, family: .seek, reason: "dispatcherRecoveryBlocked")
        }
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            return .rejectedBeforeToken(ticket: ticket, family: .seek, reason: "invalidSeekPosition")
        }
        if let loop, !Self.valid(loop: loop) {
            return .rejectedBeforeToken(ticket: ticket, family: .seek, reason: "invalidLoop")
        }
        return await suspendAndEnqueue(
            ticket: ticket,
            family: .seek,
            command: .seek(positionSeconds: positionSeconds, resume: resume, loop: loop)
        )
    }

    public func submitLoop(
        _ loop: PlaybackLoopRange?
    ) async -> Lane3IntentDispatchOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, family: .loop, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, family: .loop, reason: "dispatcherRecoveryBlocked")
        }
        if let loop, !Self.valid(loop: loop) {
            return .rejectedBeforeToken(ticket: ticket, family: .loop, reason: "invalidLoop")
        }
        return await suspendAndEnqueue(ticket: ticket, family: .loop, command: .loop(loop))
    }

    public func submitTempoRatio(_ ratio: Double) async -> Lane3IntentDispatchOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, family: .tempo, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, family: .tempo, reason: "dispatcherRecoveryBlocked")
        }
        guard ratio.isFinite, policy.tempoRatioRange.contains(ratio) else {
            return .rejectedBeforeToken(ticket: ticket, family: .tempo, reason: "invalidTempoRatio")
        }
        return await suspendAndEnqueue(ticket: ticket, family: .tempo, command: .tempo(ratio))
    }

    /// Explicit retry after an automatic recovery failed. No continuous-control token is generated
    /// while the dispatcher is recovery-blocked.
    public func retryRecovery() async -> Lane3AutomaticRecoveryReceipt {
        guard !executionInFlight else {
            return Lane3AutomaticRecoveryReceipt(
                attempted: false,
                succeeded: false,
                playbackGeneration: nil,
                clickGeneration: nil,
                errorDescription: "executionInFlight"
            )
        }
        executionInFlight = true
        let recovery = await performAutomaticRecovery()
        executionInFlight = false
        recoveryBlocked = !recovery.succeeded
        if recovery.succeeded {
            await drainReady()
        }
        return recovery
    }

    public func pendingFamilies() -> [Lane3IntentCoalescingFamily] {
        pending.keys.sorted { $0.rawValue < $1.rawValue }
    }

    public func isRecoveryBlocked() -> Bool { recoveryBlocked }

    private func suspendAndEnqueue(
        ticket: UInt64,
        family: Lane3IntentCoalescingFamily,
        command: Command
    ) async -> Lane3IntentDispatchOutcome {
        if Task.isCancelled {
            return .cancelledBeforeDispatch(ticket: ticket, family: family)
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                enqueue(
                    ticket: ticket,
                    family: family,
                    command: command,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { await self.cancel(ticket: ticket, family: family) }
        }
    }

    private func enqueue(
        ticket: UInt64,
        family: Lane3IntentCoalescingFamily,
        command: Command,
        continuation: CheckedContinuation<Lane3IntentDispatchOutcome, Never>
    ) {
        if cancellationBeforeEnqueue.remove(ticket) != nil {
            continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket, family: family))
            return
        }
        if recoveryBlocked {
            continuation.resume(returning: .rejectedBeforeToken(
                ticket: ticket,
                family: family,
                reason: "dispatcherRecoveryBlocked"
            ))
            return
        }

        var predecessorCount = 0
        if let previous = pending[family] {
            predecessorCount = previous.coalescedPredecessorCount + 1
            wakeTasks[family]?.cancel()
            previous.continuation.resume(returning: .superseded(
                ticket: previous.ticket,
                byTicket: ticket,
                family: family
            ))
        }

        pending[family] = PendingIntent(
            ticket: ticket,
            family: family,
            command: command,
            coalescedPredecessorCount: predecessorCount,
            ready: false,
            continuation: continuation
        )
        let delay = policy.quietPeriod(for: family)
        wakeTasks[family] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.markReady(family: family, ticket: ticket)
        }
    }

    private func cancel(ticket: UInt64, family: Lane3IntentCoalescingFamily) {
        if let current = pending[family], current.ticket == ticket {
            pending[family] = nil
            wakeTasks[family]?.cancel()
            wakeTasks[family] = nil
            current.continuation.resume(returning: .cancelledBeforeDispatch(
                ticket: ticket,
                family: family
            ))
            return
        }
        if executingTicket == ticket {
            cancellationAfterDispatch.insert(ticket)
            return
        }
        cancellationBeforeEnqueue.insert(ticket)
    }

    private func markReady(family: Lane3IntentCoalescingFamily, ticket: UInt64) async {
        guard var current = pending[family], current.ticket == ticket else { return }
        current.ready = true
        pending[family] = current
        wakeTasks[family] = nil
        await drainReady()
    }

    private func drainReady() async {
        guard !executionInFlight, !recoveryBlocked else { return }

        while !executionInFlight,
              let candidate = pending.values
                .filter({ $0.ready })
                .min(by: { $0.ticket < $1.ticket }) {
            pending[candidate.family] = nil
            wakeTasks[candidate.family]?.cancel()
            wakeTasks[candidate.family] = nil
            executionInFlight = true
            executingTicket = candidate.ticket

            let core = await execute(candidate)
            let callerCancelled = cancellationAfterDispatch.remove(candidate.ticket) != nil
            let outcome = makeOutcome(candidate: candidate, core: core, callerCancelled: callerCancelled)

            executingTicket = nil
            executionInFlight = false
            candidate.continuation.resume(returning: outcome)

            if core.automaticRecovery.attempted && !core.automaticRecovery.succeeded {
                recoveryBlocked = true
                rejectAllPendingForRecoveryBlock()
                return
            }
        }
    }

    private func execute(_ intent: PendingIntent) async -> ExecutionCoreResult {
        switch intent.command {
        case let .seek(positionSeconds, resume, loop):
            return await executePlaybackMutation(family: .seek, expectedReason: .seek) {
                try await playback.seekAndReturnToken(
                    projectID: projectID,
                    to: positionSeconds,
                    resume: resume,
                    loop: loop
                )
            }
        case let .loop(loop):
            return await executePlaybackMutation(family: .loop, expectedReason: .loopChange) {
                try await playback.setLoopAndReturnToken(projectID: projectID, loop: loop)
            }
        case let .tempo(ratio):
            let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
            do {
                let token = try await playback.invalidateExternalDiscontinuity(
                    projectID: projectID,
                    reason: .tempoChange
                )
                do {
                    let receipt = try await coordinator.applyTempoRatio(ratio, playbackToken: token)
                    return ExecutionCoreResult(
                        playbackToken: token,
                        coordinatorReceipt: receipt,
                        errorDescription: nil,
                        automaticRecovery: .notAttempted
                    )
                } catch {
                    let recovery = await performAutomaticRecovery()
                    return ExecutionCoreResult(
                        playbackToken: token,
                        coordinatorReceipt: nil,
                        errorDescription: String(describing: error),
                        automaticRecovery: recovery
                    )
                }
            } catch {
                let after = await playback.rescheduleTokenSnapshot(projectID: projectID)
                let generated = Self.newToken(after: after, comparedWith: before, expectedReason: .tempoChange)
                let recovery = generated == nil ? .notAttempted : await performAutomaticRecovery()
                return ExecutionCoreResult(
                    playbackToken: generated,
                    coordinatorReceipt: nil,
                    errorDescription: String(describing: error),
                    automaticRecovery: recovery
                )
            }
        }
    }

    private func executePlaybackMutation(
        family: Lane3IntentCoalescingFamily,
        expectedReason: PlaybackTransportDiscontinuityReason,
        mutation: () async throws -> PlaybackTransportRescheduleToken
    ) async -> ExecutionCoreResult {
        let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
        do {
            let token = try await mutation()
            do {
                let route = Lane3ProductionTokenRouting.route(for: token.reason)
                guard route == .transportBinding else {
                    let recovery = await performAutomaticRecovery()
                    return ExecutionCoreResult(
                        playbackToken: token,
                        coordinatorReceipt: nil,
                        errorDescription: "unexpectedRoute:\(route.rawValue)",
                        automaticRecovery: recovery
                    )
                }
                let receipt = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: receipt,
                    errorDescription: nil,
                    automaticRecovery: .notAttempted
                )
            } catch {
                let recovery = await performAutomaticRecovery()
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: nil,
                    errorDescription: String(describing: error),
                    automaticRecovery: recovery
                )
            }
        } catch {
            let after = await playback.rescheduleTokenSnapshot(projectID: projectID)
            let generated = Self.newToken(after: after, comparedWith: before, expectedReason: expectedReason)
            let recovery = generated == nil ? .notAttempted : await performAutomaticRecovery()
            return ExecutionCoreResult(
                playbackToken: generated,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: recovery
            )
        }
    }

    private func performAutomaticRecovery() async -> Lane3AutomaticRecoveryReceipt {
        do {
            let token = try await playback.invalidateExternalDiscontinuity(
                projectID: projectID,
                reason: .recovery
            )
            do {
                let receipt = try await coordinator.recover(playbackToken: token)
                return Lane3AutomaticRecoveryReceipt(
                    attempted: true,
                    succeeded: true,
                    playbackGeneration: token.generation,
                    clickGeneration: receipt.clickGeneration,
                    errorDescription: nil
                )
            } catch {
                return Lane3AutomaticRecoveryReceipt(
                    attempted: true,
                    succeeded: false,
                    playbackGeneration: token.generation,
                    clickGeneration: nil,
                    errorDescription: String(describing: error)
                )
            }
        } catch {
            return Lane3AutomaticRecoveryReceipt(
                attempted: true,
                succeeded: false,
                playbackGeneration: nil,
                clickGeneration: nil,
                errorDescription: String(describing: error)
            )
        }
    }

    private func makeOutcome(
        candidate: PendingIntent,
        core: ExecutionCoreResult,
        callerCancelled: Bool
    ) -> Lane3IntentDispatchOutcome {
        if let token = core.playbackToken,
           let receipt = core.coordinatorReceipt,
           core.errorDescription == nil {
            return .executed(Lane3IntentExecutionReceipt(
                ticket: candidate.ticket,
                family: candidate.family,
                coalescedPredecessorCount: candidate.coalescedPredecessorCount,
                playbackGeneration: token.generation,
                coordinatorReceipt: receipt,
                callerCancellationObservedAfterDispatch: callerCancelled
            ))
        }
        return .failedAfterDispatch(Lane3IntentFailureReceipt(
            ticket: candidate.ticket,
            family: candidate.family,
            playbackGeneration: core.playbackToken?.generation,
            tokenReason: core.playbackToken?.reason,
            errorDescription: core.errorDescription ?? "unknownDispatchFailure",
            automaticRecovery: core.automaticRecovery,
            callerCancellationObservedAfterDispatch: callerCancelled
        ))
    }

    private func rejectAllPendingForRecoveryBlock() {
        let values = Array(pending.values)
        pending.removeAll()
        for family in Lane3IntentCoalescingFamily.allCases {
            wakeTasks[family]?.cancel()
            wakeTasks[family] = nil
        }
        for item in values {
            item.continuation.resume(returning: .rejectedBeforeToken(
                ticket: item.ticket,
                family: item.family,
                reason: "dispatcherRecoveryBlocked"
            ))
        }
    }

    private func allocateTicket() -> UInt64? {
        let (next, overflow) = nextTicket.addingReportingOverflow(1)
        guard !overflow else { return nil }
        nextTicket = next
        return next
    }

    private static func valid(loop: PlaybackLoopRange) -> Bool {
        loop.startSeconds.isFinite
            && loop.endSeconds.isFinite
            && loop.startSeconds >= 0
            && loop.endSeconds > loop.startSeconds
    }

    private static func newToken(
        after: PlaybackTransportRescheduleToken?,
        comparedWith before: PlaybackTransportRescheduleToken?,
        expectedReason: PlaybackTransportDiscontinuityReason
    ) -> PlaybackTransportRescheduleToken? {
        guard let after, after.reason == expectedReason else { return nil }
        if let before {
            guard after.generation > before.generation else { return nil }
        }
        return after
    }
}
