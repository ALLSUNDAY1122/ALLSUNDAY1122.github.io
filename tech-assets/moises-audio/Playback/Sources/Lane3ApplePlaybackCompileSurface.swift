#if canImport(AVFAudio)
import AVFAudio
import Foundation

/// Compile-time guard for the selected Playback-side Apple evidence/production surface.
/// Keeping this guard in Sources makes omission of the bounded file source or selected ramped
/// playback backend a compile error in the Apple target instead of a late runtime discovery.
public enum Lane3ApplePlaybackCompileSurface {
    public static func requireSelectedSurface() {
        requirePCMSourceConformance(Lane3AppleFilePCMChunkSource.self)
        _ = Lane3AppleLongTrackEvidenceInputFactory.self
        _ = AppleRampedMultiTrackPlaybackBackend.self
    }

    private static func requirePCMSourceConformance<T>(_ type: T.Type)
    where T: Lane3PCMChunkReadable {}
}
#endif
