import Foundation

public enum Lane3PracticeClickInterruptionError: Error, Equatable, Sendable {
    case lifecycleNotIdle(String)
    case lifecycleTransitionInFlight(String)
    case interruptionRacedCountInArm
    case countInNotAuthorized
    case countInAuthorizationStale
    case countInArmSerialOverflow
    case metronomeRestoreNotAuthorized
    case metronomeRestoreStale
    case coordinatorPoisoned
}

public struct Lane3CountInArmAuthorization: Equatable, Sendable {
    public let armSerial: UInt64
    public let lifecycleRevision: UInt64
    public let clickGenerationAtArm: UInt64
    public let clicks: Int

    public init(
        armSerial: UInt64,
        lifecycleRevision: UInt64,
        clickGenerationAtArm: UInt64,
        clicks: Int
    ) {
        self.armSerial = armSerial
        self.lifecycleRevision = lifecycleRevision
        self.clickGenerationAtArm = clickGenerationAtArm
        self.clicks = clicks
    }
}

public struct Lane3MetronomeRestoreAuthorization: Equatable, Sendable {
    public let episodeSerial: UInt64
    public let lifecycleRevision: UInt64
    public let clickGeneration: UInt64
    public let requiresFreshRenderOrigin: Bool
    public let requiresFreshCommonHostAnchor: Bool

    public init(
        episodeSerial: UInt64,
        lifecycleRevision: UInt64,
        clickGeneration: UInt64,
        requiresFreshRenderOrigin: Bool = true,
        requiresFreshCommonHostAnchor: Bool = true
    ) {
        self.episodeSerial = episodeSerial
        self.lifecycleRevision = lifecycleRevision
        self.clickGeneration = clickGeneration
        self.requiresFreshRenderOrigin = requiresFreshRenderOrigin
        self.requiresFreshCommonHostAnchor = requiresFreshCommonHostAnchor
    }
}

public struct Lane3PracticeInterruptionBeginEnvelope: Equatable, Sendable {
    public let transportResult: Lane3InterruptionBeginResult
    public let countInAuthorizationRevoked: Bool
    public let underlyingPendingCountInClicksAfterBoundary: Int?
    public let observedClickGenerationAfterBoundary: UInt64?

    public init(
        transportResult: Lane3InterruptionBeginResult,
        countInAuthorizationRevoked: Bool,
        underlyingPendingCountInClicksAfterBoundary: Int?,
        observedClickGenerationAfterBoundary: UInt64?
    ) {
        self.transportResult = transportResult
        self.countInAuthorizationRevoked = countInAuthorizationRevoked
        self.underlyingPendingCountInClicksAfterBoundary = underlyingPendingCountInClicksAfterBoundary
        self.observedClickGenerationAfterBoundary = observedClickGenerationAfterBoundary
    }
}

public struct Lane3PracticeInterruptionEndEnvelope: Equatable, Sendable {
    public let transportResult: Lane3InterruptionEndResult
    public let metronomeRestoreAuthorization: Lane3MetronomeRestoreAuthorization?
    public let countInAutoRestoreAllowed: Bool

    public init(
        transportResult: Lane3InterruptionEndResult,
        metronomeRestoreAuthorization: Lane3MetronomeRestoreAuthorization?,
        countInAutoRestoreAllowed: Bool
    ) {
        self.transportResult = transportResult
        self.metronomeRestoreAuthorization = metronomeRestoreAuthorization
        self.countInAutoRestoreAllowed = countInAutoRestoreAllowed
    }
}

public struct Lane3PracticeClickInterruptionSnapshot: Equatable, Sendable {
    public let lifecycle: Lane3InterruptionLifecycleSnapshot
    public let countInAuthorization: Lane3CountInArmAuthorization?
    public let underlyingPendingCountInClicks: Int?
    public let metronomeEnabled: Bool
    public let clickGeneration: UInt64
    public let coordinatorPoisoned: Bool

    public init(
        lifecycle: Lane3InterruptionLifecycleSnapshot,
        countInAuthorization: Lane3CountInArmAuthorization?,
        underlyingPendingCountInClicks: Int?,
        metronomeEnabled: Bool,
        clickGeneration: UInt64,
        coordinatorPoisoned: Bool
    ) {
        self.lifecycle = lifecycle
        self.countInAuthorization = countInAuthorization
        self.underlyingPendingCountInClicks = underlyingPendingCountInClicks
        self.metronomeEnabled = metronomeEnabled
        self.clickGeneration = clickGeneration
        self.coordinatorPoisoned = coordinatorPoisoned
    }
}

/// Product-side click lifecycle gate layered on AW18/AW19.
///
/// The underlying coordinator remains the only click-generation mutation authority. This gate adds
/// interruption semantics that the raw DSP state cannot express by itself:
/// - pre-interruption count-in is one-shot and is never auto-restored after an interruption;
/// - count-in planning requires a local authorization armed during the current idle lifecycle;
/// - metronome may remain logically enabled, but rescheduling after interruption requires a fresh
///   authorization tied to the exact AW18 lifecycle revision and current click generation;
/// - a newer interruption or any click-generation mutation makes an older restore authorization stale.
///
/// The controller's `pendingCountInClicks` can remain non-nil after interruption because the frozen
/// coordinator API has no serialized clear operation. That value is intentionally quarantined: the
/// selected product route MUST create count-in plans through this gate, never directly from the raw
/// PracticeDSP state. A later explicit `scheduleCountIn` overwrites the stale logical value and creates
/// a new current-lifecycle authorization.
public actor Lane3PracticeInterruptionClickGate {
    private let transport: Lane3InstrumentedInterruptionGate
    private let coordinator: PracticeDSPGenerationCoordinator

    private var nextCountInArmSerial: UInt64 = 0
    private var countInAuthorization: Lane3CountInArmAuthorization?

    public init(
        transport: Lane3InstrumentedInterruptionGate,
        coordinator: PracticeDSPGenerationCoordinator
    ) {
        self.transport = transport
        self.coordinator = coordinator
    }

    @discardableResult
    public func setMetronomeEnabled(
        _ enabled: Bool
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        let lifecycle = await transport.snapshot()
        switch lifecycle.phase {
        case .idle, .active:
            break
        case .beginning, .ending, .resuming:
            throw Lane3PracticeClickInterruptionError.lifecycleTransitionInFlight(lifecycle.phase.rawValue)
        case .endedRecoveryRequired, .poisoned:
            throw Lane3PracticeClickInterruptionError.lifecycleNotIdle(lifecycle.phase.rawValue)
        }
        return try await coordinator.setMetronomeEnabled(enabled)
    }

    @discardableResult
    public func scheduleCountIn(
        clicks: Int
    ) async throws -> Lane3CountInArmAuthorization {
        let lifecycleBefore = await transport.snapshot()
        guard lifecycleBefore.phase == .idle else {
            throw Lane3PracticeClickInterruptionError.lifecycleNotIdle(lifecycleBefore.phase.rawValue)
        }

        let receipt = try await coordinator.scheduleCountIn(clicks: clicks)
        let lifecycleAfter = await transport.snapshot()
        guard lifecycleAfter.phase == .idle,
              lifecycleAfter.lifecycleRevision == lifecycleBefore.lifecycleRevision else {
            countInAuthorization = nil
            throw Lane3PracticeClickInterruptionError.interruptionRacedCountInArm
        }

        let (next, overflow) = nextCountInArmSerial.addingReportingOverflow(1)
        guard !overflow else {
            countInAuthorization = nil
            throw Lane3PracticeClickInterruptionError.countInArmSerialOverflow
        }
        nextCountInArmSerial = next
        let authorization = Lane3CountInArmAuthorization(
            armSerial: next,
            lifecycleRevision: lifecycleAfter.lifecycleRevision,
            clickGenerationAtArm: receipt.clickGeneration,
            clicks: clicks
        )
        countInAuthorization = authorization
        return authorization
    }

    /// Invalidates the selected product route's one-shot count-in authorization before awaiting the
    /// transport boundary. This makes interruption fail closed even if the AW18 actor is suspended.
    public func submitInterruptionBegan() async -> Lane3PracticeInterruptionBeginEnvelope {
        let revoked = countInAuthorization != nil
        countInAuthorization = nil

        let result = await transport.submitInterruptionBegan()
        let coordinatorSnapshot = try? await coordinator.snapshot()
        return Lane3PracticeInterruptionBeginEnvelope(
            transportResult: result,
            countInAuthorizationRevoked: revoked,
            underlyingPendingCountInClicksAfterBoundary: coordinatorSnapshot?.dspState.pendingCountInClicks,
            observedClickGenerationAfterBoundary: coordinatorSnapshot?.dspState.scheduleGeneration
        )
    }

    public func submitInterruptionEnded(
        shouldResume: Bool
    ) async -> Lane3PracticeInterruptionEndEnvelope {
        let result = await transport.submitInterruptionEnded(shouldResume: shouldResume)
        let authorization = await metronomeRestoreAuthorization(for: result)
        return Lane3PracticeInterruptionEndEnvelope(
            transportResult: result,
            metronomeRestoreAuthorization: authorization,
            countInAutoRestoreAllowed: false
        )
    }

    public func retryEndedInterruptionRecovery() async -> Lane3PracticeInterruptionEndEnvelope {
        let result = await transport.retryEndedInterruptionRecovery()
        let authorization = await metronomeRestoreAuthorization(for: result)
        return Lane3PracticeInterruptionEndEnvelope(
            transportResult: result,
            metronomeRestoreAuthorization: authorization,
            countInAutoRestoreAllowed: false
        )
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
        let lifecycle = await transport.snapshot()
        guard lifecycle.phase == .idle,
              lifecycle.episodeSerial == authorization.episodeSerial,
              lifecycle.lifecycleRevision == authorization.lifecycleRevision else {
            throw Lane3PracticeClickInterruptionError.metronomeRestoreStale
        }

        let coordinatorSnapshot = try await coordinator.snapshot()
        guard !coordinatorSnapshot.isPoisoned else {
            throw Lane3PracticeClickInterruptionError.coordinatorPoisoned
        }
        let state = coordinatorSnapshot.dspState
        guard state.metronomeEnabled,
              state.scheduleGeneration == authorization.clickGeneration else {
            throw Lane3PracticeClickInterruptionError.metronomeRestoreStale
        }

        return try PracticeDSPClickExecutionPlanner.metronome(
            state: state,
            beatTimesSeconds: beatTimesSeconds,
            sourceStartSeconds: sourceStartSeconds,
            sourceEndSeconds: sourceEndSeconds,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            downbeatStride: downbeatStride
        )
    }

    public func makeCountInPlan(
        authorization: Lane3CountInArmAuthorization,
        sourceBeatIntervalSeconds: Double,
        musicStartSampleTime: Int64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) async throws -> DSPCountInPlan {
        guard let current = countInAuthorization else {
            throw Lane3PracticeClickInterruptionError.countInNotAuthorized
        }
        guard current == authorization else {
            throw Lane3PracticeClickInterruptionError.countInAuthorizationStale
        }

        let lifecycle = await transport.snapshot()
        guard lifecycle.phase == .idle,
              lifecycle.lifecycleRevision == authorization.lifecycleRevision else {
            countInAuthorization = nil
            throw Lane3PracticeClickInterruptionError.countInAuthorizationStale
        }

        let coordinatorSnapshot = try await coordinator.snapshot()
        guard !coordinatorSnapshot.isPoisoned else {
            throw Lane3PracticeClickInterruptionError.coordinatorPoisoned
        }
        let state = coordinatorSnapshot.dspState
        guard state.pendingCountInClicks == authorization.clicks,
              state.scheduleGeneration >= authorization.clickGenerationAtArm else {
            countInAuthorization = nil
            throw Lane3PracticeClickInterruptionError.countInAuthorizationStale
        }

        return try PracticeDSPClickExecutionPlanner.countIn(
            state: state,
            sourceBeatIntervalSeconds: sourceBeatIntervalSeconds,
            musicStartSampleTime: musicStartSampleTime,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            downbeatStride: downbeatStride
        )
    }

    /// Call only after the Apple click executor has accepted the count-in replacement schedule.
    /// Clearing the local authorization prevents the stale raw pendingCountIn state from scheduling
    /// the one-shot count-in twice through the selected product route.
    public func markCountInScheduleCommitted(
        authorization: Lane3CountInArmAuthorization
    ) throws {
        guard countInAuthorization == authorization else {
            throw Lane3PracticeClickInterruptionError.countInAuthorizationStale
        }
        countInAuthorization = nil
    }

    public func snapshot() async throws -> Lane3PracticeClickInterruptionSnapshot {
        let lifecycle = await transport.snapshot()
        let coordinatorSnapshot = try await coordinator.snapshot()
        return Lane3PracticeClickInterruptionSnapshot(
            lifecycle: lifecycle,
            countInAuthorization: countInAuthorization,
            underlyingPendingCountInClicks: coordinatorSnapshot.dspState.pendingCountInClicks,
            metronomeEnabled: coordinatorSnapshot.dspState.metronomeEnabled,
            clickGeneration: coordinatorSnapshot.dspState.scheduleGeneration,
            coordinatorPoisoned: coordinatorSnapshot.isPoisoned
        )
    }

    private func metronomeRestoreAuthorization(
        for result: Lane3InterruptionEndResult
    ) async -> Lane3MetronomeRestoreAuthorization? {
        guard case let .ended(receipt) = result,
              receipt.boundarySafe,
              !receipt.recoveryRequired,
              !receipt.supersededByNewerLifecycleEvent,
              receipt.resumedPlayback else {
            return nil
        }

        let lifecycle = await transport.snapshot()
        guard lifecycle.phase == .idle,
              lifecycle.episodeSerial == receipt.episodeSerial,
              lifecycle.lifecycleRevision == receipt.lifecycleRevision else {
            return nil
        }

        guard let coordinatorSnapshot = try? await coordinator.snapshot(),
              !coordinatorSnapshot.isPoisoned,
              coordinatorSnapshot.dspState.metronomeEnabled else {
            return nil
        }

        return Lane3MetronomeRestoreAuthorization(
            episodeSerial: receipt.episodeSerial,
            lifecycleRevision: receipt.lifecycleRevision,
            clickGeneration: coordinatorSnapshot.dspState.scheduleGeneration
        )
    }
}
