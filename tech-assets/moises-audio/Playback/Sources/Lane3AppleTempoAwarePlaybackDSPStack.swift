#if canImport(AVFAudio)
import AVFAudio
import Foundation

public struct Lane3AppleTempoAwareGraphReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sharedEngineGraph: Bool
    public let sharedTimePitchNode: Bool
    public let tempoAwareProjectClock: Bool
    public let tempoScaledLoopHostScheduling: Bool
    public let twoPhaseTempoBoundaryAvailable: Bool
    public let facadeOwnsTempoCoalescing: Bool
    public let upstreamTempoQuietPeriodDisabled: Bool
    public let rawPlaybackBackendExposed: Bool
    public let parityPromotionAllowed: Bool
}

public struct Lane3AppleBoundaryEnvelopeCompositionReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let masterGainAfterSharedTimePitch: Bool
    public let seekRestartEnvelopeAvailable: Bool
    public let loopMutationRestartEnvelopeAvailable: Bool
    public let tempoRestartEnvelopeAvailable: Bool
    public let playRestartEnvelopeAvailable: Bool
    public let boundaryMutedTempoUsesImmediateDSPApply: Bool
    public let automaticRepeatedLoopSeamEnvelopeAvailable: Bool
    public let staleFadeInGenerationGuarded: Bool
    public let audibleArtifactEliminationClaimed: Bool
    public let parityPromotionAllowed: Bool
}

public struct Lane3AppleSelectedStackRecoveryCompositionReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let oneWayFacadeRecoveryLatch: Bool
    public let selectedReplacementSlotAvailable: Bool
    public let replacementGenerationFenced: Bool
    public let staleRecoveryTicketRejected: Bool
    public let rawFacadeFactoryPubliclyExposed: Bool
    public let inPlacePoisonResetAvailable: Bool
    public let physicalDeviceRecoveryValidated: Bool
    public let parityPromotionAllowed: Bool
}

/// AW31 shared Apple graph with AW32's selected restart-envelope decorator and AW33's explicit
/// reconstruction contract. The underlying Playback backend remains private. HQ receives the fenced
/// Playback surface plus the exact AW29 DSP stack, then builds AW17/AW18/AW21 and wraps the selected
/// facade in `Lane3SelectedTransportReconstructionSlot`. A facade that latches AW33 recovery is never
/// reset in place; the whole selected composition is rebuilt and swapped by ticket/generation.
public struct Lane3AppleTempoAwarePlaybackDSPStack: @unchecked Sendable {
    public let playback: RescheduleFencedPlaybackBackend
    public let dsp: Lane3AppleDSPProductionStack
    public let compositionReceipt: Lane3AppleTempoAwareGraphReceipt
    public let boundaryEnvelopeCompositionReceipt: Lane3AppleBoundaryEnvelopeCompositionReceipt
    public let recoveryCompositionReceipt: Lane3AppleSelectedStackRecoveryCompositionReceipt
    private let tempoBackend: AppleBoundaryEnvelopedPlaybackBackend
    private let projectID: ProjectID
    private let tempoRatioRange: ClosedRange<Double>

    public static func make(
        projectID: ProjectID,
        appOwnedRoot: URL,
        collector: Lane3DSPRuntimeTelemetryCollector,
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        initialState: PracticeDSPState = PracticeDSPState(),
        gainRampPolicy: PlaybackGainRampPolicy = PlaybackGainRampPolicy(),
        tempoTransitionPolicy: PracticeDSPTempoTransitionPolicy = .boundaryMutedImmediate,
        tempoTransitionSleeper: any PracticeDSPTempoTransitionSleeping = PracticeDSPSystemTempoTransitionSleeper(),
        pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive,
        pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping = PracticeDSPSystemPitchTransitionSleeper(),
        telemetryTimeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource(),
        boundaryEnvelopePolicy: PlaybackBoundaryEnvelopePolicy = .provisionalAppleInteractive,
        boundaryEnvelopeSleeper: any PlaybackBoundaryEnvelopeSleeping = PlaybackBoundaryEnvelopeSystemSleeper(),
        startLeadSeconds: Double = 0.075
    ) throws -> Lane3AppleTempoAwarePlaybackDSPStack {
        let engine = AVAudioEngine()
        let node = AVAudioUnitTimePitch()
        node.rate = Float(initialState.tempoRatio)
        node.pitch = Float(PracticeDSPMath.cents(forSemitones: initialState.pitchSemitones))
        let dsp = try Lane3AppleDSPProductionStack.make(
            projectID: projectID,
            collector: collector,
            node: node,
            capabilities: capabilities,
            initialState: initialState,
            tempoTransitionPolicy: tempoTransitionPolicy,
            tempoTransitionSleeper: tempoTransitionSleeper,
            pitchTransitionPolicy: pitchTransitionPolicy,
            pitchTransitionSleeper: pitchTransitionSleeper,
            telemetryTimeSource: telemetryTimeSource
        )
        let rawPlayback = try AppleTempoAwareRampedMultiTrackPlaybackBackend(
            appOwnedRoot: appOwnedRoot,
            engine: engine,
            sharedTimePitchNode: node,
            gainRampPolicy: gainRampPolicy,
            tempoRatioRange: capabilities.tempoRatioRange,
            initialTempoRatio: initialState.tempoRatio,
            startLeadSeconds: startLeadSeconds
        )
        let envelopedPlayback = try AppleBoundaryEnvelopedPlaybackBackend(
            backend: rawPlayback,
            engine: engine,
            sharedTimePitchNode: node,
            policy: boundaryEnvelopePolicy,
            sleeper: boundaryEnvelopeSleeper,
            startLeadSeconds: startLeadSeconds
        )
        let playback = RescheduleFencedPlaybackBackend(backend: envelopedPlayback)
        let receipt = Lane3AppleTempoAwareGraphReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW31_APPLE_SHARED_PLAYBACK_DSP_GRAPH_NON_PARITY",
            sharedEngineGraph: true,
            sharedTimePitchNode: true,
            tempoAwareProjectClock: true,
            tempoScaledLoopHostScheduling: true,
            twoPhaseTempoBoundaryAvailable: true,
            facadeOwnsTempoCoalescing: true,
            upstreamTempoQuietPeriodDisabled: true,
            rawPlaybackBackendExposed: false,
            parityPromotionAllowed: false
        )
        let boundaryReceipt = Lane3AppleBoundaryEnvelopeCompositionReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW32_APPLE_RESTART_ENVELOPE_NON_PARITY",
            masterGainAfterSharedTimePitch: true,
            seekRestartEnvelopeAvailable: true,
            loopMutationRestartEnvelopeAvailable: true,
            tempoRestartEnvelopeAvailable: true,
            playRestartEnvelopeAvailable: true,
            boundaryMutedTempoUsesImmediateDSPApply: tempoTransitionPolicy == .boundaryMutedImmediate,
            automaticRepeatedLoopSeamEnvelopeAvailable: false,
            staleFadeInGenerationGuarded: true,
            audibleArtifactEliminationClaimed: false,
            parityPromotionAllowed: false
        )
        let recoveryReceipt = Lane3AppleSelectedStackRecoveryCompositionReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW33_APPLE_SELECTED_STACK_RECOVERY_NON_PARITY",
            oneWayFacadeRecoveryLatch: true,
            selectedReplacementSlotAvailable: true,
            replacementGenerationFenced: true,
            staleRecoveryTicketRejected: true,
            rawFacadeFactoryPubliclyExposed: false,
            inPlacePoisonResetAvailable: false,
            physicalDeviceRecoveryValidated: false,
            parityPromotionAllowed: false
        )
        return .init(
            playback: playback,
            dsp: dsp,
            compositionReceipt: receipt,
            boundaryEnvelopeCompositionReceipt: boundaryReceipt,
            recoveryCompositionReceipt: recoveryReceipt,
            tempoBackend: envelopedPlayback,
            projectID: projectID,
            tempoRatioRange: capabilities.tempoRatioRange
        )
    }

    /// Selected AW17 construction for AW31-AW33. Tempo's upstream quiet period is deliberately zero:
    /// the selected facade already performs latest-wins coalescing before it fades/stops Playback.
    /// Keeping the historical AW17 16ms tempo delay here would create a second debounce while audio
    /// is muted and can surface as an avoidable restart gap.
    public func makeTempoBoundaryCompatibleTransportAuthority(
        coordinator: PracticeDSPGenerationCoordinator,
        seekQuietPeriod: Duration = .milliseconds(16),
        loopQuietPeriod: Duration = .milliseconds(16)
    ) -> Lane3UnifiedProductionTransportAuthority {
        Lane3UnifiedProductionTransportAuthority(
            projectID: projectID,
            playback: playback,
            coordinator: coordinator,
            policy: Lane3UnifiedTransportPolicy(
                seekQuietPeriod: seekQuietPeriod,
                loopQuietPeriod: loopQuietPeriod,
                tempoQuietPeriod: .zero,
                tempoRatioRange: tempoRatioRange
            )
        )
    }

    /// Internal constructor used only to seed the public recovery slot. Keeping this non-public is
    /// important: callers outside the Lane-3 module should not be able to retain an unfenced facade
    /// reference and keep using it after AW33 replaces the selected stack.
    func makeSelectedTransportFacade(
        transportGate: Lane3InterruptionLifecycleGate,
        serializedClickGate: Lane3SerializedPracticeClickGate,
        tempoQuietPeriod: Duration = .milliseconds(16)
    ) -> Lane3TempoBoundarySelectedTransportFacade {
        Lane3TempoBoundarySelectedTransportFacade(
            projectID: projectID,
            transportGate: transportGate,
            serializedClickGate: serializedClickGate,
            tempoBackend: tempoBackend,
            tempoQuietPeriod: tempoQuietPeriod
        )
    }

    public func makeSelectedTransportRecoverySlot(
        transportGate: Lane3InterruptionLifecycleGate,
        serializedClickGate: Lane3SerializedPracticeClickGate,
        tempoQuietPeriod: Duration = .milliseconds(16)
    ) -> Lane3SelectedTransportReconstructionSlot {
        Lane3SelectedTransportReconstructionSlot(
            initialFacade: makeSelectedTransportFacade(
                transportGate: transportGate,
                serializedClickGate: serializedClickGate,
                tempoQuietPeriod: tempoQuietPeriod
            )
        )
    }

    public func boundaryEnvelopeRuntimeSnapshot() async -> PlaybackBoundaryEnvelopeRuntimeSnapshot {
        await tempoBackend.boundaryEnvelopeRuntimeSnapshot()
    }
}
#endif
