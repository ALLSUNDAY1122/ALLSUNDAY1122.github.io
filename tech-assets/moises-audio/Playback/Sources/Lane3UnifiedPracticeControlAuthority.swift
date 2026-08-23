import Foundation

public enum Lane3PitchControlRejectionReason: String, Codable, Sendable {
    case invalidPitchSemitones
    case interruptionOrLifecycleBlocked
    case transportRecoveryBlocked
    case coordinatorPoisoned
    case coordinatorBusyOutsideSelectedRoute
    case lifecycleChangedDuringMutation
    case coordinatorChangedDuringMutation
    case clickGenerationChangedDuringPitch
    case pitchReadbackMismatch
    case backendRequiresRecovery
    case ticketOverflow
}

public struct Lane3PitchControlExecutionReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let requestedSemitones: Double
    public let committedSemitones: Double
    public let clickGenerationPreserved: Bool
    public let lifecycleRevisionPreserved: Bool
    public let coordinatorOperationSerialPreserved: Bool
    public let callerCancellationObservedAfterDispatch: Bool
    public let parityPromotionAllowed: Bool

    public init(
        ticket: UInt64,
        requestedSemitones: Double,
        committedSemitones: Double,
        clickGenerationPreserved: Bool,
        lifecycleRevisionPreserved: Bool,
        coordinatorOperationSerialPreserved: Bool,
        callerCancellationObservedAfterDispatch: Bool,
        parityPromotionAllowed: Bool = false
    ) {
        self.ticket = ticket
        self.requestedSemitones = requestedSemitones
        self.committedSemitones = committedSemitones
        self.clickGenerationPreserved = clickGenerationPreserved
        self.lifecycleRevisionPreserved = lifecycleRevisionPreserved
        self.coordinatorOperationSerialPreserved = coordinatorOperationSerialPreserved
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
        self.parityPromotionAllowed = parityPromotionAllowed
    }
}

public struct Lane3PitchControlFailureReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let requestedSemitones: Double
    public let reason: Lane3PitchControlRejectionReason?
    public let errorDescription: String
    public let automaticRecoveryAttempted: Bool
    public let automaticRecoverySucceeded: Bool
    public let callerCancellationObservedAfterDispatch: Bool
    public let parityPromotionAllowed: Bool

    public init(
        ticket: UInt64,
        requestedSemitones: Double,
        reason: Lane3PitchControlRejectionReason?,
        errorDescription: String,
        automaticRecoveryAttempted: Bool = false,
        automaticRecoverySucceeded: Bool = false,
        callerCancellationObservedAfterDispatch: Bool,
        parityPromotionAllowed: Bool = false
    ) {
        self.ticket = ticket
        self.requestedSemitones = requestedSemitones
        self.reason = reason
        self.errorDescription = errorDescription
        self.automaticRecoveryAttempted = automaticRecoveryAttempted
        self.automaticRecoverySucceeded = automaticRecoverySucceeded
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
        self.parityPromotionAllowed = parityPromotionAllowed
    }
}

public enum Lane3PitchControlOutcome: Equatable, Sendable {
    case executed(Lane3PitchControlExecutionReceipt)
    case supersededBeforeDispatch(ticket: UInt64, byTicket: UInt64)
    case cancelledBeforeDispatch(ticket: UInt64)
    case rejectedBeforeDispatch(ticket: UInt64, reason: Lane3PitchControlRejectionReason)
    case failedAfterDispatch(Lane3PitchControlFailureReceipt)
}

public struct Lane3UnifiedPracticeControlSnapshot: Equatable, Sendable {
    public let pitchBarrierClosed: Bool
    public let interruptionBlocksPitch: Bool
    public let sharedOperationsInFlight: Int
    public let pendingPitchTicket: UInt64?
    public let executingPitchTicket: UInt64?
    public let nextPitchTicket: UInt64

    public init(
        pitchBarrierClosed: Bool,
        interruptionBlocksPitch: Bool,
        sharedOperationsInFlight: Int,
        pendingPitchTicket: UInt64?,
        executingPitchTicket: UInt64?,
        nextPitchTicket: UInt64
    ) {
        self.pitchBarrierClosed = pitchBarrierClosed
        self.interruptionBlocksPitch = interruptionBlocksPitch
        self.sharedOperationsInFlight = sharedOperationsInFlight
        self.pendingPitchTicket = pendingPitchTicket
        self.executingPitchTicket = executingPitchTicket
        self.nextPitchTicket = nextPitchTicket
    }
}

/// AW23 selected product-facing Lane-3 practice authority.
///
/// Pitch/key does not move transport or click time, so it deliberately consumes no Playback or click
/// generation. It nevertheless must be serialized against coordinator-backed tempo/click/transport
/// work: a direct controller pitch call can otherwise apply a candidate built from stale tempo state
/// and overwrite a newer transaction. This actor provides an exclusive pitch barrier while leaving
/// normal AW16 continuous-control concurrency/coalescing intact whenever no pitch is executing.
///
/// Selected integration must route ALL Lane-3 product transport/practice controls through this object.
/// Direct App calls to `PracticeDSPProductionController.setPitchSemitones` are a bypass.
public actor Lane3UnifiedPracticeControlAuthority {
    private struct PendingPitch {
        let ticket: UInt64
        let semitones: Double
        let continuation: CheckedContinuation<Lane3PitchControlOutcome, Never>
    }

    private let projectID: ProjectID
    private let transport: Lane3InstrumentedInterruptionGate
    private let practice: Lane3SerializedPracticeClickGate
    private let controller: PracticeDSPProductionController
    private let coordinator: PracticeDSPGenerationCoordinator
    private let telemetryProbe: Lane3DSPRuntimeTelemetryProbe?
    private let pitchRange: ClosedRange<Double>

    private var nextPitchTicket: UInt64 = 0
    private var pendingPitch: PendingPitch?
    private var pitchDrainRunning = false
    private var pitchBarrierClosed = false
    private var interruptionBlocksPitch = false
    private var executingPitchTicket: UInt64?
    private var backendDispatchStarted = false
    private var cancellationBeforeDispatch: Set<UInt64> = []
    private var cancellationAfterDispatch: Set<UInt64> = []

    private var sharedOperationsInFlight = 0
    private var sharedAdmissionWaiters: [CheckedContinuation<Void, Never>] = []
    private var sharedQuiescenceWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        projectID: ProjectID,
        transport: Lane3InstrumentedInterruptionGate,
        practice: Lane3SerializedPracticeClickGate,
        controller: PracticeDSPProductionController,
        coordinator: PracticeDSPGenerationCoordinator,
        telemetryProbe: Lane3DSPRuntimeTelemetryProbe? = nil,
        pitchRange: ClosedRange<Double> = PracticeDSPCapabilities.appleTimePitchBaseline.pitchSemitoneRange
    ) {
        self.projectID = projectID
        self.transport = transport
        self.practice = practice
        self.controller = controller
        self.coordinator = coordinator
        self.telemetryProbe = telemetryProbe
        self.pitchRange = pitchRange
    }

    public func submitPitchSemitones(_ semitones: Double) async -> Lane3PitchControlOutcome {
        guard let ticket = allocatePitchTicket() else {
            return .rejectedBeforeDispatch(ticket: UInt64.max, reason: .ticketOverflow)
        }
        guard semitones.isFinite, pitchRange.contains(semitones) else {
            return .rejectedBeforeDispatch(ticket: ticket, reason: .invalidPitchSemitones)
        }
        guard !interruptionBlocksPitch else {
            return .rejectedBeforeDispatch(ticket: ticket, reason: .interruptionOrLifecycleBlocked)
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                enqueuePitch(PendingPitch(
                    ticket: ticket,
                    semitones: semitones,
                    continuation: continuation
                ))
            }
        } onCancel: {
            Task { await self.cancelPitch(ticket: ticket) }
        }
    }

    // MARK: Selected transport route

    public func submitSeek(to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome {
        await withShared { await transport.submitSeek(to: positionSeconds, resume: resume, loop: loop) }
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome {
        await withShared { await transport.submitLoop(loop) }
    }

    public func submitTempoRatio(_ ratio: Double) async -> Lane3InterruptionGuardedOutcome {
        await withShared {
            if let telemetryProbe {
                return await telemetryProbe.measureAsync(kind: .tempo) {
                    await transport.submitTempoRatio(ratio)
                }
            }
            return await transport.submitTempoRatio(ratio)
        }
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async -> Lane3InterruptionGuardedOutcome {
        await withShared { await transport.submitMediaLoad(asset) }
    }

    public func submitMediaReplacement(
        stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?
    ) async -> Lane3InterruptionGuardedOutcome {
        await withShared {
            await transport.submitMediaReplacement(
                stems: stems, positionSeconds: positionSeconds, resume: resume, loop: loop
            )
        }
    }

    public func submitPlay() async -> Lane3InterruptionGuardedOutcome {
        await withShared { await transport.submitPlay() }
    }

    public func submitPause() async -> Lane3InterruptionGuardedOutcome {
        await withShared { await transport.submitPause() }
    }

    public func submitRecovery() async -> Lane3InterruptionGuardedOutcome {
        await withShared {
            if let telemetryProbe {
                return await telemetryProbe.measureAsync(kind: .recovery) {
                    await transport.submitRecovery()
                }
            }
            return await transport.submitRecovery()
        }
    }

    // MARK: Selected click/practice route

    @discardableResult
    public func setMetronomeEnabled(_ enabled: Bool) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        try await withSharedThrowing {
            if let telemetryProbe {
                return try await telemetryProbe.measureAsync(kind: .metronomeMutation) {
                    try await practice.setMetronomeEnabled(enabled)
                }
            }
            return try await practice.setMetronomeEnabled(enabled)
        }
    }

    @discardableResult
    public func scheduleCountIn(clicks: Int) async throws -> Lane3CountInArmAuthorization {
        try await withSharedThrowing {
            if let telemetryProbe {
                return try await telemetryProbe.measureAsync(kind: .countInArm) {
                    try await practice.scheduleCountIn(clicks: clicks)
                }
            }
            return try await practice.scheduleCountIn(clicks: clicks)
        }
    }

    public func makeCountInPlan(
        authorization: Lane3CountInArmAuthorization,
        sourceBeatIntervalSeconds: Double,
        musicStartSampleTime: Int64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) async throws -> DSPCountInPlan {
        try await withSharedThrowing {
            try await practice.makeCountInPlan(
                authorization: authorization,
                sourceBeatIntervalSeconds: sourceBeatIntervalSeconds,
                musicStartSampleTime: musicStartSampleTime,
                renderOriginSampleTime: renderOriginSampleTime,
                sampleRate: sampleRate,
                downbeatStride: downbeatStride
            )
        }
    }

    @discardableResult
    public func markCountInScheduleCommitted(
        authorization: Lane3CountInArmAuthorization
    ) async throws -> PracticeDSPSerializedCountInReceipt {
        try await withSharedThrowing {
            if let telemetryProbe {
                return try await telemetryProbe.measureAsync(kind: .countInConsume) {
                    try await practice.markCountInScheduleCommitted(authorization: authorization)
                }
            }
            return try await practice.markCountInScheduleCommitted(authorization: authorization)
        }
    }

    public func makeMetronomeRestorePlan(
        authorization: Lane3MetronomeRestoreAuthorization,
        beatTimesSeconds: [Double],
        sourceStartSeconds: Double,
        sourceEndSeconds: Double?,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) async throws -> PracticeDSPMetronomeExecutionPlan {
        try await withSharedThrowing {
            try await practice.makeMetronomeRestorePlan(
                authorization: authorization,
                beatTimesSeconds: beatTimesSeconds,
                sourceStartSeconds: sourceStartSeconds,
                sourceEndSeconds: sourceEndSeconds,
                renderOriginSampleTime: renderOriginSampleTime,
                sampleRate: sampleRate,
                downbeatStride: downbeatStride
            )
        }
    }

    // MARK: Interruption lifecycle route

    public func submitInterruptionBegan() async -> Lane3SerializedInterruptionBeginEnvelope {
        // Close pitch admission before the first await. A pending pitch has not touched the backend
        // and is rejected; a backend-dispatched pitch is allowed to complete before the boundary.
        interruptionBlocksPitch = true
        if let pendingPitch {
            self.pendingPitch = nil
            pendingPitch.continuation.resume(returning: .rejectedBeforeDispatch(
                ticket: pendingPitch.ticket,
                reason: .interruptionOrLifecycleBlocked
            ))
        }
        return await withShared { await practice.submitInterruptionBegan() }
    }

    public func submitInterruptionEnded(shouldResume: Bool) async -> Lane3PracticeInterruptionEndEnvelope {
        let result = await withShared {
            await practice.submitInterruptionEnded(shouldResume: shouldResume)
        }
        await reopenPitchIfLifecycleIdle()
        return result
    }

    public func retryEndedInterruptionRecovery() async -> Lane3PracticeInterruptionEndEnvelope {
        let result = await withShared { await practice.retryEndedInterruptionRecovery() }
        await reopenPitchIfLifecycleIdle()
        return result
    }

    public func snapshot() -> Lane3UnifiedPracticeControlSnapshot {
        Lane3UnifiedPracticeControlSnapshot(
            pitchBarrierClosed: pitchBarrierClosed,
            interruptionBlocksPitch: interruptionBlocksPitch,
            sharedOperationsInFlight: sharedOperationsInFlight,
            pendingPitchTicket: pendingPitch?.ticket,
            executingPitchTicket: executingPitchTicket,
            nextPitchTicket: nextPitchTicket
        )
    }

    // MARK: Pitch latest-wins queue

    private func allocatePitchTicket() -> UInt64? {
        let (next, overflow) = nextPitchTicket.addingReportingOverflow(1)
        guard !overflow else { return nil }
        nextPitchTicket = next
        return next
    }

    private func enqueuePitch(_ command: PendingPitch) {
        if interruptionBlocksPitch {
            command.continuation.resume(returning: .rejectedBeforeDispatch(
                ticket: command.ticket, reason: .interruptionOrLifecycleBlocked
            ))
            return
        }
        if let previous = pendingPitch {
            previous.continuation.resume(returning: .supersededBeforeDispatch(
                ticket: previous.ticket, byTicket: command.ticket
            ))
        }
        pendingPitch = command
        if !pitchDrainRunning {
            pitchDrainRunning = true
            Task { await self.drainPitchQueue() }
        }
    }

    private func cancelPitch(ticket: UInt64) {
        if let pendingPitch, pendingPitch.ticket == ticket {
            self.pendingPitch = nil
            pendingPitch.continuation.resume(returning: .cancelledBeforeDispatch(ticket: ticket))
            return
        }
        guard executingPitchTicket == ticket else { return }
        if backendDispatchStarted {
            cancellationAfterDispatch.insert(ticket)
        } else {
            cancellationBeforeDispatch.insert(ticket)
        }
    }

    private func drainPitchQueue() async {
        while let command = pendingPitch {
            pendingPitch = nil
            executingPitchTicket = command.ticket
            backendDispatchStarted = false
            pitchBarrierClosed = true
            await waitForSharedQuiescence()

            if cancellationBeforeDispatch.remove(command.ticket) != nil {
                finishPitchBarrier()
                command.continuation.resume(returning: .cancelledBeforeDispatch(ticket: command.ticket))
                continue
            }
            if interruptionBlocksPitch {
                finishPitchBarrier()
                command.continuation.resume(returning: .rejectedBeforeDispatch(
                    ticket: command.ticket, reason: .interruptionOrLifecycleBlocked
                ))
                continue
            }

            backendDispatchStarted = true
            let outcome = await executePitch(command)
            finishPitchBarrier()
            command.continuation.resume(returning: outcome)
        }
        pitchDrainRunning = false
    }

    private func finishPitchBarrier() {
        executingPitchTicket = nil
        backendDispatchStarted = false
        pitchBarrierClosed = false
        resumeSharedAdmissionWaiters()
    }

    private func executePitch(_ command: PendingPitch) async -> Lane3PitchControlOutcome {
        let lifecycleBefore = await transport.snapshot()
        guard lifecycleBefore.phase == .idle else {
            return .rejectedBeforeDispatch(ticket: command.ticket, reason: .interruptionOrLifecycleBlocked)
        }
        guard !lifecycleBefore.authorityRecoveryBlocked else {
            return .rejectedBeforeDispatch(ticket: command.ticket, reason: .transportRecoveryBlocked)
        }

        let authorityBefore = await coordinator.authoritySnapshot()
        guard !authorityBefore.isPoisoned else {
            return .rejectedBeforeDispatch(ticket: command.ticket, reason: .coordinatorPoisoned)
        }
        guard !authorityBefore.operationInFlight else {
            return .rejectedBeforeDispatch(ticket: command.ticket, reason: .coordinatorBusyOutsideSelectedRoute)
        }

        let stateBefore: PracticeDSPGenerationCoordinatorSnapshot
        do {
            stateBefore = try await coordinator.snapshot()
        } catch {
            return .failedAfterDispatch(makeFailure(
                command, reason: nil, error: "preflight snapshot failed: \(error)", recovery: nil
            ))
        }

        do {
            if let telemetryProbe {
                try await telemetryProbe.measureAsync(kind: .pitch) {
                    try await controller.setPitchSemitones(command.semitones, projectID: projectID)
                }
            } else {
                try await controller.setPitchSemitones(command.semitones, projectID: projectID)
            }
        } catch {
            let needsRecovery = (try? await controller.requiresBackendResynchronization(projectID: projectID)) == true
            let recovery = needsRecovery ? await automaticRecovery() : nil
            return .failedAfterDispatch(makeFailure(
                command,
                reason: needsRecovery ? .backendRequiresRecovery : nil,
                error: String(describing: error),
                recovery: recovery
            ))
        }

        let authorityAfter = await coordinator.authoritySnapshot()
        let lifecycleAfter = await transport.snapshot()
        let stateAfter: PracticeDSPGenerationCoordinatorSnapshot
        do {
            stateAfter = try await coordinator.snapshot()
        } catch {
            return .failedAfterDispatch(makeFailure(
                command, reason: nil, error: "postflight snapshot failed: \(error)", recovery: nil
            ))
        }

        let structuralFailure: Lane3PitchControlRejectionReason?
        if lifecycleAfter.phase != .idle || lifecycleAfter.lifecycleRevision != lifecycleBefore.lifecycleRevision {
            structuralFailure = .lifecycleChangedDuringMutation
        } else if authorityAfter.operationSerial != authorityBefore.operationSerial
                    || authorityAfter.operationInFlight
                    || authorityAfter.isPoisoned
                    || authorityAfter.activeBinding != authorityBefore.activeBinding {
            structuralFailure = .coordinatorChangedDuringMutation
        } else if stateAfter.dspState.scheduleGeneration != stateBefore.dspState.scheduleGeneration {
            structuralFailure = .clickGenerationChangedDuringPitch
        } else if abs(stateAfter.dspState.pitchSemitones - command.semitones) > 0.000_001 {
            structuralFailure = .pitchReadbackMismatch
        } else {
            structuralFailure = nil
        }

        if let structuralFailure {
            let recovery = await automaticRecovery()
            return .failedAfterDispatch(makeFailure(
                command,
                reason: structuralFailure,
                error: structuralFailure.rawValue,
                recovery: recovery
            ))
        }

        return .executed(Lane3PitchControlExecutionReceipt(
            ticket: command.ticket,
            requestedSemitones: command.semitones,
            committedSemitones: stateAfter.dspState.pitchSemitones,
            clickGenerationPreserved: true,
            lifecycleRevisionPreserved: true,
            coordinatorOperationSerialPreserved: true,
            callerCancellationObservedAfterDispatch: cancellationAfterDispatch.remove(command.ticket) != nil
        ))
    }

    private func automaticRecovery() async -> Bool {
        let outcome: Lane3InterruptionGuardedOutcome
        if let telemetryProbe {
            outcome = await telemetryProbe.measureAsync(kind: .recovery) {
                await transport.submitRecovery()
            }
        } else {
            outcome = await transport.submitRecovery()
        }
        guard case let .transport(transportOutcome) = outcome else { return false }
        if case .executed = transportOutcome { return true }
        if case let .failedAfterDispatch(receipt) = transportOutcome {
            return receipt.automaticRecovery.succeeded
        }
        return false
    }

    private func makeFailure(
        _ command: PendingPitch,
        reason: Lane3PitchControlRejectionReason?,
        error: String,
        recovery: Bool?
    ) -> Lane3PitchControlFailureReceipt {
        Lane3PitchControlFailureReceipt(
            ticket: command.ticket,
            requestedSemitones: command.semitones,
            reason: reason,
            errorDescription: error,
            automaticRecoveryAttempted: recovery != nil,
            automaticRecoverySucceeded: recovery ?? false,
            callerCancellationObservedAfterDispatch: cancellationAfterDispatch.remove(command.ticket) != nil
        )
    }

    // MARK: Shared/exclusive barrier

    private func withShared<T>(_ operation: () async -> T) async -> T {
        await enterSharedOperation()
        defer { leaveSharedOperation() }
        return await operation()
    }

    private func withSharedThrowing<T>(_ operation: () async throws -> T) async throws -> T {
        await enterSharedOperation()
        defer { leaveSharedOperation() }
        return try await operation()
    }

    private func enterSharedOperation() async {
        while pitchBarrierClosed {
            await withCheckedContinuation { sharedAdmissionWaiters.append($0) }
        }
        sharedOperationsInFlight += 1
    }

    private func leaveSharedOperation() {
        precondition(sharedOperationsInFlight > 0)
        sharedOperationsInFlight -= 1
        if sharedOperationsInFlight == 0 {
            let waiters = sharedQuiescenceWaiters
            sharedQuiescenceWaiters.removeAll(keepingCapacity: true)
            for waiter in waiters { waiter.resume() }
        }
    }

    private func waitForSharedQuiescence() async {
        while sharedOperationsInFlight > 0 {
            await withCheckedContinuation { sharedQuiescenceWaiters.append($0) }
        }
    }

    private func resumeSharedAdmissionWaiters() {
        let waiters = sharedAdmissionWaiters
        sharedAdmissionWaiters.removeAll(keepingCapacity: true)
        for waiter in waiters { waiter.resume() }
    }

    private func reopenPitchIfLifecycleIdle() async {
        let lifecycle = await transport.snapshot()
        if lifecycle.phase == .idle, !lifecycle.authorityRecoveryBlocked {
            interruptionBlocksPitch = false
        }
    }
}
