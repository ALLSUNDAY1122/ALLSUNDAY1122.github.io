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
    public let rawPlaybackBackendExposed: Bool
    public let parityPromotionAllowed: Bool
}

/// AW31 selected low-level Apple graph. The raw Playback backend stays private; HQ receives the
/// fenced Playback surface plus AW29 DSP stack, then asks this object to build the App-facing AW31
/// facade after AW18/AW21 are assembled around those exact components.
public struct Lane3AppleTempoAwarePlaybackDSPStack: @unchecked Sendable {
    public let playback: RescheduleFencedPlaybackBackend
    public let dsp: Lane3AppleDSPProductionStack
    public let compositionReceipt: Lane3AppleTempoAwareGraphReceipt
    private let tempoBackend: AppleTempoAwareRampedMultiTrackPlaybackBackend
    private let projectID: ProjectID

    public static func make(
        projectID: ProjectID,
        appOwnedRoot: URL,
        collector: Lane3DSPRuntimeTelemetryCollector,
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        initialState: PracticeDSPState = PracticeDSPState(),
        gainRampPolicy: PlaybackGainRampPolicy = PlaybackGainRampPolicy(),
        tempoTransitionPolicy: PracticeDSPTempoTransitionPolicy = .provisionalAppleInteractive,
        tempoTransitionSleeper: any PracticeDSPTempoTransitionSleeping = PracticeDSPSystemTempoTransitionSleeper(),
        pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive,
        pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping = PracticeDSPSystemPitchTransitionSleeper(),
        telemetryTimeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource()
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
            initialTempoRatio: initialState.tempoRatio
        )
        let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
        let receipt = Lane3AppleTempoAwareGraphReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW31_APPLE_SHARED_PLAYBACK_DSP_GRAPH_NON_PARITY",
            sharedEngineGraph: true,
            sharedTimePitchNode: true,
            tempoAwareProjectClock: true,
            tempoScaledLoopHostScheduling: true,
            twoPhaseTempoBoundaryAvailable: true,
            rawPlaybackBackendExposed: false,
            parityPromotionAllowed: false
        )
        return .init(
            playback: playback,
            dsp: dsp,
            compositionReceipt: receipt,
            tempoBackend: rawPlayback,
            projectID: projectID
        )
    }

    public func makeSelectedTransportFacade(
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
}
#endif
