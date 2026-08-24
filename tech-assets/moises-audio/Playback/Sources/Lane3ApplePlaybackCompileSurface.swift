#if canImport(AVFAudio)
import AVFAudio
import Foundation

/// Compile-time guard for the selected Playback-side Apple evidence/production surface.
/// AW31 promotes the tempo-aware shared Playback/DSP graph as the selected transport path while
/// retaining the older ramped backend as a baseline implementation. Omission of the new backend,
/// two-phase boundary conformance, stack factory, or bounded evidence source becomes an Apple-target
/// compile failure instead of a late runtime discovery.
public enum Lane3ApplePlaybackCompileSurface {
    public static func requireSelectedSurface() {
        requirePCMSourceConformance(Lane3AppleFilePCMChunkSource.self)
        requirePlaybackBackendConformance(AppleTempoAwareRampedMultiTrackPlaybackBackend.self)
        requireTempoBoundaryConformance(AppleTempoAwareRampedMultiTrackPlaybackBackend.self)
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
