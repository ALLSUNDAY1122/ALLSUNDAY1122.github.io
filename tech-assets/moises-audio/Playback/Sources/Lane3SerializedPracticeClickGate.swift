import Foundation

public enum Lane3SerializedPracticeClickError: Error, Equatable, Sendable {
    case interruptionBoundaryInFlight
    case countInAuthorizationStale
    case countInConsumeFailedFailClosed
}

public struct Lane3SerializedInterruptionBeginEnvelope: Equatable, Sendable {
    public let practiceResult: Lane3PracticeInterruptionBeginEnvelope
    public let rawPendingCountInDiscarded: Bool
    public let discardRequiredRecovery: Bool
    public let discardReceipt: PracticeDSPSerializedCountInReceipt?

    public init(
        practiceResult: Lane3PracticeInterruptionBeginEnvelope,
        rawPendingCountInDiscarded: Bool,
        discardRequiredRecovery: Bool,
        discardReceipt: PracticeDSPSerializedCountInReceipt?
    ) {
        self.practiceResult = practiceResult
        self.rawPendingCountInDiscarded = rawPendingCountInDiscarded
        self.discardRequiredRecovery = discardRequiredRecovery
        self.discardReceipt = discardReceipt
    }
}

public struct Lane3SerializedPracticeClickSnapshot: Equatable, Sendable {
    public let practice: Lane3PracticeClickInterruptionSnapshot
    public let interruptionBoundaryInFlight: Bool

    public init(
        practice: Lane3PracticeClickInterruptionSnapshot,
        interruptionBoundaryInFlight: Bool
    ) {
        self.practice = practice
        self.interruptionBoundaryInFlight = interruptionBoundaryInFlight
    }
}

/// AW21 selected product route layered over the AW20 interruption gate.
///
/// The raw PracticeDSP pending count-in state is no longer used as a quarantine-only safety net:
/// - executor acceptance -> AW20 one-shot authorization revoke -> coordinator serialized consume;
/// - interruption begin -> coordinator serialized discard before the AW18 transport boundary;
/// - count-in planning is bound to the exact arm generation, not merely a newer-or-equal generation;
/// - a local boundary fence prevents a re-entrant count-in arm while interruption discard awaits.
///
/// Consume intentionally preserves the already accepted executor generation. Discard intentionally
/// advances/invalidate the generation because interruption must flush queued count-in clicks.
public actor Lane3SerializedPracticeClickGate {
    private let practiceGate: Lane3PracticeInterruptionClickGate
    private let coordinator: PracticeDSPGenerationCoordinator
    private var interruptionBoundaryInFlight = false

    public init(
        practiceGate: Lane3PracticeInterruptionClickGate,
        coordinator: PracticeDSPGenerationCoordinator
    ) {
        self.practiceGate = practiceGate
        self.coordinator = coordinator
    }

    @discardableResult
    public func setMetronomeEnabled(
        _ enabled: Bool
    ) async throws -> PracticeDSPGenerationCoordinatorReceipt {
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        return try await practiceGate.setMetronomeEnabled(enabled)
    }

    @discardableResult
    public func scheduleCountIn(
        clicks: Int
    ) async throws -> Lane3CountInArmAuthorization {
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        let authorization = try await practiceGate.scheduleCountIn(clicks: clicks)
        guard !interruptionBoundaryInFlight else {
            _ = try? await coordinator.discardCountIn(
                expectedClickGeneration: authorization.clickGenerationAtArm,
                expectedClicks: authorization.clicks
            )
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        return authorization
    }

    public func makeCountInPlan(
        authorization: Lane3CountInArmAuthorization,
        sourceBeatIntervalSeconds: Double,
        musicStartSampleTime: Int64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        downbeatStride: Int = 4
    ) async throws -> DSPCountInPlan {
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        try await validateExactCountInAuthorization(authorization)
        let plan = try await practiceGate.makeCountInPlan(
            authorization: authorization,
            sourceBeatIntervalSeconds: sourceBeatIntervalSeconds,
            musicStartSampleTime: musicStartSampleTime,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            downbeatStride: downbeatStride
        )
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        try await validateExactCountInAuthorization(authorization)
        return plan
    }

    /// Call only after AppleSampleAccurateClickExecutor has accepted the replacement count-in batch.
    /// The AW20 local one-shot authorization is revoked first so a failed consume cannot permit a
    /// second selected-route schedule. The coordinator then clears raw pending state without flushing
    /// the accepted batch. On a consume failure we attempt an exact-authority discard; it can never
    /// erase a newer arm because generation + click count must still match.
    @discardableResult
    public func markCountInScheduleCommitted(
        authorization: Lane3CountInArmAuthorization
    ) async throws -> PracticeDSPSerializedCountInReceipt {
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        try await validateExactCountInAuthorization(authorization)
        try await practiceGate.markCountInScheduleCommitted(authorization: authorization)
        do {
            return try await coordinator.consumeScheduledCountIn(
                expectedClickGeneration: authorization.clickGenerationAtArm,
                expectedClicks: authorization.clicks
            )
        } catch {
            _ = try? await coordinator.discardCountIn(
                expectedClickGeneration: authorization.clickGenerationAtArm,
                expectedClicks: authorization.clicks
            )
            throw error
        }
    }

    /// The boundary flag is set before the first await. Thus a re-entrant product count-in arm cannot
    /// appear between raw pending discard and the AW18 interruption transition. The transport boundary
    /// is still submitted even if discard reports a failure, so interruption handling is never skipped.
    public func submitInterruptionBegan() async -> Lane3SerializedInterruptionBeginEnvelope {
        interruptionBoundaryInFlight = true
        let discardReceipt: PracticeDSPSerializedCountInReceipt?
        var discardRequiredRecovery = false
        do {
            discardReceipt = try await coordinator.discardCurrentCountIn()
        } catch {
            discardReceipt = nil
            discardRequiredRecovery = true
        }

        let practiceResult = await practiceGate.submitInterruptionBegan()
        interruptionBoundaryInFlight = false
        return Lane3SerializedInterruptionBeginEnvelope(
            practiceResult: practiceResult,
            rawPendingCountInDiscarded: discardReceipt != nil,
            discardRequiredRecovery: discardRequiredRecovery,
            discardReceipt: discardReceipt
        )
    }

    public func submitInterruptionEnded(
        shouldResume: Bool
    ) async -> Lane3PracticeInterruptionEndEnvelope {
        await practiceGate.submitInterruptionEnded(shouldResume: shouldResume)
    }

    public func retryEndedInterruptionRecovery() async -> Lane3PracticeInterruptionEndEnvelope {
        await practiceGate.retryEndedInterruptionRecovery()
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
        guard !interruptionBoundaryInFlight else {
            throw Lane3SerializedPracticeClickError.interruptionBoundaryInFlight
        }
        return try await practiceGate.makeMetronomeRestorePlan(
            authorization: authorization,
            beatTimesSeconds: beatTimesSeconds,
            sourceStartSeconds: sourceStartSeconds,
            sourceEndSeconds: sourceEndSeconds,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            downbeatStride: downbeatStride
        )
    }

    public func snapshot() async throws -> Lane3SerializedPracticeClickSnapshot {
        Lane3SerializedPracticeClickSnapshot(
            practice: try await practiceGate.snapshot(),
            interruptionBoundaryInFlight: interruptionBoundaryInFlight
        )
    }

    private func validateExactCountInAuthorization(
        _ authorization: Lane3CountInArmAuthorization
    ) async throws {
        let snapshot = try await coordinator.snapshot()
        guard !snapshot.isPoisoned,
              snapshot.dspState.scheduleGeneration == authorization.clickGenerationAtArm,
              snapshot.dspState.pendingCountInClicks == authorization.clicks else {
            throw Lane3SerializedPracticeClickError.countInAuthorizationStale
        }
    }
}
