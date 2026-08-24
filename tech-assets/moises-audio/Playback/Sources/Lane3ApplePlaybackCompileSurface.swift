#if canImport(AVFAudio)
import AVFAudio
import Foundation

/// Compile-time guard for the selected Playback-side Apple evidence/production surface.
/// AW31 provides the tempo-aware shared Playback/DSP graph and AW32 places a generation-guarded
/// master restart envelope after the exact shared time/pitch node. Omission of either selected
/// backend, the two-phase boundary contract, the envelope contract/decorator, muted-boundary tempo
/// policy, stack factory or bounded evidence source becomes an Apple-target compile failure.
public enum Lane3ApplePlaybackCompileSurface {
    public static func requireSelectedSurface() {
        requirePCMSourceConformance(Lane3AppleFilePCMChunkSource.self)
        requirePlaybackBackendConformance(AppleTempoAwareRampedMultiTrackPlaybackBackend.self)
        requireTempoBoundaryConformance(AppleTempoAwareRampedMultiTrackPlaybackBackend.self)
        requirePlaybackBackendConformance(AppleBoundaryEnvelopedPlaybackBackend.self)
        requireTempoBoundaryConformance(AppleBoundaryEnvelopedPlaybackBackend.self)
        _ = PlaybackBoundaryEnvelopePlanner.self
        _ = PlaybackBoundaryEnvelopePolicy.self
        _ = PlaybackBoundaryEnvelopeGenerationFence.self
        _ = PlaybackBoundaryEnvelopeRuntimeSnapshot.self
        _ = PracticeDSPTempoTransitionPolicy.boundaryMutedImmediate
        _ = Lane3AppleBoundaryEnvelopeCompositionReceipt.self
        _ = Lane3AppleLongTrackEvidenceInputFactory.self
        _ = Lane3AppleTempoAwarePlaybackDSPStack.self
        _ = Lane3TempoBoundarySelectedTransportFacade.self
        _ = AppleRampedMultiTrackPlaybackBackend.self
    }

    private static func requirePCMSourceConformance<T>(_ type: T.Type)
    where T: Lane3PCMChunkReadable {}

    private static func requirePlaybackBackendConformance<T>(_ type: T.Type)
    where T: PlaybackBackendDriving {}

    private static func requireTempoBoundaryConformance<T>(_ type: T.Type)
    where T: PlaybackTempoBoundaryRescheduling {}
}
#endif
