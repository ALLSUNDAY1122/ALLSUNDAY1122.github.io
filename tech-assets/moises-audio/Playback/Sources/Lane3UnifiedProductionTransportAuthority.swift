import Foundation

public enum Lane3UnifiedTransportKind: String, Codable, Sendable, CaseIterable {
    case seek
    case loop
    case tempo
    case mediaLoad
    case mediaReplacement
    case play
    case pause
    case interruptionBegan
    case interruptionEnded
    case recovery
}

public enum Lane3UnifiedContinuousFamily: String, Codable, Sendable, CaseIterable, Hashable {
    case seek
    case loop
    case tempo
}

public enum Lane3DiscreteBarrierPolicy: String, Codable, Sendable {
    case flushOlderContinuous
    case supersedeOlderContinuous
}

public struct Lane3UnifiedTransportPolicy: Equatable, Sendable {
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

    fileprivate func quietPeriod(for family: Lane3UnifiedContinuousFamily) -> Duration {
        switch family {
        case .seek: return seekQuietPeriod
        case .loop: return loopQuietPeriod
        case .tempo: return tempoQuietPeriod
        }
    }
}

public struct Lane3UnifiedAutomaticRecoveryReceipt: Equatable, Sendable {
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

    public static let notAttempted = Lane3UnifiedAutomaticRecoveryReceipt(
        attempted: false,
        succeeded: false,
        playbackGeneration: nil,
        clickGeneration: nil,
        errorDescription: nil
    )
}

public struct Lane3UnifiedTransportExecutionReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let kind: Lane3UnifiedTransportKind
    public let coalescedPredecessorCount: Int
    public let playbackGeneration: UInt64
    public let coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt
    public let callerCancellationObservedAfterDispatch: Bool

    public init(
        ticket: UInt64,
        kind: Lane3UnifiedTransportKind,
        coalescedPredecessorCount: Int,
        playbackGeneration: UInt64,
        coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt,
        callerCancellationObservedAfterDispatch: Bool
    ) {
        self.ticket = ticket
        self.kind = kind
        self.coalescedPredecessorCount = coalescedPredecessorCount
        self.playbackGeneration = playbackGeneration
        self.coordinatorReceipt = coordinatorReceipt
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
    }
}

public struct Lane3UnifiedTransportFailureReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let kind: Lane3UnifiedTransportKind
    public let playbackGeneration: UInt64?
    public let tokenReason: PlaybackTransportDiscontinuityReason?
    public let errorDescription: String
    public let automaticRecovery: Lane3UnifiedAutomaticRecoveryReceipt
    public let callerCancellationObservedAfterDispatch: Bool
}

public enum Lane3UnifiedTransportOutcome: Equatable, Sendable {
    case executed(Lane3UnifiedTransportExecutionReceipt)
    case supersededBeforeToken(ticket: UInt64, byTicket: UInt64, kind: Lane3UnifiedTransportKind)
    case cancelledBeforeDispatch(ticket: UInt64, kind: Lane3UnifiedTransportKind)
    case rejectedBeforeToken(ticket: UInt64, kind: Lane3UnifiedTransportKind, reason: String)
    case failedAfterDispatch(Lane3UnifiedTransportFailureReceipt)
}

public struct Lane3UnifiedTransportAuthoritySnapshot: Equatable, Sendable {
    public let nextTicket: UInt64
    public let pendingContinuousKinds: [Lane3UnifiedTransportKind]
    public let pendingDiscreteKinds: [Lane3UnifiedTransportKind]
    public let executionInFlight: Bool
    public let executingTicket: UInt64?
    public let recoveryBlocked: Bool
}

/// Single product-side token authority for Lane 3.
/// Continuous seek/loop/tempo requests retain pre-token latest-wins coalescing. Discrete play/pause
/// form an ordering barrier that flushes older continuous controls, while media/interruption/recovery
/// boundaries supersede older pending controls before they can consume a Playback generation. Every
/// actual token-producing call is executed by this actor's one drain.
public actor Lane3UnifiedProductionTransportAuthority {
    private enum ContinuousCommand: Sendable {
        case seek(positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?)
        case loop(PlaybackLoopRange?)
        case tempo(Double)
    }

    private enum DiscreteCommand: Sendable {
        case mediaLoad(LocalAudioAsset)
        case mediaReplacement(stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?)
        case play
        case pause
        case interruptionBegan
        case interruptionEnded
        case recovery
    }

    private struct PendingContinuous {
        let ticket: UInt64
        let family: Lane3UnifiedContinuousFamily
        let kind: Lane3UnifiedTransportKind
        let command: ContinuousCommand
        let coalescedPredecessorCount: Int
        var ready: Bool
        let continuation: CheckedContinuation<Lane3UnifiedTransportOutcome, Never>
    }

    private struct PendingDiscrete {
        let ticket: UInt64
        let kind: Lane3UnifiedTransportKind
        let command: DiscreteCommand
        let continuation: CheckedContinuation<Lane3UnifiedTransportOutcome, Never>
    }

    private struct ExecutionCoreResult {
        let playbackToken: PlaybackTransportRescheduleToken?
        let coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt?
        let errorDescription: String?
        let automaticRecovery: Lane3UnifiedAutomaticRecoveryReceipt
    }

    private let projectID: ProjectID
    private let playback: RescheduleFencedPlaybackBackend
    private let coordinator: PracticeDSPGenerationCoordinator
    private let policy: Lane3UnifiedTransportPolicy

    private var nextTicket: UInt64 = 0
    private var continuous: [Lane3UnifiedContinuousFamily: PendingContinuous] = [:]
    private var wakeTasks: [Lane3UnifiedContinuousFamily: Task<Void, Never>] = [:]
    private var discrete: [PendingDiscrete] = []
    private var executionInFlight = false
    private var executingTicket: UInt64?
    private var cancellationAfterDispatch: Set<UInt64> = []
    private var cancellationBeforeEnqueue: Set<UInt64> = []
    private var recoveryBlocked = false

    public init(
        projectID: ProjectID,
        playback: RescheduleFencedPlaybackBackend,
        coordinator: PracticeDSPGenerationCoordinator,
        policy: Lane3UnifiedTransportPolicy = Lane3UnifiedTransportPolicy()
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
    ) async -> Lane3UnifiedTransportOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, kind: .seek, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, kind: .seek, reason: "authorityRecoveryBlocked")
        }
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            return .rejectedBeforeToken(ticket: ticket, kind: .seek, reason: "invalidSeekPosition")
        }
        if let loop, !Self.valid(loop: loop) {
            return .rejectedBeforeToken(ticket: ticket, kind: .seek, reason: "invalidLoop")
        }
        return await suspendContinuous(
            ticket: ticket,
            family: .seek,
            kind: .seek,
            command: .seek(positionSeconds: positionSeconds, resume: resume, loop: loop)
        )
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async -> Lane3UnifiedTransportOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, kind: .loop, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, kind: .loop, reason: "authorityRecoveryBlocked")
        }
        if let loop, !Self.valid(loop: loop) {
            return .rejectedBeforeToken(ticket: ticket, kind: .loop, reason: "invalidLoop")
        }
        return await suspendContinuous(ticket: ticket, family: .loop, kind: .loop, command: .loop(loop))
    }

    public func submitTempoRatio(_ ratio: Double) async -> Lane3UnifiedTransportOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, kind: .tempo, reason: "ticketOverflow")
        }
        if recoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, kind: .tempo, reason: "authorityRecoveryBlocked")
        }
        guard ratio.isFinite, policy.tempoRatioRange.contains(ratio) else {
            return .rejectedBeforeToken(ticket: ticket, kind: .tempo, reason: "invalidTempoRatio")
        }
        return await suspendContinuous(ticket: ticket, family: .tempo, kind: .tempo, command: .tempo(ratio))
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(kind: .mediaLoad, command: .mediaLoad(asset), barrier: .supersedeOlderContinuous)
    }

    public func submitMediaReplacement(
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async -> Lane3UnifiedTransportOutcome {
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            return rejectAllocated(kind: .mediaReplacement, reason: "invalidMediaPosition")
        }
        if let loop, !Self.valid(loop: loop) {
            return rejectAllocated(kind: .mediaReplacement, reason: "invalidLoop")
        }
        guard !stems.isEmpty else {
            return rejectAllocated(kind: .mediaReplacement, reason: "emptyStems")
        }
        return await submitDiscrete(
            kind: .mediaReplacement,
            command: .mediaReplacement(stems: stems, positionSeconds: positionSeconds, resume: resume, loop: loop),
            barrier: .supersedeOlderContinuous
        )
    }

    public func submitPlay() async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(kind: .play, command: .play, barrier: .flushOlderContinuous)
    }

    public func submitPause() async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(kind: .pause, command: .pause, barrier: .flushOlderContinuous)
    }

    public func submitInterruptionBegan() async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(kind: .interruptionBegan, command: .interruptionBegan, barrier: .supersedeOlderContinuous)
    }

    public func submitInterruptionEnded() async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(kind: .interruptionEnded, command: .interruptionEnded, barrier: .supersedeOlderContinuous)
    }

    public func submitRecovery() async -> Lane3UnifiedTransportOutcome {
        await submitDiscrete(
            kind: .recovery,
            command: .recovery,
            barrier: .supersedeOlderContinuous,
            allowWhileRecoveryBlocked: true
        )
    }

    public func snapshot() -> Lane3UnifiedTransportAuthoritySnapshot {
        Lane3UnifiedTransportAuthoritySnapshot(
            nextTicket: nextTicket,
            pendingContinuousKinds: continuous.values.map(\.kind).sorted { $0.rawValue < $1.rawValue },
            pendingDiscreteKinds: discrete.map(\.kind),
            executionInFlight: executionInFlight,
            executingTicket: executingTicket,
            recoveryBlocked: recoveryBlocked
        )
    }

    private func rejectAllocated(kind: Lane3UnifiedTransportKind, reason: String) -> Lane3UnifiedTransportOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, kind: kind, reason: "ticketOverflow")
        }
        return .rejectedBeforeToken(ticket: ticket, kind: kind, reason: reason)
    }

    private func suspendContinuous(
        ticket: UInt64,
        family: Lane3UnifiedContinuousFamily,
        kind: Lane3UnifiedTransportKind,
        command: ContinuousCommand
    ) async -> Lane3UnifiedTransportOutcome {
        if Task.isCancelled {
            return .cancelledBeforeDispatch(ticket: ticket, kind: kind)
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                enqueueContinuous(
                    ticket: ticket,
                    family: family,
                    kind: kind,
                    command: command,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { await self.cancel(ticket: ticket, kind: kind, family: family) }
        }
    }

    private func enqueueContinuous(
        ticket: UInt64,
        family: Lane3UnifiedContinuousFamily,
        kind: Lane3UnifiedTransportKind,
        command: ContinuousCommand,
        continuation: CheckedContinuation<Lane3UnifiedTransportOutcome, Never>
    ) {
        if cancellationBeforeEnqueue.remove(ticket) != nil {
            continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket, kind: kind))
            return
        }
        if recoveryBlocked {
            continuation.resume(returning: .rejectedBeforeToken(ticket: ticket, kind: kind, reason: "authorityRecoveryBlocked"))
            return
        }

        var predecessorCount = 0
        if let previous = continuous[family] {
            predecessorCount = previous.coalescedPredecessorCount + 1
            wakeTasks[family]?.cancel()
            previous.continuation.resume(returning: .supersededBeforeToken(
                ticket: previous.ticket,
                byTicket: ticket,
                kind: previous.kind
            ))
        }
        continuous[family] = PendingContinuous(
            ticket: ticket,
            family: family,
            kind: kind,
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

    private func submitDiscrete(
        kind: Lane3UnifiedTransportKind,
        command: DiscreteCommand,
        barrier: Lane3DiscreteBarrierPolicy,
        allowWhileRecoveryBlocked: Bool = false
    ) async -> Lane3UnifiedTransportOutcome {
        guard let ticket = allocateTicket() else {
            return .rejectedBeforeToken(ticket: UInt64.max, kind: kind, reason: "ticketOverflow")
        }
        if recoveryBlocked && !allowWhileRecoveryBlocked {
            return .rejectedBeforeToken(ticket: ticket, kind: kind, reason: "authorityRecoveryBlocked")
        }
        if Task.isCancelled {
            return .cancelledBeforeDispatch(ticket: ticket, kind: kind)
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                enqueueDiscrete(
                    ticket: ticket,
                    kind: kind,
                    command: command,
                    barrier: barrier,
                    allowWhileRecoveryBlocked: allowWhileRecoveryBlocked,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { await self.cancel(ticket: ticket, kind: kind, family: nil) }
        }
    }

    private func enqueueDiscrete(
        ticket: UInt64,
        kind: Lane3UnifiedTransportKind,
        command: DiscreteCommand,
        barrier: Lane3DiscreteBarrierPolicy,
        allowWhileRecoveryBlocked: Bool,
        continuation: CheckedContinuation<Lane3UnifiedTransportOutcome, Never>
    ) {
        if cancellationBeforeEnqueue.remove(ticket) != nil {
            continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket, kind: kind))
            return
        }
        if recoveryBlocked && !allowWhileRecoveryBlocked {
            continuation.resume(returning: .rejectedBeforeToken(ticket: ticket, kind: kind, reason: "authorityRecoveryBlocked"))
            return
        }

        applyBarrier(policy: barrier, discreteTicket: ticket)
        discrete.append(PendingDiscrete(ticket: ticket, kind: kind, command: command, continuation: continuation))
        discrete.sort { $0.ticket < $1.ticket }
        Task { await self.drainReady() }
    }

    private func applyBarrier(policy: Lane3DiscreteBarrierPolicy, discreteTicket: UInt64) {
        let older = continuous.values.filter { $0.ticket < discreteTicket }
        switch policy {
        case .flushOlderContinuous:
            for item in older {
                guard var current = continuous[item.family], current.ticket == item.ticket else { continue }
                current.ready = true
                continuous[item.family] = current
                wakeTasks[item.family]?.cancel()
                wakeTasks[item.family] = nil
            }
        case .supersedeOlderContinuous:
            for item in older {
                guard let current = continuous[item.family], current.ticket == item.ticket else { continue }
                continuous[item.family] = nil
                wakeTasks[item.family]?.cancel()
                wakeTasks[item.family] = nil
                current.continuation.resume(returning: .supersededBeforeToken(
                    ticket: current.ticket,
                    byTicket: discreteTicket,
                    kind: current.kind
                ))
            }
        }
    }

    private func cancel(
        ticket: UInt64,
        kind: Lane3UnifiedTransportKind,
        family: Lane3UnifiedContinuousFamily?
    ) {
        if let family, let current = continuous[family], current.ticket == ticket {
            continuous[family] = nil
            wakeTasks[family]?.cancel()
            wakeTasks[family] = nil
            current.continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket, kind: kind))
            return
        }
        if let index = discrete.firstIndex(where: { $0.ticket == ticket }) {
            let item = discrete.remove(at: index)
            item.continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket, kind: item.kind))
            return
        }
        if executingTicket == ticket {
            cancellationAfterDispatch.insert(ticket)
            return
        }
        cancellationBeforeEnqueue.insert(ticket)
    }

    private func markReady(family: Lane3UnifiedContinuousFamily, ticket: UInt64) async {
        guard var current = continuous[family], current.ticket == ticket else { return }
        current.ready = true
        continuous[family] = current
        wakeTasks[family] = nil
        await drainReady()
    }

    private func drainReady() async {
        guard !executionInFlight else { return }

        while !executionInFlight {
            let recoveryCandidate = recoveryBlocked ? discrete.first(where: { $0.kind == .recovery }) : nil
            if recoveryBlocked && recoveryCandidate == nil { return }

            let continuousCandidate = recoveryBlocked ? nil : continuous.values
                .filter(\.ready)
                .min(by: { $0.ticket < $1.ticket })
            let discreteCandidate = recoveryBlocked ? recoveryCandidate : discrete.first
            guard continuousCandidate != nil || discreteCandidate != nil else { return }

            if let continuousCandidate,
               discreteCandidate == nil || continuousCandidate.ticket < discreteCandidate!.ticket {
                continuous[continuousCandidate.family] = nil
                wakeTasks[continuousCandidate.family]?.cancel()
                wakeTasks[continuousCandidate.family] = nil
                executionInFlight = true
                executingTicket = continuousCandidate.ticket
                let core = await executeContinuous(continuousCandidate)
                let cancelled = cancellationAfterDispatch.remove(continuousCandidate.ticket) != nil
                let outcome = outcomeForContinuous(continuousCandidate, core: core, callerCancelled: cancelled)
                executingTicket = nil
                executionInFlight = false
                continuousCandidate.continuation.resume(returning: outcome)
                updateRecoveryBlock(after: core)
                if recoveryBlocked { rejectPendingExceptRecovery() }
            } else if let discreteCandidate {
                guard let index = discrete.firstIndex(where: { $0.ticket == discreteCandidate.ticket }) else { continue }
                let item = discrete.remove(at: index)
                executionInFlight = true
                executingTicket = item.ticket
                let core = await executeDiscrete(item)
                let cancelled = cancellationAfterDispatch.remove(item.ticket) != nil
                let outcome = outcomeForDiscrete(item, core: core, callerCancelled: cancelled)
                executingTicket = nil
                executionInFlight = false
                item.continuation.resume(returning: outcome)

                if item.kind == .recovery {
                    recoveryBlocked = core.coordinatorReceipt == nil || core.errorDescription != nil
                } else {
                    updateRecoveryBlock(after: core)
                }
                if recoveryBlocked { rejectPendingExceptRecovery() }
            }
        }
    }

    private func updateRecoveryBlock(after core: ExecutionCoreResult) {
        if core.automaticRecovery.attempted {
            recoveryBlocked = !core.automaticRecovery.succeeded
            return
        }
        if core.coordinatorReceipt == nil, core.errorDescription != nil {
            recoveryBlocked = true
        }
    }

    private func executeContinuous(_ item: PendingContinuous) async -> ExecutionCoreResult {
        switch item.command {
        case let .seek(positionSeconds, resume, loop):
            return await executeTransportMutation(expectedReason: .seek) {
                try await playback.seekAndReturnToken(
                    projectID: projectID,
                    to: positionSeconds,
                    resume: resume,
                    loop: loop
                )
            }
        case let .loop(loop):
            return await executeTransportMutation(expectedReason: .loopChange) {
                try await playback.setLoopAndReturnToken(projectID: projectID, loop: loop)
            }
        case let .tempo(ratio):
            return await executeTempo(ratio)
        }
    }

    private func executeDiscrete(_ item: PendingDiscrete) async -> ExecutionCoreResult {
        switch item.command {
        case let .mediaLoad(asset):
            return await executeTransportMutation(expectedReason: .mediaLoad) {
                try await playback.loadSourceAndReturnToken(projectID: projectID, asset: asset)
            }
        case let .mediaReplacement(stems, positionSeconds, resume, loop):
            return await executeTransportMutation(expectedReason: .mediaReplacement) {
                try await playback.loadStemsAndReturnToken(
                    projectID: projectID,
                    stems: stems,
                    positionSeconds: positionSeconds,
                    resume: resume,
                    loop: loop
                )
            }
        case .play:
            return await executeTransportMutation(expectedReason: .play) {
                try await playback.playAndReturnToken(projectID: projectID)
            }
        case .pause:
            let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
            let token = await playback.pauseAndReturnToken(projectID: projectID)
            guard let token else {
                return ExecutionCoreResult(
                    playbackToken: Self.newToken(
                        after: await playback.rescheduleTokenSnapshot(projectID: projectID),
                        comparedWith: before,
                        expectedReason: .pause
                    ),
                    coordinatorReceipt: nil,
                    errorDescription: "pauseTokenUnavailable",
                    automaticRecovery: .notAttempted
                )
            }
            return await bindTransportToken(token)
        case .interruptionBegan:
            return await executeExternalTransport(reason: .interruptionBegan)
        case .interruptionEnded:
            return await executeExternalTransport(reason: .interruptionEnded)
        case .recovery:
            return await executeRecovery()
        }
    }

    private func executeTempo(_ ratio: Double) async -> ExecutionCoreResult {
        let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
        do {
            let token = try await playback.invalidateExternalDiscontinuity(projectID: projectID, reason: .tempoChange)
            do {
                let receipt = try await coordinator.applyTempoRatio(ratio, playbackToken: token)
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: receipt,
                    errorDescription: nil,
                    automaticRecovery: .notAttempted
                )
            } catch {
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: nil,
                    errorDescription: String(describing: error),
                    automaticRecovery: await performAutomaticRecovery()
                )
            }
        } catch {
            let generated = Self.newToken(
                after: await playback.rescheduleTokenSnapshot(projectID: projectID),
                comparedWith: before,
                expectedReason: .tempoChange
            )
            return ExecutionCoreResult(
                playbackToken: generated,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: generated == nil ? .notAttempted : await performAutomaticRecovery()
            )
        }
    }

    private func executeExternalTransport(reason: PlaybackTransportDiscontinuityReason) async -> ExecutionCoreResult {
        let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
        do {
            let token = try await playback.invalidateExternalDiscontinuity(projectID: projectID, reason: reason)
            return await bindTransportToken(token)
        } catch {
            let generated = Self.newToken(
                after: await playback.rescheduleTokenSnapshot(projectID: projectID),
                comparedWith: before,
                expectedReason: reason
            )
            return ExecutionCoreResult(
                playbackToken: generated,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: generated == nil ? .notAttempted : await performAutomaticRecovery()
            )
        }
    }

    private func executeTransportMutation(
        expectedReason: PlaybackTransportDiscontinuityReason,
        mutation: () async throws -> PlaybackTransportRescheduleToken
    ) async -> ExecutionCoreResult {
        let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
        do {
            let token = try await mutation()
            return await bindTransportToken(token)
        } catch {
            let generated = Self.newToken(
                after: await playback.rescheduleTokenSnapshot(projectID: projectID),
                comparedWith: before,
                expectedReason: expectedReason
            )
            return ExecutionCoreResult(
                playbackToken: generated,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: generated == nil ? .notAttempted : await performAutomaticRecovery()
            )
        }
    }

    private func bindTransportToken(_ token: PlaybackTransportRescheduleToken) async -> ExecutionCoreResult {
        switch token.reason {
        case .tempoChange, .recovery:
            return ExecutionCoreResult(
                playbackToken: token,
                coordinatorReceipt: nil,
                errorDescription: "unexpectedTransportRoute:\(token.reason.rawValue)",
                automaticRecovery: await performAutomaticRecovery()
            )
        default:
            break
        }
        do {
            let receipt = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
            return ExecutionCoreResult(
                playbackToken: token,
                coordinatorReceipt: receipt,
                errorDescription: nil,
                automaticRecovery: .notAttempted
            )
        } catch {
            return ExecutionCoreResult(
                playbackToken: token,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: await performAutomaticRecovery()
            )
        }
    }

    private func executeRecovery() async -> ExecutionCoreResult {
        let before = await playback.rescheduleTokenSnapshot(projectID: projectID)
        do {
            let token = try await playback.invalidateExternalDiscontinuity(projectID: projectID, reason: .recovery)
            do {
                let receipt = try await coordinator.recover(playbackToken: token)
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: receipt,
                    errorDescription: nil,
                    automaticRecovery: .notAttempted
                )
            } catch {
                return ExecutionCoreResult(
                    playbackToken: token,
                    coordinatorReceipt: nil,
                    errorDescription: String(describing: error),
                    automaticRecovery: .notAttempted
                )
            }
        } catch {
            let generated = Self.newToken(
                after: await playback.rescheduleTokenSnapshot(projectID: projectID),
                comparedWith: before,
                expectedReason: .recovery
            )
            return ExecutionCoreResult(
                playbackToken: generated,
                coordinatorReceipt: nil,
                errorDescription: String(describing: error),
                automaticRecovery: .notAttempted
            )
        }
    }

    private func performAutomaticRecovery() async -> Lane3UnifiedAutomaticRecoveryReceipt {
        do {
            let token = try await playback.invalidateExternalDiscontinuity(projectID: projectID, reason: .recovery)
            do {
                let receipt = try await coordinator.recover(playbackToken: token)
                return Lane3UnifiedAutomaticRecoveryReceipt(
                    attempted: true,
                    succeeded: true,
                    playbackGeneration: token.generation,
                    clickGeneration: receipt.clickGeneration,
                    errorDescription: nil
                )
            } catch {
                return Lane3UnifiedAutomaticRecoveryReceipt(
                    attempted: true,
                    succeeded: false,
                    playbackGeneration: token.generation,
                    clickGeneration: nil,
                    errorDescription: String(describing: error)
                )
            }
        } catch {
            return Lane3UnifiedAutomaticRecoveryReceipt(
                attempted: true,
                succeeded: false,
                playbackGeneration: nil,
                clickGeneration: nil,
                errorDescription: String(describing: error)
            )
        }
    }

    private func outcomeForContinuous(
        _ item: PendingContinuous,
        core: ExecutionCoreResult,
        callerCancelled: Bool
    ) -> Lane3UnifiedTransportOutcome {
        makeOutcome(
            ticket: item.ticket,
            kind: item.kind,
            coalescedPredecessorCount: item.coalescedPredecessorCount,
            core: core,
            callerCancelled: callerCancelled
        )
    }

    private func outcomeForDiscrete(
        _ item: PendingDiscrete,
        core: ExecutionCoreResult,
        callerCancelled: Bool
    ) -> Lane3UnifiedTransportOutcome {
        makeOutcome(
            ticket: item.ticket,
            kind: item.kind,
            coalescedPredecessorCount: 0,
            core: core,
            callerCancelled: callerCancelled
        )
    }

    private func makeOutcome(
        ticket: UInt64,
        kind: Lane3UnifiedTransportKind,
        coalescedPredecessorCount: Int,
        core: ExecutionCoreResult,
        callerCancelled: Bool
    ) -> Lane3UnifiedTransportOutcome {
        if let token = core.playbackToken,
           let receipt = core.coordinatorReceipt,
           core.errorDescription == nil {
            return .executed(Lane3UnifiedTransportExecutionReceipt(
                ticket: ticket,
                kind: kind,
                coalescedPredecessorCount: coalescedPredecessorCount,
                playbackGeneration: token.generation,
                coordinatorReceipt: receipt,
                callerCancellationObservedAfterDispatch: callerCancelled
            ))
        }
        return .failedAfterDispatch(Lane3UnifiedTransportFailureReceipt(
            ticket: ticket,
            kind: kind,
            playbackGeneration: core.playbackToken?.generation,
            tokenReason: core.playbackToken?.reason,
            errorDescription: core.errorDescription ?? "unknownDispatchFailure",
            automaticRecovery: core.automaticRecovery,
            callerCancellationObservedAfterDispatch: callerCancelled
        ))
    }

    private func rejectPendingExceptRecovery() {
        let continuousValues = Array(continuous.values)
        continuous.removeAll()
        for family in Lane3UnifiedContinuousFamily.allCases {
            wakeTasks[family]?.cancel()
            wakeTasks[family] = nil
        }
        for item in continuousValues {
            item.continuation.resume(returning: .rejectedBeforeToken(
                ticket: item.ticket,
                kind: item.kind,
                reason: "authorityRecoveryBlocked"
            ))
        }

        let retainedRecovery = discrete.filter { $0.kind == .recovery }
        let rejected = discrete.filter { $0.kind != .recovery }
        discrete = retainedRecovery
        for item in rejected {
            item.continuation.resume(returning: .rejectedBeforeToken(
                ticket: item.ticket,
                kind: item.kind,
                reason: "authorityRecoveryBlocked"
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
