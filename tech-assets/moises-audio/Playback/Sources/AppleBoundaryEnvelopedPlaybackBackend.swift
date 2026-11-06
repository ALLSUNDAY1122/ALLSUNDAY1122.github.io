#if canImport(AVFAudio)
import AVFAudio
import Foundation

public enum AppleBoundaryEnvelopedPlaybackBackendError: Error, Equatable, Sendable {
    case envelopeGenerationOverflow
    case envelopePoisoned
}

/// AW32 discontinuity envelope decorator for the AW31 tempo-aware shared Apple graph, extended by
/// AW33 with explicit selected-stack poison reporting. The underlying AW31 backend remains the
/// source/transport clock authority. This decorator owns a single master gain stage after the shared
/// `AVAudioUnitTimePitch`, so a seek, loop mutation, tempo boundary or restart can cross silence
/// instead of cutting arbitrary non-zero PCM samples directly. The provisional fade durations are
/// engineering guardrails only: physical-device PCM/listening is still required before any click/pop
/// or PARITY claim.
public actor AppleBoundaryEnvelopedPlaybackBackend: PlaybackBackendDriving, PlaybackTempoBoundaryRescheduling, Lane3SelectedStackRecoveryReporting {
    private let backend: AppleTempoAwareRampedMultiTrackPlaybackBackend
    private let masterGainStage: AppleTransactionalStemGainRampStage
    private let policy: PlaybackBoundaryEnvelopePolicy
    private let sleeper: any PlaybackBoundaryEnvelopeSleeping
    private let startLeadSeconds: Double

    private var playing = false
    private var pendingTempoEnvelope: PlaybackBoundaryEnvelopePlan?
    private var restartFadeInTask: Task<Void, Never>?
    private var envelopeGeneration: UInt64 = 0
    private var envelopePoisoned = false

    private var fadeOutScheduled: UInt64 = 0
    private var restartFadeInArmed: UInt64 = 0
    private var restartFadeInApplied: UInt64 = 0
    private var staleOrCancelledEnvelopeTasksRejected: UInt64 = 0
    private var counterOverflowed = false

    public init(
        backend: AppleTempoAwareRampedMultiTrackPlaybackBackend,
        engine: AVAudioEngine,
        sharedTimePitchNode: AVAudioUnitTimePitch,
        policy: PlaybackBoundaryEnvelopePolicy = .provisionalAppleInteractive,
        sleeper: any PlaybackBoundaryEnvelopeSleeping = PlaybackBoundaryEnvelopeSystemSleeper(),
        startLeadSeconds: Double = 0.075
    ) throws {
        _ = try PlaybackBoundaryEnvelopePlanner.makePlan(
            sampleRate: 48_000,
            startLeadSeconds: startLeadSeconds,
            policy: policy
        )
        let masterMixer = AVAudioMixerNode()
        let masterGainStage = try AppleTransactionalStemGainRampStage(mixerNode: masterMixer)
        engine.disconnectNodeOutput(sharedTimePitchNode)
        engine.attach(masterMixer)
        engine.connect(sharedTimePitchNode, to: masterMixer, format: nil)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: nil)
        masterGainStage.setImmediateValidated(1)

        self.backend = backend
        self.masterGainStage = masterGainStage
        self.policy = policy
        self.sleeper = sleeper
        self.startLeadSeconds = startLeadSeconds
    }

    public func selectedStackRequiresReconstruction() async -> Bool {
        envelopePoisoned
    }

    public func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        try requireHealthy()
        try invalidateEnvelopeAuthority()
        restartFadeInTask?.cancel()
        restartFadeInTask = nil
        masterGainStage.setImmediateValidated(1)
        do {
            try await backend.loadSource(projectID: projectID, asset: asset)
        } catch {
            markPoisonIfRequired(error)
            throw error
        }
        playing = false
        pendingTempoEnvelope = nil
    }

    public func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireHealthy()
        try invalidateEnvelopeAuthority()
        restartFadeInTask?.cancel()
        restartFadeInTask = nil
        if resume {
            masterGainStage.setImmediateValidated(0)
        } else {
            masterGainStage.setImmediateValidated(1)
        }
        do {
            try await backend.loadStems(
                projectID: projectID,
                stems: stems,
                positionSeconds: positionSeconds,
                resume: resume,
                loop: loop
            )
        } catch {
            markPoisonIfRequired(error)
            masterGainStage.setImmediateValidated(envelopePoisoned ? 0 : 1)
            playing = false
            throw error
        }
        playing = resume
        pendingTempoEnvelope = nil
        if resume {
            let plan = try currentPlan()
            try armRestartFadeIn(plan: plan)
        }
    }

    public func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {
        try requireHealthy()
        do {
            try await backend.setEffectiveGains(projectID: projectID, gains: gains)
        } catch {
            markPoisonIfRequired(error)
            throw error
        }
    }

    public func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireHealthy()
        let plan = try await fadeOutForBoundaryIfNeeded()
        do {
            try await backend.seek(
                projectID: projectID,
                to: positionSeconds,
                resume: resume,
                loop: loop
            )
        } catch {
            markPoisonIfRequired(error)
            masterGainStage.setImmediateValidated(envelopePoisoned ? 0 : 1)
            playing = false
            throw error
        }
        playing = resume
        if resume {
            let restartPlan = try plan ?? currentPlan()
            try armRestartFadeIn(plan: restartPlan)
        } else {
            masterGainStage.setImmediateValidated(1)
        }
    }

    public func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        try requireHealthy()
        let wasPlaying = playing
        let plan = try await fadeOutForBoundaryIfNeeded()
        do {
            try await backend.setLoop(projectID: projectID, loop: loop)
        } catch {
            markPoisonIfRequired(error)
            masterGainStage.setImmediateValidated(envelopePoisoned ? 0 : 1)
            playing = false
            throw error
        }
        playing = wasPlaying
        if wasPlaying {
            let restartPlan = try plan ?? currentPlan()
            try armRestartFadeIn(plan: restartPlan)
        } else {
            masterGainStage.setImmediateValidated(1)
        }
    }

    public func play(projectID: ProjectID) async throws {
        try requireHealthy()
        if playing {
            do {
                try await backend.play(projectID: projectID)
            } catch {
                markPoisonIfRequired(error)
                throw error
            }
            return
        }
        try invalidateEnvelopeAuthority()
        restartFadeInTask?.cancel()
        restartFadeInTask = nil
        masterGainStage.setImmediateValidated(0)
        do {
            try await backend.play(projectID: projectID)
        } catch {
            markPoisonIfRequired(error)
            masterGainStage.setImmediateValidated(envelopePoisoned ? 0 : 1)
            playing = false
            throw error
        }
        playing = true
        try armRestartFadeIn(plan: currentPlan())
    }

    public func pause(projectID: ProjectID) async {
        if !envelopePoisoned, playing {
            _ = try? await fadeOutForBoundaryIfNeeded()
        } else {
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
        }
        await backend.pause(projectID: projectID)
        playing = false
        pendingTempoEnvelope = nil
        masterGainStage.setImmediateValidated(envelopePoisoned ? 0 : 1)
    }

    public func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        await backend.currentPositionSeconds(projectID: projectID)
    }

    public func prepareTempoBoundary(
        projectID: ProjectID,
        toTempoRatio: Double
    ) async throws -> PlaybackTempoBoundaryReceipt {
        try requireHealthy()
        let plan = try await fadeOutForBoundaryIfNeeded()
        do {
            let receipt = try await backend.prepareTempoBoundary(
                projectID: projectID,
                toTempoRatio: toTempoRatio
            )
            pendingTempoEnvelope = plan
            playing = false
            return receipt
        } catch {
            markPoisonIfRequired(error)
            pendingTempoEnvelope = nil
            if envelopePoisoned {
                masterGainStage.setImmediateValidated(0)
            } else if plan != nil {
                try? scheduleImmediateFadeIn(plan: plan ?? currentPlan())
            } else {
                masterGainStage.setImmediateValidated(1)
            }
            throw error
        }
    }

    public func commitTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        try requireHealthy()
        let plan = try pendingTempoEnvelope ?? currentPlan()
        do {
            try await backend.commitTempoBoundary(projectID: projectID, receipt: receipt)
        } catch {
            envelopePoisoned = true
            playing = false
            pendingTempoEnvelope = nil
            masterGainStage.setImmediateValidated(0)
            throw error
        }
        pendingTempoEnvelope = nil
        playing = receipt.resumeWasPlaying
        if receipt.resumeWasPlaying {
            try armRestartFadeIn(plan: plan)
        } else {
            masterGainStage.setImmediateValidated(1)
        }
    }

    public func cancelTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        try requireHealthy()
        let plan = try pendingTempoEnvelope ?? currentPlan()
        do {
            try await backend.cancelTempoBoundary(projectID: projectID, receipt: receipt)
        } catch {
            envelopePoisoned = true
            playing = false
            pendingTempoEnvelope = nil
            masterGainStage.setImmediateValidated(0)
            throw error
        }
        pendingTempoEnvelope = nil
        playing = receipt.resumeWasPlaying
        if receipt.resumeWasPlaying {
            try armRestartFadeIn(plan: plan)
        } else {
            masterGainStage.setImmediateValidated(1)
        }
    }

    public func boundaryEnvelopeRuntimeSnapshot() -> PlaybackBoundaryEnvelopeRuntimeSnapshot {
        PlaybackBoundaryEnvelopeRuntimeSnapshot(
            fadeOutScheduled: fadeOutScheduled,
            restartFadeInArmed: restartFadeInArmed,
            restartFadeInApplied: restartFadeInApplied,
            loopEnvelopeArmed: 0,
            loopFadeOutApplied: 0,
            loopFadeInApplied: 0,
            staleOrCancelledEnvelopeTasksRejected: staleOrCancelledEnvelopeTasksRejected,
            loopEnvelopeCapacityDrops: 0,
            loopEnvelopeUnsafeDurationDrops: 0,
            counterOverflowed: counterOverflowed,
            pendingLoopEnvelopeTasks: 0,
            restartFadeInPending: restartFadeInTask != nil
        )
    }

    private func fadeOutForBoundaryIfNeeded() async throws -> PlaybackBoundaryEnvelopePlan? {
        do {
            try invalidateEnvelopeAuthority()
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            guard playing else {
                masterGainStage.setImmediateValidated(1)
                return nil
            }
            let plan = try currentPlan()
            try masterGainStage.validateRamp(to: 0, frameCount: plan.fadeOutFrames)
            masterGainStage.scheduleValidatedRamp(to: 0, frameCount: plan.fadeOutFrames)
            increment(&fadeOutScheduled)
            await sleeper.sleep(seconds: plan.fadeOutSeconds)
            masterGainStage.setImmediateValidated(0)
            return plan
        } catch {
            envelopePoisoned = true
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            masterGainStage.setImmediateValidated(0)
            throw error
        }
    }

    private func armRestartFadeIn(plan: PlaybackBoundaryEnvelopePlan) throws {
        do {
            try requireHealthy()
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            try masterGainStage.validateImmediate(0)
            try masterGainStage.validateRamp(to: 1, frameCount: plan.fadeInFrames)
            masterGainStage.setImmediateValidated(0)
            let generation = envelopeGeneration
            increment(&restartFadeInArmed)
            restartFadeInTask = Task { [weak self] in
                await self?.sleepAndApplyRestartFadeIn(
                    expectedGeneration: generation,
                    plan: plan
                )
            }
        } catch {
            envelopePoisoned = true
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            masterGainStage.setImmediateValidated(0)
            throw error
        }
    }

    private func sleepAndApplyRestartFadeIn(
        expectedGeneration: UInt64,
        plan: PlaybackBoundaryEnvelopePlan
    ) async {
        await sleeper.sleep(seconds: plan.startLeadSeconds)
        guard !Task.isCancelled,
              !envelopePoisoned,
              playing,
              expectedGeneration == envelopeGeneration else {
            increment(&staleOrCancelledEnvelopeTasksRejected)
            if expectedGeneration == envelopeGeneration {
                restartFadeInTask = nil
            }
            return
        }
        masterGainStage.scheduleValidatedRamp(to: 1, frameCount: plan.fadeInFrames)
        increment(&restartFadeInApplied)
        restartFadeInTask = nil
    }

    private func scheduleImmediateFadeIn(plan: PlaybackBoundaryEnvelopePlan) throws {
        try masterGainStage.validateRamp(to: 1, frameCount: plan.fadeInFrames)
        masterGainStage.scheduleValidatedRamp(to: 1, frameCount: plan.fadeInFrames)
    }

    private func currentPlan() throws -> PlaybackBoundaryEnvelopePlan {
        try PlaybackBoundaryEnvelopePlanner.makePlan(
            sampleRate: masterGainStage.renderSampleRate,
            startLeadSeconds: startLeadSeconds,
            policy: policy
        )
    }

    private func invalidateEnvelopeAuthority() throws {
        let next = envelopeGeneration.addingReportingOverflow(1)
        guard !next.overflow else {
            counterOverflowed = true
            envelopePoisoned = true
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            masterGainStage.setImmediateValidated(0)
            throw AppleBoundaryEnvelopedPlaybackBackendError.envelopeGenerationOverflow
        }
        envelopeGeneration = next.partialValue
    }

    private func requireHealthy() throws {
        guard !envelopePoisoned else {
            throw AppleBoundaryEnvelopedPlaybackBackendError.envelopePoisoned
        }
    }

    private func markPoisonIfRequired(_ error: Error) {
        if Self.underlyingRequiresReconstruction(error) {
            envelopePoisoned = true
            restartFadeInTask?.cancel()
            restartFadeInTask = nil
            masterGainStage.setImmediateValidated(0)
        }
    }

    private static func underlyingRequiresReconstruction(_ error: Error) -> Bool {
        if let appleError = error as? AppleTempoAwarePlaybackBackendError,
           case .tempoBoundaryPoisoned = appleError {
            return true
        }
        if let boundaryError = error as? PlaybackTempoBoundaryError {
            switch boundaryError {
            case .transactionSerialOverflow, .scheduleGenerationOverflow:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func increment(_ value: inout UInt64) {
        let next = value.addingReportingOverflow(1)
        if next.overflow {
            value = UInt64.max
            counterOverflowed = true
        } else {
            value = next.partialValue
        }
    }
}
#endif
